#!/usr/bin/env bash
# install-ativos-gpu-drivers.sh
#
# Detects the GPU(s) present in the system via PCI vendor ID and installs
# the correct driver stack (NVIDIA / AMD / Intel) if it isn't already
# installed. Safe to re-run: anything already installed is left alone.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-gpu-drivers.sh"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "!! pacman not found — this script only supports Arch/AtivOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/lib-find-limine-conf.sh
source "$SCRIPT_DIR/../lib/lib-find-limine-conf.sh"
# shellcheck source=../lib/lib-add-cmdline-param.sh
source "$SCRIPT_DIR/../lib/lib-add-cmdline-param.sh"

# ---- helpers ----------------------------------------------------------
pkg_installed() { pacman -Qi "$1" >/dev/null 2>&1; }
any_installed() { for p in "$@"; do pkg_installed "$p" && return 0; done; return 1; }

multilib_enabled() { grep -qE '^\[multilib\]' /etc/pacman.conf 2>/dev/null; }

install_pkgs() {
    local todo=()
    for p in "$@"; do
        pkg_installed "$p" || todo+=("$p")
    done
    if [[ ${#todo[@]} -gt 0 ]]; then
        echo "==> Installing: ${todo[*]}"
        pacman -S --needed --noconfirm "${todo[@]}"
        NEEDS_REBUILD=1
    else
        echo "    Already installed: $*"
    fi
}

NEEDS_REBUILD=0

if ! command -v lspci >/dev/null 2>&1; then
    echo "==> Installing pciutils (needed to detect the GPU)"
    pacman -S --needed --noconfirm pciutils
fi

# ---- detect GPU(s) via PCI vendor ID -----------------------------------
# 10de = NVIDIA, 1002 = AMD/ATI, 8086 = Intel, 1234/15ad/80ee = common VMs
mapfile -t GPU_LINES < <(lspci -nnk | grep -Ei 'VGA compatible controller|3D controller|Display controller')

if [[ ${#GPU_LINES[@]} -eq 0 ]]; then
    echo "!! No GPU detected via lspci. Skipping driver installation."
    exit 0
fi

echo "==> Detected GPU(s):"
printf '    %s\n' "${GPU_LINES[@]}"
echo ""

HAS_NVIDIA=0; HAS_AMD=0; HAS_INTEL=0; HAS_VM=0
for line in "${GPU_LINES[@]}"; do
    echo "$line" | grep -qi '\[10de:' && HAS_NVIDIA=1
    echo "$line" | grep -qi '\[1002:' && HAS_AMD=1
    echo "$line" | grep -qi '\[8086:' && HAS_INTEL=1
    echo "$line" | grep -qiE '\[1234:|\[15ad:|\[80ee:' && HAS_VM=1
done

# ---- NVIDIA -------------------------------------------------------------
if [[ $HAS_NVIDIA -eq 1 ]]; then
    echo "==> NVIDIA GPU detected"

    # THE BUG (the one that actually broke your splash): the early-KMS
    # MODULES= edit and nvidia_drm.modeset=1 cmdline param below used to
    # live INSIDE the "driver not yet installed" branch of this if/else —
    # i.e. they only ever ran in the same invocation that itself installed
    # the package via install_pkgs. Any system where the driver was
    # already present — installed manually (e.g. `sudo pacman -S
    # nvidia-open` directly instead of through this script), or even just
    # this script being re-run a second time normally — hit the "already
    # installed, skipping" branch and never touched KMS/cmdline at all, no
    # matter how many times you re-ran it. Fixed by splitting "install the
    # package" from "make sure early KMS + modeset are configured": the
    # latter now always runs whenever an NVIDIA driver is present on disk,
    # regardless of which invocation (or which tool) put it there.
    if any_installed nvidia nvidia-dkms nvidia-open nvidia-open-dkms nvidia-lts; then
        echo "    NVIDIA driver already installed, skipping package install."
    else
        # As of driver 590 (Dec 2025), Arch replaced its official NVIDIA
        # packages with the open kernel modules entirely: `nvidia-dkms`
        # doesn't exist anymore. Using `nvidia-open` (precompiled per-kernel
        # binary package built by Arch itself, pulled in as a dependency of
        # the exact `linux`/`linux-lts`/etc. package version installed) —
        # not `nvidia-open-dkms` — since it needs no local build step at
        # all: pacman just refuses the install outright if it can't match a
        # precompiled module to the installed kernel, instead of installing
        # "successfully" and only failing quietly to produce a .ko like a
        # dkms build can (headers mismatch, etc). Driver 590 also dropped
        # Pascal/Maxwell (GTX 900/10xx and older) support outright — those
        # cards need the legacy `nvidia-580xx-dkms` package from the AUR
        # instead, which this script won't build automatically (needs an
        # AUR helper and a much longer build than a repo package).
        NVIDIA_UTIL_PKGS=(nvidia-utils nvidia-settings)
        multilib_enabled && NVIDIA_UTIL_PKGS+=(lib32-nvidia-utils)
        install_pkgs nvidia-open "${NVIDIA_UTIL_PKGS[@]}"
    fi

    nvidia_module_built() {
        # nvidia-open ships its .ko under /usr/lib/modules/<kver>/...
        # like any standard pacman package (no dkms/updates subdir,
        # since there's no local build step).
        #
        # Checks every kernel actually installed on disk (each one has a
        # /usr/lib/modules/<kver>/pkgbase file) rather than uname -r, since
        # this script also runs inside arch-chroot during install, where
        # uname -r reports the HOST/live-ISO's running kernel — not the
        # kernel that was just pacstrapped into the target.
        local kdir
        for kdir in /usr/lib/modules/*/; do
            [[ -f "${kdir}pkgbase" ]] || continue
            find "$kdir" -name 'nvidia.ko*' 2>/dev/null | grep -q . && return 0
        done
        return 1
    }

    if nvidia_module_built; then
        echo "    nvidia-open module present for at least one installed kernel."

        # Early KMS so plymouth/the boot splash renders correctly instead
        # of flashing to a black screen before the driver loads.
        if ! grep -qE '^MODULES=\([^)]*\bnvidia\b' /etc/mkinitcpio.conf; then
            echo "==> Enabling early KMS for NVIDIA in mkinitcpio.conf"
            cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%s)"
            if grep -qE '^MODULES=\(\s*\)' /etc/mkinitcpio.conf; then
                sed -i -E 's/^MODULES=\(\s*\)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            else
                sed -i -E 's/^MODULES=\(([^)]*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            fi
            NEEDS_REBUILD=1
        else
            echo "    Early KMS for NVIDIA already configured in mkinitcpio.conf"
        fi

        # THE BUG (boot splash never shows on NVIDIA): loading nvidia_drm
        # early via MODULES= above is not enough by itself — the module
        # loads but modesetting stays off unless the kernel is explicitly
        # told to enable it. Without this, Plymouth has no real DRM/KMS
        # device to draw the graphical splash on and silently falls back
        # to a blank/text boot (GNOME/KDE still start fine afterwards,
        # which is why this is easy to miss — only the splash is
        # affected). This must be a kernel *cmdline* param, not a
        # modprobe option, so it's active in the initramfs stage before
        # udev/systemd would otherwise apply a modprobe.d config.
        #
        # Note: checking /proc/cmdline here (rather than the actual
        # bootloader config file) only tells us about the CURRENT boot, not
        # whether the param is configured for the NEXT one — but
        # add_kernel_cmdline_param() itself is idempotent against the real
        # config file, so calling it unconditionally on every run is safe
        # and correct regardless of what /proc/cmdline says right now.
        echo "==> Ensuring nvidia_drm.modeset=1 is set on the kernel command line (required for Plymouth on NVIDIA)"
        add_kernel_cmdline_param "nvidia_drm.modeset=1"
    else
        echo "!! nvidia-open didn't produce a module for any installed kernel."
        echo "   Two likely causes:"
        echo "     1. Your card is pre-Turing (Maxwell/Pascal, GTX 900/10xx or"
        echo "        older) — the open modules don't support it at all. You'll"
        echo "        need 'nvidia-580xx-dkms' from the AUR instead:"
        echo "          sudo pacman -Rns nvidia-open nvidia-utils nvidia-settings"
        echo "          yay -S nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings"
        echo "     2. linux-headers is missing or doesn't match the installed kernel"
        echo "        — check: dkms status"
        echo "   Skipping the early-KMS mkinitcpio edit until this is sorted —"
        echo "   baking in a module that doesn't exist would only break the"
        echo "   initramfs rebuild here and in every later step that also rebuilds"
        echo "   it (Plymouth). Re-run this script once the module builds."
    fi
    echo ""
fi

# ---- AMD ------------------------------------------------------------
if [[ $HAS_AMD -eq 1 ]]; then
    echo "==> AMD GPU detected"
    if pkg_installed mesa && pkg_installed vulkan-radeon; then
        echo "    AMD driver stack already installed, skipping."
    else
        AMD_PKGS=(mesa vulkan-radeon libva-mesa-driver mesa-vdpau)
        multilib_enabled && AMD_PKGS+=(lib32-mesa lib32-vulkan-radeon)
        install_pkgs "${AMD_PKGS[@]}"
    fi
    echo ""
fi

# ---- Intel ------------------------------------------------------------
if [[ $HAS_INTEL -eq 1 ]]; then
    echo "==> Intel GPU detected"
    if pkg_installed mesa && pkg_installed vulkan-intel; then
        echo "    Intel driver stack already installed, skipping."
    else
        INTEL_PKGS=(mesa vulkan-intel intel-media-driver)
        multilib_enabled && INTEL_PKGS+=(lib32-mesa lib32-vulkan-intel)
        install_pkgs "${INTEL_PKGS[@]}"
    fi
    echo ""
fi

# ---- Virtual machine GPU (QEMU/VMware/VirtualBox) ----------------------
if [[ $HAS_VM -eq 1 && $HAS_NVIDIA -eq 0 && $HAS_AMD -eq 0 && $HAS_INTEL -eq 0 ]]; then
    echo "==> Virtual machine GPU detected"
    if pkg_installed mesa; then
        echo "    mesa already installed, skipping."
    else
        install_pkgs mesa
    fi

    # THE BUG: on VMware specifically, the vmwgfx DRM/KMS driver often
    # isn't ready early enough via mkinitcpio's generic 'autodetect' hook
    # alone — this is a documented quirk (see the ArchWiki VMware guest
    # page), not something specific to our Plymouth theme. Without it,
    # Plymouth has no working KMS device to draw on and falls back to a
    # blank text console with a blinking cursor for the rest of boot,
    # until SDDM's own display server takes over later. Forcing the
    # module into the initramfs's MODULES array (same fix distros like
    # Omarchy effectively get via their hook ordering) gives it time to
    # initialize before Plymouth needs it.
    VM_KMS_MODULE=""
    for line in "${GPU_LINES[@]}"; do
        echo "$line" | grep -qi '\[15ad:' && VM_KMS_MODULE="vmwgfx"
        echo "$line" | grep -qi '\[80ee:' && VM_KMS_MODULE="vboxvideo"
    done

    if [[ -n "$VM_KMS_MODULE" ]] && ! grep -qE "^MODULES=\([^)]*\b${VM_KMS_MODULE}\b" /etc/mkinitcpio.conf; then
        echo "==> Enabling early KMS for $VM_KMS_MODULE in mkinitcpio.conf"
        cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%s)"
        if grep -qE '^MODULES=\(\s*\)' /etc/mkinitcpio.conf; then
            sed -i -E "s/^MODULES=\(\s*\)/MODULES=($VM_KMS_MODULE)/" /etc/mkinitcpio.conf
        else
            sed -i -E "s/^MODULES=\(([^)]*)\)/MODULES=(\1 $VM_KMS_MODULE)/" /etc/mkinitcpio.conf
        fi
        NEEDS_REBUILD=1
    elif [[ -n "$VM_KMS_MODULE" ]]; then
        echo "    $VM_KMS_MODULE already in MODULES= in mkinitcpio.conf"
    fi
    echo ""
fi

if [[ $HAS_NVIDIA -eq 0 && $HAS_AMD -eq 0 && $HAS_INTEL -eq 0 && $HAS_VM -eq 0 ]]; then
    echo "!! Detected a GPU but couldn't identify the vendor. Nothing installed:"
    printf '    %s\n' "${GPU_LINES[@]}"
fi

# ---- rebuild initramfs if anything changed -----------------------------
if [[ $NEEDS_REBUILD -eq 1 ]] && command -v mkinitcpio >/dev/null 2>&1; then
    echo "==> Rebuilding initramfs for all kernel presets"
    if ! mkinitcpio -P; then
        echo "!! mkinitcpio -P failed. mkinitcpio.conf was backed up before editing"
        echo "   (see /etc/mkinitcpio.conf.bak.*) if you need to revert the change."
        exit 1
    fi
fi

echo "==> GPU driver check complete."

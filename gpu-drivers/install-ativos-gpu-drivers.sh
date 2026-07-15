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
    if any_installed nvidia nvidia-dkms nvidia-open nvidia-open-dkms nvidia-lts; then
        echo "    NVIDIA driver already installed, skipping."
    else
        # nvidia-dkms works across every NVIDIA GPU Arch still supports and
        # survives kernel upgrades without a rebuild. (Turing/RTX-20xx and
        # newer cards can switch to nvidia-open-dkms manually later if you
        # want the open kernel modules instead.)
        NVIDIA_PKGS=(nvidia-dkms nvidia-utils nvidia-settings)
        multilib_enabled && NVIDIA_PKGS+=(lib32-nvidia-utils)
        install_pkgs "${NVIDIA_PKGS[@]}"

        # Early KMS so plymouth/the boot splash renders correctly instead of
        # flashing to a black screen before the driver loads.
        if ! grep -qE '^MODULES=\([^)]*\bnvidia\b' /etc/mkinitcpio.conf; then
            echo "==> Enabling early KMS for NVIDIA in mkinitcpio.conf"
            cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%s)"
            if grep -qE '^MODULES=\(\s*\)' /etc/mkinitcpio.conf; then
                sed -i -E 's/^MODULES=\(\s*\)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            else
                sed -i -E 's/^MODULES=\(([^)]*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            fi
            NEEDS_REBUILD=1
        fi
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
    echo ""
fi

if [[ $HAS_NVIDIA -eq 0 && $HAS_AMD -eq 0 && $HAS_INTEL -eq 0 && $HAS_VM -eq 0 ]]; then
    echo "!! Detected a GPU but couldn't identify the vendor. Nothing installed:"
    printf '    %s\n' "${GPU_LINES[@]}"
fi

# ---- rebuild initramfs if anything changed -----------------------------
if [[ $NEEDS_REBUILD -eq 1 ]] && command -v mkinitcpio >/dev/null 2>&1; then
    echo "==> Rebuilding initramfs for all kernel presets"
    mkinitcpio -P
fi

echo "==> GPU driver check complete."

#!/usr/bin/env bash
# install-ativos-plymouth.sh
# Installs and activates the AtivOS Plymouth boot splash on Arch/AtivOS.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-plymouth.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$SCRIPT_DIR/theme"
THEME_DEST="/usr/share/plymouth/themes/ativos"

# ---- 1. make sure plymouth is installed ----------------------------------
if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
    echo "==> Installing plymouth"
    pacman -S --needed --noconfirm plymouth
fi

# ---- 2. install theme files ----------------------------------------------
echo "==> Installing theme to $THEME_DEST"
mkdir -p "$THEME_DEST"
cp "$THEME_SRC/ativos.plymouth" "$THEME_DEST/"
cp "$THEME_SRC/ativos.script"   "$THEME_DEST/"
cp "$THEME_SRC/logo.png"        "$THEME_DEST/"
cp "$THEME_SRC/progress_track.png" "$THEME_DEST/"
cp "$THEME_SRC/progress_fill.png"  "$THEME_DEST/"
chmod 644 "$THEME_DEST"/*

# ---- 3. add the plymouth hook to mkinitcpio -------------------------------
# THIS WAS THE BUG: the old version always inserted the "plymouth" hook after
# "udev". That only works on the legacy busybox/udev-based initramfs. Systems
# using the systemd-based initramfs (HOOKS=(base systemd ...) — increasingly
# the default on fresh Arch installs, and required for things like
# systemd-cryptenroll) have no "udev" hook at all, so the sed never matched,
# the hook never got added, and plymouth silently never ran at boot. The
# systemd-based initramfs also needs a different hook name entirely
# ("sd-plymouth", not "plymouth").
MKINITCPIO_CONF="/etc/mkinitcpio.conf"

if grep -qE '^HOOKS=\([^)]*\bsystemd\b' "$MKINITCPIO_CONF"; then
    HOOK_NAME="sd-plymouth"
    ANCHOR="systemd"
else
    HOOK_NAME="plymouth"
    ANCHOR="udev"
fi

if grep -qE "^HOOKS=.*\b${HOOK_NAME}\b" "$MKINITCPIO_CONF"; then
    echo "==> '$HOOK_NAME' hook already present in mkinitcpio.conf"
else
    echo "==> Adding '$HOOK_NAME' hook to $MKINITCPIO_CONF (after '$ANCHOR')"
    cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.bak.$(date +%s)"
    sed -i -E "s/(HOOKS=\([^)]*\b${ANCHOR}\b)/\1 ${HOOK_NAME}/" "$MKINITCPIO_CONF"
    if ! grep -qE "^HOOKS=.*\b${HOOK_NAME}\b" "$MKINITCPIO_CONF"; then
        echo "    Could not auto-edit HOOKS (unexpected format)."
        echo "    Add '$HOOK_NAME' manually to the HOOKS= array in $MKINITCPIO_CONF,"
        echo "    right after '$ANCHOR', then re-run this script."
        exit 1
    fi
fi

# ---- 4. set the theme as default -----------------------------------------
echo "==> Setting AtivOS as the default Plymouth theme"
plymouth-set-default-theme ativos

# -R above is supposed to rebuild the initramfs, but it only reliably covers
# the currently-running kernel's preset. Force a full rebuild across every
# preset in /etc/mkinitcpio.d/ (linux, linux-lts, etc.) so the hook change
# from step 3 actually lands in whichever image the bootloader boots.
if command -v mkinitcpio >/dev/null 2>&1; then
    echo "==> Rebuilding initramfs for all kernel presets"
    mkinitcpio -P
fi

# ---- 5. make sure the kernel actually shows the splash --------------------
# Limine is checked first (the modern default many Arch-based distros,
# including Omarchy-style setups, use); GRUB is supported as a fallback for
# systems that still use it.

LIMINE_DEFAULT="/etc/default/limine"
GRUB_DEFAULT="/etc/default/grub"

add_cmdline_params() {
    # Appends the given params inside the existing KERNEL_CMDLINE[default]="..."
    # value, or creates that line if it doesn't exist yet. This file gets
    # `source`d as bash (by /usr/local/bin/limine-update), so the value must
    # stay a single properly-quoted string — an unquoted multi-word += line
    # is not valid bash and would break sourcing.
    local params="$1"
    if grep -qE 'KERNEL_CMDLINE\[default\]=.*\bquiet\b' "$LIMINE_DEFAULT" && \
       grep -qE 'KERNEL_CMDLINE\[default\]=.*\bsplash\b' "$LIMINE_DEFAULT"; then
        return 1
    fi
    if grep -qE 'KERNEL_CMDLINE\[default\]=' "$LIMINE_DEFAULT"; then
        sed -i -E "s/(KERNEL_CMDLINE\[default\]=\")([^\"]*)(\")/\1\2 ${params}\3/" "$LIMINE_DEFAULT"
    else
        grep -qE '^\s*declare -A KERNEL_CMDLINE' "$LIMINE_DEFAULT" 2>/dev/null || \
            echo 'declare -A KERNEL_CMDLINE' >> "$LIMINE_DEFAULT"
        echo "KERNEL_CMDLINE[default]=\"$params\"" >> "$LIMINE_DEFAULT"
    fi
    return 0
}

if command -v limine-update >/dev/null 2>&1 || [[ -f "$LIMINE_DEFAULT" ]] || command -v limine-entry-tool >/dev/null 2>&1; then
    echo "==> Limine detected — configuring kernel command line"

    if [[ ! -f "$LIMINE_DEFAULT" ]]; then
        if [[ -f /etc/limine-entry-tool.conf ]]; then
            cp /etc/limine-entry-tool.conf "$LIMINE_DEFAULT"
        else
            touch "$LIMINE_DEFAULT"
        fi
    fi

    cp "$LIMINE_DEFAULT" "${LIMINE_DEFAULT}.bak.$(date +%s)"

    if add_cmdline_params "quiet splash"; then
        echo "    Added 'quiet splash' to KERNEL_CMDLINE[default] in $LIMINE_DEFAULT"
    else
        echo "    'quiet splash' already present in $LIMINE_DEFAULT"
    fi

    if command -v limine-update >/dev/null 2>&1; then
        echo "==> Running limine-update (refreshes limine.conf entries with the new cmdline)"
        limine-update
    elif command -v limine-mkinitcpio >/dev/null 2>&1; then
        echo "==> Running limine-mkinitcpio (refreshes limine.conf entries with the new cmdline)"
        limine-mkinitcpio -P
    else
        echo "    No limine-update/limine-mkinitcpio found — install limine-mkinitcpio-hook"
        echo "    (AUR) for automatic entry management, or edit /boot/limine.conf (or"
        echo "    /boot/limine/limine.conf) by hand and add 'quiet splash' to each"
        echo "    entry's cmdline: line."
    fi

elif [[ -f "$GRUB_DEFAULT" ]]; then
    echo "==> GRUB detected — configuring kernel command line"
    if ! grep -qE 'GRUB_CMDLINE_LINUX_DEFAULT=.*quiet' "$GRUB_DEFAULT" || \
       ! grep -qE 'GRUB_CMDLINE_LINUX_DEFAULT=.*splash' "$GRUB_DEFAULT"; then
        cp "$GRUB_DEFAULT" "${GRUB_DEFAULT}.bak.$(date +%s)"
        sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)(")/\1\2 quiet splash\3/' "$GRUB_DEFAULT"
        echo "    Added 'quiet splash' to GRUB_CMDLINE_LINUX_DEFAULT"
    else
        echo "    'quiet splash' already present"
    fi

    if command -v grub-mkconfig >/dev/null 2>&1; then
        echo "==> Regenerating grub.cfg"
        grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo "!! grub-mkconfig not found — regenerate your GRUB config manually."
    fi
else
    echo "!! Neither Limine nor GRUB config detected."
    echo "   If you use systemd-boot, add 'quiet splash' to the 'options' line"
    echo "   in your entries under /boot/loader/entries/*.conf manually."
fi

echo ""
echo "==> Done. Reboot to see the AtivOS boot splash."
echo "    Preview without rebooting (switches to the splash on this TTY):"
echo "      sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth --quit"

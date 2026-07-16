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
else
    HOOK_NAME="plymouth"
fi

if grep -qE "^HOOKS=.*\b${HOOK_NAME}\b" "$MKINITCPIO_CONF"; then
    echo "==> '$HOOK_NAME' hook already present in mkinitcpio.conf"
else
    # THE ACTUAL BUG (splash never appearing): this used to always insert the
    # hook right after "udev"/"systemd" — the very start of the HOOKS array.
    # That's too early: plymouth needs the KMS/DRM modules (loaded by the
    # "kms" hook) already active so it can draw a real graphical splash, and
    # it needs to run before "filesystems"/"fsck" so the splash is already up
    # before those stages print their own messages. Inserted too early,
    # plymouth silently starts in a non-graphical fallback mode — the hook
    # "works" (no errors, boots fine) but nothing is ever visibly shown.
    # Correct position: immediately before "filesystems" (falls back to
    # "fsck", then to right after udev/systemd only if neither exists).
    if grep -qE '\bfilesystems\b' "$MKINITCPIO_CONF"; then
        ANCHOR="filesystems"; POSITION="before"
    elif grep -qE '\bfsck\b' "$MKINITCPIO_CONF"; then
        ANCHOR="fsck"; POSITION="before"
    elif grep -qE '\bsystemd\b' "$MKINITCPIO_CONF"; then
        ANCHOR="systemd"; POSITION="after"
    else
        ANCHOR="udev"; POSITION="after"
    fi

    echo "==> Adding '$HOOK_NAME' hook to $MKINITCPIO_CONF ($POSITION '$ANCHOR')"
    cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.bak.$(date +%s)"
    if [[ "$POSITION" == "before" ]]; then
        sed -i -E "s/(HOOKS=\([^)]*)\b${ANCHOR}\b/\1${HOOK_NAME} ${ANCHOR}/" "$MKINITCPIO_CONF"
    else
        sed -i -E "s/(HOOKS=\([^)]*\b${ANCHOR}\b)/\1 ${HOOK_NAME}/" "$MKINITCPIO_CONF"
    fi
    if ! grep -qE "^HOOKS=.*\b${HOOK_NAME}\b" "$MKINITCPIO_CONF"; then
        echo "    Could not auto-edit HOOKS (unexpected format)."
        echo "    Add '$HOOK_NAME' manually to the HOOKS= array in $MKINITCPIO_CONF,"
        echo "    right before 'filesystems' (after 'kms'/'block'), then re-run this script."
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

# Locate the real limine.conf on disk, if one exists — this is what
# actually matters for archinstall's native Limine installs, which write
# this file directly at install time with no limine-entry-tool/AUR layer
# on top at all.
LIMINE_CONF=""
for c in /boot/limine.conf /boot/EFI/limine/limine.conf /boot/limine/limine.conf \
         /efi/limine.conf /efi/EFI/limine/limine.conf /efi/limine/limine.conf; do
    [[ -f "$c" ]] && LIMINE_CONF="$c" && break
done
if [[ -z "$LIMINE_CONF" ]]; then
    LIMINE_CONF="$(find /boot /efi -maxdepth 4 -iname 'limine.conf' 2>/dev/null | head -1)"
fi

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

# THE BUG: this whole branch used to only fire (and only ever touched
# /etc/default/limine) if limine-entry-tool/limine-update/limine-mkinitcpio
# were present. archinstall's built-in Limine support doesn't use any of
# those — it writes /boot/limine.conf (or an ESP-relative equivalent)
# directly, as a static file, so this branch was never actually reaching
# the file that mattered on a plain archinstall + Limine system.
if [[ -n "$LIMINE_CONF" ]] || command -v limine-update >/dev/null 2>&1 || [[ -f "$LIMINE_DEFAULT" ]] || command -v limine-entry-tool >/dev/null 2>&1; then
    echo "==> Limine detected — configuring kernel command line"

    # Direct approach: patch the real config file's cmdline: lines. This is
    # what actually matters for archinstall-style native Limine installs.
    if [[ -n "$LIMINE_CONF" ]]; then
        echo "    Found $LIMINE_CONF"
        cp "$LIMINE_CONF" "${LIMINE_CONF}.bak.$(date +%s)"
        if grep -qE '^\s*cmdline:.*\bquiet\b' "$LIMINE_CONF" && grep -qE '^\s*cmdline:.*\bsplash\b' "$LIMINE_CONF"; then
            echo "    'quiet splash' already present in $LIMINE_CONF"
        elif grep -qE '^\s*cmdline:' "$LIMINE_CONF"; then
            sed -i -E 's/^([[:space:]]*cmdline:[[:space:]]*.*)$/\1 quiet splash/' "$LIMINE_CONF"
            echo "    Added 'quiet splash' directly to cmdline: line(s) in $LIMINE_CONF"
        else
            echo "    No 'cmdline:' key found in $LIMINE_CONF — check its entry format manually."
        fi
    fi

    # Tool-based approach: only relevant if the limine-entry-tool/AUR
    # ecosystem is actually present, so future kernel updates stay
    # splash-enabled too (not needed for archinstall's native setup, which
    # has no such regeneration mechanism to configure).
    if command -v limine-update >/dev/null 2>&1 || [[ -f "$LIMINE_DEFAULT" ]] || command -v limine-entry-tool >/dev/null 2>&1; then
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
            limine-update || echo "    limine-update reported an error — the direct edit above still stands."
        elif command -v limine-mkinitcpio >/dev/null 2>&1; then
            echo "==> Running limine-mkinitcpio (refreshes limine.conf entries with the new cmdline)"
            limine-mkinitcpio -P || echo "    limine-mkinitcpio reported an error — the direct edit above still stands."
        fi
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
    SDBOOT_ENTRIES_DIR=""
    for d in /boot/loader/entries /efi/loader/entries; do
        [[ -d "$d" ]] && SDBOOT_ENTRIES_DIR="$d" && break
    done

    if [[ -n "$SDBOOT_ENTRIES_DIR" ]]; then
        echo "==> systemd-boot detected — configuring kernel command line"
        # THE BUG: this branch used to just print "add it yourself" and do
        # nothing. archinstall's default bootloader is systemd-boot (not
        # Limine/GRUB), so on installs that went through archinstall first
        # and layered the AtivOS stack on top, this was the branch that
        # actually mattered — and it silently did nothing.

        # /etc/kernel/cmdline is what `kernel-install` (systemd's own
        # entry generator, triggered automatically by the "linux" package's
        # pacman hook on every kernel update) reads to build new loader
        # entries — writing here keeps future kernel updates splash-enabled
        # too, not just this one boot.
        KERNEL_CMDLINE_FILE="/etc/kernel/cmdline"
        if [[ -f "$KERNEL_CMDLINE_FILE" ]]; then
            cp "$KERNEL_CMDLINE_FILE" "${KERNEL_CMDLINE_FILE}.bak.$(date +%s)"
            if grep -qE '\bquiet\b' "$KERNEL_CMDLINE_FILE" && grep -qE '\bsplash\b' "$KERNEL_CMDLINE_FILE"; then
                echo "    'quiet splash' already present in $KERNEL_CMDLINE_FILE"
            else
                sed -i -E 's/[[:space:]]*$//; s/$/ quiet splash/' "$KERNEL_CMDLINE_FILE"
                echo "    Added 'quiet splash' to $KERNEL_CMDLINE_FILE"
            fi
        else
            echo "quiet splash" > "$KERNEL_CMDLINE_FILE"
            echo "    Created $KERNEL_CMDLINE_FILE with 'quiet splash'"
            echo "    (archinstall-generated systemd-boot setups usually bake root=/rw"
            echo "     params into the initrd/UKI rather than this file — if your"
            echo "     existing entries' 'options' line has params that AREN'T also"
            echo "     baked in, add those to this file too before relying on it.)"
        fi

        # Regenerate entries immediately so this boot (not just the next
        # kernel update) picks up the splash.
        if command -v kernel-install >/dev/null 2>&1; then
            echo "==> Regenerating loader entries via kernel-install"
            for kver_dir in /usr/lib/modules/*; do
                [[ -f "$kver_dir/pkgbase" ]] || continue
                kver="$(basename "$kver_dir")"
                kernel-install add "$kver" "$kver_dir/vmlinuz" 2>/dev/null || true
            done
        fi

        # Belt-and-suspenders: also sweep already-generated entry files
        # directly, in case kernel-install isn't available or didn't touch
        # every entry (e.g. a fallback-initramfs entry).
        UPDATED=0
        for conf in "$SDBOOT_ENTRIES_DIR"/*.conf; do
            [[ -f "$conf" ]] || continue
            if grep -qE '^options\b.*\bquiet\b' "$conf" && grep -qE '^options\b.*\bsplash\b' "$conf"; then
                continue
            fi
            cp "$conf" "${conf}.bak.$(date +%s)"
            if grep -qE '^options\b' "$conf"; then
                sed -i -E 's/^(options[[:space:]].*)$/\1 quiet splash/' "$conf"
            else
                echo "options quiet splash" >> "$conf"
            fi
            UPDATED=1
        done
        [[ $UPDATED -eq 1 ]] && echo "    Swept 'quiet splash' directly into $SDBOOT_ENTRIES_DIR/*.conf"
    else
        echo "!! No Limine, GRUB, or systemd-boot configuration detected."
        echo "   Add 'quiet splash' to your bootloader's kernel command line manually."
    fi
fi

echo ""
echo "==> Done. Reboot to see the AtivOS boot splash."
echo "    Preview without rebooting (switches to the splash on this TTY):"
echo "      sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth --quit"

# lib-add-cmdline-param.sh — sourced, not executed directly.
#
# Adds a single kernel command-line parameter (e.g. "splash", or
# "nvidia_drm.modeset=1") across whichever bootloader is actually in use —
# Limine (both the archinstall-native /boot/limine.conf and the
# limine-entry-tool/AUR /etc/default/limine layer), GRUB, or systemd-boot.
#
# Pulled out of plymouth-theme/install-ativos-plymouth.sh so
# gpu-drivers/install-ativos-gpu-drivers.sh can reuse the exact same
# tested bootloader-detection logic instead of re-implementing it — the
# alternative (copy-pasting ~100 lines) is exactly the kind of drift that
# caused the "archinstall native Limine install" and "systemd-boot did
# nothing" bugs documented inline below in the first place.
#
# Expects the caller to already have `set -euo pipefail` active, to be
# running as root, and to `source lib/lib-find-limine-conf.sh` first (this
# file uses find_limine_conf/$LIMINE_CONF).

add_kernel_cmdline_param() {
    local param="$1"
    # word-boundary match so e.g. "splash" doesn't false-positive against
    # "splashy" and "nvidia_drm.modeset=1" doesn't false-positive against
    # a hypothetical "nvidia_drm.modeset=0"
    local param_re
    param_re="$(printf '%s' "$param" | sed -E 's/[.[\*^$]/\\&/g')"

    local LIMINE_DEFAULT="/etc/default/limine"
    local GRUB_DEFAULT="/etc/default/grub"

    find_limine_conf

    _add_to_limine_default() {
        if [[ ! -f "$LIMINE_DEFAULT" ]]; then
            if [[ -f /etc/limine-entry-tool.conf ]]; then
                cp /etc/limine-entry-tool.conf "$LIMINE_DEFAULT"
            else
                touch "$LIMINE_DEFAULT"
            fi
        fi
        cp "$LIMINE_DEFAULT" "${LIMINE_DEFAULT}.bak.$(date +%s)"

        if grep -qE "KERNEL_CMDLINE\[default\]=.*\b${param_re}\b" "$LIMINE_DEFAULT"; then
            echo "    '$param' already present in $LIMINE_DEFAULT"
            return 0
        fi
        if grep -qE 'KERNEL_CMDLINE\[default\]=' "$LIMINE_DEFAULT"; then
            sed -i -E "s/(KERNEL_CMDLINE\[default\]=\")([^\"]*)(\")/\1\2 ${param}\3/" "$LIMINE_DEFAULT"
        else
            grep -qE '^\s*declare -A KERNEL_CMDLINE' "$LIMINE_DEFAULT" 2>/dev/null || \
                echo 'declare -A KERNEL_CMDLINE' >> "$LIMINE_DEFAULT"
            echo "KERNEL_CMDLINE[default]=\"$param\"" >> "$LIMINE_DEFAULT"
        fi
        echo "    Added '$param' to KERNEL_CMDLINE[default] in $LIMINE_DEFAULT"
    }

    if [[ -n "$LIMINE_CONF" ]] || command -v limine-update >/dev/null 2>&1 || [[ -f "$LIMINE_DEFAULT" ]] || command -v limine-entry-tool >/dev/null 2>&1; then
        echo "==> Limine detected — adding '$param' to kernel command line"

        if [[ -n "$LIMINE_CONF" ]]; then
            cp "$LIMINE_CONF" "${LIMINE_CONF}.bak.$(date +%s)"
            if grep -qE "^\s*cmdline:.*\b${param_re}\b" "$LIMINE_CONF"; then
                echo "    '$param' already present in $LIMINE_CONF"
            elif grep -qE '^\s*cmdline:' "$LIMINE_CONF"; then
                sed -i -E "s/^([[:space:]]*cmdline:[[:space:]]*.*)\$/\1 ${param}/" "$LIMINE_CONF"
                echo "    Added '$param' directly to cmdline: line(s) in $LIMINE_CONF"
            else
                echo "    No 'cmdline:' key found in $LIMINE_CONF — check its entry format manually."
            fi
        fi

        if command -v limine-update >/dev/null 2>&1 || [[ -f "$LIMINE_DEFAULT" ]] || command -v limine-entry-tool >/dev/null 2>&1; then
            _add_to_limine_default
            if command -v limine-update >/dev/null 2>&1; then
                limine-update || echo "    limine-update reported an error — the direct edit above still stands."
            elif command -v limine-mkinitcpio >/dev/null 2>&1; then
                limine-mkinitcpio -P || echo "    limine-mkinitcpio reported an error — the direct edit above still stands."
            fi
        fi

    elif [[ -f "$GRUB_DEFAULT" ]]; then
        echo "==> GRUB detected — adding '$param' to kernel command line"
        if ! grep -qE "GRUB_CMDLINE_LINUX_DEFAULT=.*\b${param_re}\b" "$GRUB_DEFAULT"; then
            cp "$GRUB_DEFAULT" "${GRUB_DEFAULT}.bak.$(date +%s)"
            sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\")([^\"]*)(\")/\1\2 ${param}\3/" "$GRUB_DEFAULT"
            echo "    Added '$param' to GRUB_CMDLINE_LINUX_DEFAULT"
            if command -v grub-mkconfig >/dev/null 2>&1; then
                grub-mkconfig -o /boot/grub/grub.cfg
            else
                echo "!! grub-mkconfig not found — regenerate your GRUB config manually."
            fi
        else
            echo "    '$param' already present in $GRUB_DEFAULT"
        fi

    else
        local SDBOOT_ENTRIES_DIR=""
        local d
        for d in /boot/loader/entries /efi/loader/entries; do
            [[ -d "$d" ]] && SDBOOT_ENTRIES_DIR="$d" && break
        done

        if [[ -n "$SDBOOT_ENTRIES_DIR" ]]; then
            echo "==> systemd-boot detected — adding '$param' to kernel command line"
            local KERNEL_CMDLINE_FILE="/etc/kernel/cmdline"
            if [[ -f "$KERNEL_CMDLINE_FILE" ]]; then
                cp "$KERNEL_CMDLINE_FILE" "${KERNEL_CMDLINE_FILE}.bak.$(date +%s)"
                if grep -qE "\b${param_re}\b" "$KERNEL_CMDLINE_FILE"; then
                    echo "    '$param' already present in $KERNEL_CMDLINE_FILE"
                else
                    sed -i -E "s/[[:space:]]*\$//; s/\$/ ${param}/" "$KERNEL_CMDLINE_FILE"
                    echo "    Added '$param' to $KERNEL_CMDLINE_FILE"
                fi
            else
                echo "$param" > "$KERNEL_CMDLINE_FILE"
                echo "    Created $KERNEL_CMDLINE_FILE with '$param'"
            fi

            if command -v kernel-install >/dev/null 2>&1; then
                local kver_dir kver
                for kver_dir in /usr/lib/modules/*; do
                    [[ -f "$kver_dir/pkgbase" ]] || continue
                    kver="$(basename "$kver_dir")"
                    kernel-install add "$kver" "$kver_dir/vmlinuz" 2>/dev/null || true
                done
            fi

            local conf
            for conf in "$SDBOOT_ENTRIES_DIR"/*.conf; do
                [[ -f "$conf" ]] || continue
                grep -qE "^options\b.*\b${param_re}\b" "$conf" && continue
                cp "$conf" "${conf}.bak.$(date +%s)"
                if grep -qE '^options\b' "$conf"; then
                    sed -i -E "s/^(options[[:space:]].*)\$/\1 ${param}/" "$conf"
                else
                    echo "options ${param}" >> "$conf"
                fi
            done
        else
            echo "!! No Limine, GRUB, or systemd-boot configuration detected."
            echo "   Add '$param' to your bootloader's kernel command line manually."
        fi
    fi
}

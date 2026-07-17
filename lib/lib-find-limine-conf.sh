# lib-find-limine-conf.sh — sourced, not executed directly.
#
# Locates the live limine.conf on disk regardless of where the ESP is
# mounted (/boot, /efi, /boot/EFI, /boot/efi, etc). Sets $LIMINE_CONF to the
# path if found, or "" if not. Sourced by both branding/install-ativos-
# branding.sh and plymouth-theme/install-ativos-plymouth.sh so the two
# never drift out of sync.
#
# THE BUG this replaces: archinstall mounts the ESP at /boot when it's the
# only boot-related partition, but at /boot/EFI when there's a separate
# /boot partition too (common on real hardware with more deliberate
# partitioning than a quick VM install) — so limine.conf can legitimately
# end up at /boot/EFI/limine.conf, which wasn't in the hardcoded candidate
# list. That's recoverable on its own (the code fell through to a `find`
# fallback) — except that fallback searched both `/boot` AND `/efi`
# unconditionally. On a system with no separate /efi mount, `find` exits
# non-zero for the missing path; combined with `pipefail` (on the `| head
# -1`) and `set -e` in the calling script, that silently killed the ENTIRE
# branding/plymouth script right there — before anything after it (logo
# pixmap, fastfetch config, KDE icon, boot splash) ever ran. Fixed by only
# searching roots that actually exist, and belt-and-suspenders `|| true` so
# a `find` failure for any other reason can never take the whole script
# down with it again.

find_limine_conf() {
    LIMINE_CONF=""
    local c
    for c in /boot/limine.conf /boot/EFI/limine.conf /boot/EFI/limine/limine.conf \
             /boot/limine/limine.conf /boot/efi/limine.conf /boot/efi/limine/limine.conf \
             /efi/limine.conf /efi/EFI/limine.conf /efi/EFI/limine/limine.conf /efi/limine/limine.conf; do
        [[ -f "$c" ]] && LIMINE_CONF="$c" && return 0
    done

    local search_roots=()
    [[ -d /boot ]] && search_roots+=(/boot)
    [[ -d /efi  ]] && search_roots+=(/efi)
    if [[ ${#search_roots[@]} -gt 0 ]]; then
        LIMINE_CONF="$(find "${search_roots[@]}" -maxdepth 4 -iname 'limine.conf' 2>/dev/null | head -1 || true)"
    fi
    return 0
}

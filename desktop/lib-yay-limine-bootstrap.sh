# lib-yay-limine-bootstrap.sh — sourced, not executed directly.
#
# Shared helpers + the yay/Limine AUR tooling bootstrap, used by whichever
# desktop script (KDE or GNOME) runs as step 1 of install-all.sh. This used
# to live only inside install-ativos-kde.sh; pulled out here so it isn't
# silently skipped when GNOME is chosen instead — branding (step 2) and
# Plymouth (step 5) both depend on limine-mkinitcpio/limine-update existing
# by the time they run, regardless of which desktop got installed.
#
# Expects the caller to already have `set -euo pipefail` active and to be
# running as root.

if [[ -t 1 ]]; then
    C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
    C_ACCENT='\033[38;5;111m'; C_OK='\033[38;5;114m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_ACCENT=''; C_OK=''
fi
info() { printf "${C_ACCENT}==>${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}  \xe2\x9c\x94${C_RESET} %s\n" "$*"; }
warn() { printf "${C_ACCENT}  !!${C_RESET} %s\n" "$*"; }

pkg_installed() { pacman -Qi "$1" >/dev/null 2>&1; }

install_pkgs() {
    local todo=()
    for p in "$@"; do
        pkg_installed "$p" || todo+=("$p")
    done
    if [[ ${#todo[@]} -gt 0 ]]; then
        info "Installing: ${C_BOLD}${todo[*]}${C_RESET}"
        pacman -S --needed --noconfirm "${todo[@]}"
        ok "Installed: ${todo[*]}"
    else
        ok "Already installed: $*"
    fi
}

# A pacman transaction killed mid-flight (e.g. a timed-out AUR build calling
# sudo pacman internally) can leave a stale lock file that fails every
# pacman call afterwards, in every later step. Only clear it if no pacman
# process is actually running.
clear_stale_pacman_lock() {
    local lock=/var/lib/pacman/db.lck
    if [[ -f "$lock" ]] && ! pgrep -x pacman >/dev/null 2>&1; then
        warn "Removing stale pacman lock ($lock, no pacman process running)"
        rm -f "$lock"
    fi
}

# ---------------------------------------------------------------------------
# Bootstrap yay + the Limine AUR tooling (limine-entry-tool /
# limine-mkinitcpio-hook). Later steps (branding, plymouth) use
# `limine-mkinitcpio` / `limine-update` if present to regenerate
# /boot/limine.conf and keep it splash/title-correct across future kernel
# updates. Installing yay + the Limine AUR tools here, in step 1 (whichever
# desktop script runs), guarantees they exist before step 2 (branding) and
# step 5 (Plymouth) — the first steps that look for them.
#
# makepkg/yay refuse to run as root, so the actual build has to happen as a
# normal user. We use whoever invoked `sudo` ($SUDO_USER), falling back to
# the first regular (UID >= 1000) account if that's unset.
#
# Every command in here runs inside this one function, invoked by the
# caller with `|| warn ...`: bash suppresses errexit for everything inside a
# function call that's the direct operand of `||`, so nothing in here —
# however it fails — can ever abort the calling script or poison later
# steps. A hard timeout also stops a slow/stuck AUR build
# (limine-mkinitcpio-hook pulls in Gradle/GraalVM) from hanging the install
# indefinitely.
# ---------------------------------------------------------------------------
bootstrap_yay_and_limine_aur() {
    info "Bootstrapping yay + Limine AUR tooling"

    local build_user
    build_user="${ATIVOS_TARGET_USER:-${SUDO_USER:-}}"
    if [[ -z "$build_user" || "$build_user" == "root" ]]; then
        build_user="$(logname 2>/dev/null || true)"
    fi
    if [[ -z "$build_user" || "$build_user" == "root" ]]; then
        build_user="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" {print $1; exit}')"
    fi

    if [[ -z "$build_user" ]]; then
        warn "No non-root user found to build AUR packages as (makepkg refuses to run as root)."
        warn "Skipping yay/limine-mkinitcpio install — branding/plymouth will fall back to direct file edits."
        return 0
    fi

    clear_stale_pacman_lock
    install_pkgs base-devel git go

    if command -v yay >/dev/null 2>&1; then
        ok "yay already installed"
    else
        local yay_build_dir yay_pkg
        yay_build_dir="$(mktemp -d /tmp/ativos-yay-build.XXXXXX)" || return 0
        chown "$build_user" "$yay_build_dir" 2>/dev/null || true
        info "Building yay as user '$build_user' (this can take a minute)"
        if timeout 600 su - "$build_user" -c "git clone --quiet https://aur.archlinux.org/yay.git '$yay_build_dir/yay' && cd '$yay_build_dir/yay' && makepkg --noconfirm" >/tmp/ativos-yay-build.log 2>&1; then
            yay_pkg="$(find "$yay_build_dir/yay" -maxdepth 1 -name 'yay-*.pkg.tar.*' 2>/dev/null | head -1)"
            clear_stale_pacman_lock
            if [[ -n "$yay_pkg" ]] && pacman -U --needed --noconfirm "$yay_pkg"; then
                ok "yay installed"
            else
                warn "yay build produced no installable package — see /tmp/ativos-yay-build.log"
            fi
        else
            warn "Failed to build yay (or timed out after 10 minutes) — see /tmp/ativos-yay-build.log. Continuing without it."
        fi
        rm -rf "$yay_build_dir"
        clear_stale_pacman_lock
    fi

    if command -v yay >/dev/null 2>&1; then
        if pacman -Qi limine-entry-tool >/dev/null 2>&1 && pacman -Qi limine-mkinitcpio-hook >/dev/null 2>&1; then
            ok "limine-entry-tool + limine-mkinitcpio-hook already installed"
        else
            info "Installing limine-entry-tool + limine-mkinitcpio-hook via yay (as $build_user)"
            if timeout 1800 su - "$build_user" -c "yay -S --needed --noconfirm --sudoloop limine-entry-tool limine-mkinitcpio-hook" >/tmp/ativos-limine-aur-build.log 2>&1; then
                ok "limine-entry-tool + limine-mkinitcpio-hook installed"
            else
                warn "Failed to install limine-mkinitcpio-hook via yay (or timed out after 30 minutes) — see /tmp/ativos-limine-aur-build.log"
                warn "Branding/plymouth steps will fall back to direct limine.conf edits."
            fi
            clear_stale_pacman_lock
        fi
    fi

    return 0
}

#!/usr/bin/env bash
# install-ativos-kde.sh
#
# Installs full KDE Plasma 6 + a standard set of KDE applications, enables
# SDDM as the display manager, and sets sane defaults so the system boots
# straight to a Plasma login screen. Safe to re-run: anything already
# installed is left alone.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-kde.sh"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "!! pacman not found — this script only supports Arch/AtivOS."
    exit 1
fi

if [[ -t 1 ]]; then
    C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
    C_ACCENT='\033[38;5;111m'; C_OK='\033[38;5;114m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_ACCENT=''; C_OK=''
fi
info() { printf "${C_ACCENT}==>${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}  \xe2\x9c\x94${C_RESET} %s\n" "$*"; }

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

warn() { printf "${C_ACCENT}  !!${C_RESET} %s\n" "$*"; }

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
# 0. Bootstrap yay + the Limine AUR tooling (limine-entry-tool /
#    limine-mkinitcpio-hook) right here in step 1.
#
#    THE BUG: nothing in this repo ever installed these. Later steps
#    (branding, plymouth) already had code paths that USE `limine-mkinitcpio`
#    / `limine-update` if present (to regenerate /boot/limine.conf and keep
#    it splash/title-correct across future kernel updates), but since
#    nothing ever installed them, `command -v limine-mkinitcpio` was always
#    false and those code paths were silently dead — the boot splash and
#    branding steps fell back to one-shot direct file edits that never get
#    refreshed on the next kernel update. Installing yay + the Limine AUR
#    tools here, in step 1, guarantees they exist before step 2 (branding)
#    and step 5 (Plymouth) — the first steps that look for them.
#
#    makepkg/yay refuse to run as root, so the actual build has to happen
#    as a normal user. We use whoever invoked `sudo` ($SUDO_USER), falling
#    back to the first regular (UID >= 1000) account if that's unset.
#
#    THE REGRESSION (fixed here): every command in this section used to run
#    at the top level under `set -euo pipefail`. A single failure anywhere
#    in here (network hiccup mid-build, a killed AUR build, etc.) aborted
#    this ENTIRE script on the spot — and if it happened mid-pacman-
#    transaction it could leave a stale db lock that then failed pacman in
#    every step after it too, including the OOBE build. This whole thing is
#    now one function, invoked with `|| warn ...`: bash suppresses errexit
#    for everything inside a function call that's the direct operand of
#    `||`, so nothing in here — however it fails — can ever abort this
#    script or poison later steps. A hard timeout also stops a slow/stuck
#    AUR build (limine-mkinitcpio-hook pulls in Gradle/GraalVM) from
#    hanging the install indefinitely.
# ---------------------------------------------------------------------------
bootstrap_yay_and_limine_aur() {
    info "Bootstrapping yay + Limine AUR tooling"

    local build_user
    build_user="${SUDO_USER:-}"
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

bootstrap_yay_and_limine_aur || warn "yay/Limine AUR bootstrap hit an unexpected error and was skipped — continuing with the KDE install."
clear_stale_pacman_lock

info "Installing full KDE Plasma desktop"
# plasma-meta pulls the full Plasma 6 shell (Kickoff, Kicker, System Settings,
# KScreen, Discover, plasma-nm, etc). kde-applications-meta is deliberately
# *not* used here (it's enormous) — instead we pull the everyday-use subset
# a new install actually needs, matching the "Full Plasma" experience users
# expect (Dolphin, Konsole, text editor, archive tool, etc).
install_pkgs \
    plasma-meta \
    sddm \
    dolphin dolphin-plugins \
    konsole \
    kate \
    ark \
    gwenview \
    spectacle \
    kcalc \
    okular \
    kwalletmanager \
    ksystemlog \
    partitionmanager \
    ffmpegthumbs \
    kdeconnect \
    plasma-systemmonitor \
    print-manager \
    xdg-desktop-portal-kde \
    qt6-imageformats \
    layer-shell-qt

info "Enabling SDDM"
systemctl enable sddm >/dev/null
ok "SDDM enabled"

# THE BUG: SDDM's own greeter runs under X11 by default, regardless of
# which session type (X11/Wayland) the user picks afterward — this has to
# be explicitly overridden. On systems where the Xorg/vmwgfx interaction
# is broken (a long-standing class of VMware guest bug: crashes on GB
# surface creation, "failed to create vmw_framebuffer: -22"), that default
# X11 greeter is what actually hangs at boot with a blank screen and a
# blinking cursor — even on an otherwise fully-Wayland Plasma setup. Force
# the greeter itself onto Wayland too, so it never touches that code path.
info "Configuring SDDM to use a Wayland greeter"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/09-ativos-wayland-greeter.conf <<'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts
EOF
ok "SDDM greeter set to Wayland (kwin_wayland)"

info "Setting Breeze Dark as the SDDM login theme"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-ativos-theme.conf <<'EOF'
[Theme]
Current=breeze
CursorTheme=breeze_cursors

[General]
InputMethod=
EOF

ok "KDE Plasma installed. SDDM will start on next boot."

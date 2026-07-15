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
    qt6-imageformats

info "Enabling SDDM"
systemctl enable sddm >/dev/null
ok "SDDM enabled"

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

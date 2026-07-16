#!/usr/bin/env bash
# install-ativos-apps.sh
#
# Installs AtivOS's default app set: Firefox and fastfetch straight from
# the Arch repos, plus Discord and Spotify from Flathub via Flatpak (both
# ship as Flatpak-only/AUR-only on Arch, so Flatpak is the reliable route
# for a fresh install). Safe to re-run: anything already installed is left
# alone.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-apps.sh"
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

# A pacman transaction killed mid-flight can leave a stale lock file that
# fails every pacman call afterwards. Only clear it if nothing is actually
# mid-transaction.
PACMAN_LOCK=/var/lib/pacman/db.lck
if [[ -f "$PACMAN_LOCK" ]] && ! pgrep -x pacman >/dev/null 2>&1; then
    info "Removing stale pacman lock ($PACMAN_LOCK, no pacman process running)"
    rm -f "$PACMAN_LOCK"
fi

# ---- 1. native repo packages ----------------------------------------------
install_pkgs firefox fastfetch flatpak

# ---- 2. flathub remote -----------------------------------------------------
# System-wide remote so the apps are available to every account, not just
# whoever runs this installer.
if flatpak remote-list 2>/dev/null | grep -q '^flathub\b'; then
    ok "Flathub remote already configured"
else
    info "Adding the Flathub remote"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    ok "Flathub remote added"
fi

# ---- 3. flatpak apps -------------------------------------------------------
install_flatpak() {
    local app_id="$1" name="$2"
    if flatpak info "$app_id" >/dev/null 2>&1; then
        ok "Already installed: $name"
    else
        info "Installing: ${C_BOLD}${name}${C_RESET} (Flatpak, ${app_id})"
        if flatpak install --system --noninteractive flathub "$app_id"; then
            ok "Installed: $name"
        else
            warn "Failed to install $name — check your network connection and re-run this script."
        fi
    fi
}

install_flatpak com.discordapp.Discord Discord
install_flatpak com.spotify.Client     Spotify

echo ""
ok "Default apps ready: Firefox, fastfetch, Discord, Spotify."

#!/usr/bin/env bash
# install-ativos-shell.sh
#
# CachyOS-style shell setup: fish + starship as the default for new user
# accounts, plus eza/bat (modern ls/cat) and a Nerd Font so the prompt's
# icons render correctly. Existing accounts and root are left untouched —
# this only changes what *new* users get.
#
# Safe to re-run.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-shell.sh"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "!! pacman not found — this script only supports Arch/AtivOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="$SCRIPT_DIR/files"

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
    else
        ok "Already installed: $*"
    fi
}

PACMAN_LOCK=/var/lib/pacman/db.lck
if [[ -f "$PACMAN_LOCK" ]] && ! pgrep -x pacman >/dev/null 2>&1; then
    info "Removing stale pacman lock ($PACMAN_LOCK, no pacman process running)"
    rm -f "$PACMAN_LOCK"
fi

# ---- 1. packages -----------------------------------------------------
info "Installing fish, starship, and modern CLI tools"
install_pkgs fish starship eza bat ttf-jetbrains-mono-nerd
ok "Packages installed"

# ---- 2. register fish as a valid login shell -----------------------------
if ! grep -qx '/usr/bin/fish' /etc/shells 2>/dev/null; then
    info "Adding /usr/bin/fish to /etc/shells"
    echo /usr/bin/fish >> /etc/shells
fi

# ---- 3. make fish the default shell for newly created users -------------
info "Setting fish as the default shell for new user accounts"
if [[ -f /etc/default/useradd ]]; then
    if grep -q '^SHELL=' /etc/default/useradd; then
        sed -i 's|^SHELL=.*|SHELL=/usr/bin/fish|' /etc/default/useradd
    else
        echo 'SHELL=/usr/bin/fish' >> /etc/default/useradd
    fi
else
    echo 'SHELL=/usr/bin/fish' > /etc/default/useradd
fi
ok "New accounts created with useradd now default to fish"

# ---- 4. starship prompt for new users ------------------------------------
info "Generating the starship prompt config"
mkdir -p /etc/skel/.config
# "pastel-powerline" is one of starship's built-in presets — colorful,
# segmented, and readable, and renders correctly with the Nerd Font we
# just installed.
starship preset pastel-powerline -o /etc/skel/.config/starship.toml

# ---- 5. fish config for new users ----------------------------------------
info "Installing default fish config"
mkdir -p /etc/skel/.config/fish
install -Dm644 "$FILES_DIR/config.fish" /etc/skel/.config/fish/config.fish

echo ""
ok "Shell setup complete."
echo "   New user accounts will get fish + starship automatically."
echo "   To switch your own account over: chsh -s /usr/bin/fish \$USER"

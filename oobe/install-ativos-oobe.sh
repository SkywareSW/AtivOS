#!/usr/bin/env bash
# install-ativos-oobe.sh
#
# Builds and installs the AtivOS Setup Assistant: a Qt6/QML first-boot
# wizard that walks a new user through language, appearance, network,
# privacy, and an avatar picture. It autostarts once per account (via
# /etc/xdg/autostart) and marks itself done in ~/.config/ativos/oobe-done
# so it never shows again after the user finishes it.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-oobe.sh"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "!! pacman not found — this script only supports Arch/AtivOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pkg_installed() { pacman -Qi "$1" >/dev/null 2>&1; }
install_pkgs() {
    local todo=()
    for p in "$@"; do
        pkg_installed "$p" || todo+=("$p")
    done
    if [[ ${#todo[@]} -gt 0 ]]; then
        echo "==> Installing: ${todo[*]}"
        pacman -S --needed --noconfirm "${todo[@]}"
    else
        echo "    Already installed: $*"
    fi
}

echo "==> Installing build + runtime dependencies"
install_pkgs cmake ninja qt6-base qt6-declarative qt6-svg polkit accountsservice

echo "==> Building AtivOS Setup Assistant"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

echo "==> Installing binary"
install -Dm755 "$BUILD_DIR/ativos-oobe" /usr/bin/ativos-oobe

echo "==> Installing launcher + autostart entry"
install -Dm755 "$SCRIPT_DIR/ativos-oobe-launch" /usr/bin/ativos-oobe-launch
install -Dm644 "$SCRIPT_DIR/org.ativos.oobe.desktop" /etc/xdg/autostart/org.ativos.oobe.desktop

echo "==> Installing avatar helper + polkit policy"
install -Dm755 "$SCRIPT_DIR/ativos-set-avatar" /usr/local/bin/ativos-set-avatar
install -Dm644 "$SCRIPT_DIR/org.ativos.oobe.setavatar.policy" /usr/share/polkit-1/actions/org.ativos.oobe.setavatar.policy

echo ""
echo "==> AtivOS Setup Assistant installed."
echo "    It will run automatically the first time each user logs into Plasma."
echo "    To preview it now as the current user: ativos-oobe"
echo "    To reset it and see it again: rm -f ~/.config/ativos/oobe-done"

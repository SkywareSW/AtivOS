#!/usr/bin/env bash
# setup-ativ.sh — installs the `ativ` package manager onto an Arch/AtivOS system.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./setup-ativ.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing ativ to /usr/local/bin/ativ"
install -Dm755 "$SCRIPT_DIR/ativ" /usr/local/bin/ativ

echo "==> Creating /etc/ativ/ativ.conf"
mkdir -p /etc/ativ
if [[ ! -f /etc/ativ/ativ.conf ]]; then
    cat > /etc/ativ/ativ.conf <<'EOF'
# ativ configuration
# Set to false to disable colored output
COLOR=true

# Set to true to skip all confirmation prompts by default
# (equivalent to always passing --noconfirm)
NOCONFIRM=false

# Space-separated list of packages ativ will warn before removing
PROTECTED_PACKAGES="base base-devel linux linux-lts linux-firmware systemd glibc sudo pacman filesystem"

# Where AUR packages are cloned/built (per-user, expanded via $HOME at runtime)
# BUILD_DIR="$HOME/.cache/ativ/build"
EOF
    echo "    Created default config."
else
    echo "    Config already exists, leaving it untouched."
fi

echo "==> Creating /var/log/ativ.log"
touch /var/log/ativ.log
chmod 666 /var/log/ativ.log   # any user running ativ can log to it

echo ""
echo "==> Done. Try: ativ --help"

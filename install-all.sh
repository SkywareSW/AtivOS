#!/usr/bin/env bash
# install-all.sh — runs all AtivOS installers in sequence.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-all.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "############################################"
echo "# 1/3 — Branding"
echo "############################################"
"$SCRIPT_DIR/branding/install-ativos-branding.sh"

echo ""
echo "############################################"
echo "# 2/3 — ativ package manager"
echo "############################################"
"$SCRIPT_DIR/package-manager/setup-ativ.sh"

echo ""
echo "############################################"
echo "# 3/3 — Plymouth boot splash"
echo "############################################"
"$SCRIPT_DIR/plymouth-theme/install-ativos-plymouth.sh"

echo ""
echo "==> All AtivOS components installed. Reboot to see the boot splash."

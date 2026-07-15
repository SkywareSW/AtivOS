#!/usr/bin/env bash
# install-all.sh — runs all AtivOS installers in sequence.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-all.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make sure the sub-scripts are executable regardless of how this repo was
# transferred (unzip and some git configs can strip the +x bit).
chmod +x "$SCRIPT_DIR"/desktop/install-ativos-kde.sh \
         "$SCRIPT_DIR"/branding/install-ativos-branding.sh \
         "$SCRIPT_DIR"/package-manager/setup-ativ.sh \
         "$SCRIPT_DIR"/package-manager/ativ \
         "$SCRIPT_DIR"/plymouth-theme/install-ativos-plymouth.sh \
         "$SCRIPT_DIR"/gpu-drivers/install-ativos-gpu-drivers.sh \
         "$SCRIPT_DIR"/oobe/install-ativos-oobe.sh 2>/dev/null || true

echo "############################################"
echo "# 1/6 — KDE Plasma desktop"
echo "############################################"
bash "$SCRIPT_DIR/desktop/install-ativos-kde.sh"

echo ""
echo "############################################"
echo "# 2/6 — Branding"
echo "############################################"
bash "$SCRIPT_DIR/branding/install-ativos-branding.sh"

echo ""
echo "############################################"
echo "# 3/6 — ativ package manager"
echo "############################################"
bash "$SCRIPT_DIR/package-manager/setup-ativ.sh"

echo ""
echo "############################################"
echo "# 4/6 — GPU drivers"
echo "############################################"
bash "$SCRIPT_DIR/gpu-drivers/install-ativos-gpu-drivers.sh"

echo ""
echo "############################################"
echo "# 5/6 — Plymouth boot splash"
echo "############################################"
bash "$SCRIPT_DIR/plymouth-theme/install-ativos-plymouth.sh"

echo ""
echo "############################################"
echo "# 6/6 — First-boot setup assistant (OOBE)"
echo "############################################"
bash "$SCRIPT_DIR/oobe/install-ativos-oobe.sh"

echo ""
echo "==> All AtivOS components installed. Reboot to land on the SDDM login"
echo "    screen — the Setup Assistant will greet you on first login."

#!/usr/bin/env bash
# install-ativos-gnome.sh
#
# Installs full GNOME 47 + a standard set of GNOME applications, enables
# GDM as the display manager, and sets sane defaults so the system boots
# straight to a GNOME login screen. Safe to re-run: anything already
# installed is left alone.
#
# Mirrors install-ativos-kde.sh (same helpers, same defensive patterns,
# same yay/Limine AUR bootstrap) so branding/Plymouth/OOBE behave
# identically regardless of which desktop was chosen.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-ativos-gnome.sh"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "!! pacman not found — this script only supports Arch/AtivOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib-yay-limine-bootstrap.sh
source "$SCRIPT_DIR/lib-yay-limine-bootstrap.sh"

# Bootstraps yay + limine-entry-tool/limine-mkinitcpio-hook so branding
# (step 2) and Plymouth (step 5) have them by the time they run. See
# lib-yay-limine-bootstrap.sh for why this has to happen in whichever
# desktop script runs as step 1, and why it can never abort this script.
bootstrap_yay_and_limine_aur || warn "yay/Limine AUR bootstrap hit an unexpected error and was skipped — continuing with the GNOME install."
clear_stale_pacman_lock

info "Installing full GNOME desktop"
# gnome pulls the full GNOME shell + core apps (Files, Settings, Software,
# Terminal, Text Editor, etc). gnome-extra is deliberately *not* used here
# (it's enormous and includes things like a full games suite) — instead we
# pull the everyday-use subset a new install actually needs, matching the
# "Full GNOME" experience users expect (Files, Terminal, image viewer,
# archive tool, etc), plus GSConnect as the closest equivalent to KDE
# Connect for phone integration.
install_pkgs \
    gnome \
    gdm \
    gnome-tweaks \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-gsconnect \
    gnome-terminal \
    gnome-text-editor \
    file-roller \
    loupe \
    gnome-screenshot \
    gnome-calculator \
    evince \
    gnome-disk-utility \
    gnome-system-monitor \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk

info "Enabling GDM"
systemctl enable gdm >/dev/null
ok "GDM enabled"

# Unlike SDDM, GDM already defaults to a Wayland greeter on modern Arch —
# no override needed there. The same class of VMware guest bug that forces
# SDDM onto Wayland (Xorg/vmwgfx crashing on GB surface creation) can still
# bite a GNOME *session* if a user manually selects the "GNOME on Xorg"
# option at the login screen, but that's a user choice at login time, not
# something this script should silently take away — so we leave the Xorg
# session entry in place and don't touch it.

ok "GNOME installed. GDM will start on next boot."

#!/usr/bin/env bash
#
# install-ativos-branding.sh
# Rebrands an Arch Linux install as "AtivOS":
#   - /etc/os-release (+ lsb-release, issue)
#   - fastfetch custom logo (ascii or image)
#   - KDE Plasma: system icon theme override + Kickoff (start button) icon
#
# USAGE:
#   1. Drop your assets in ~/ativos-assets/ before running:
#        ~/ativos-assets/logo.png     -> full-color logo (any size, square works best)
#        ~/ativos-assets/ascii.txt    -> plain-text ASCII art for fastfetch (optional)
#        ~/ativos-assets/start.png    -> icon for the KDE start button (square, 256x256+ recommended)
#      If start.png is missing, logo.png is reused for the start button.
#      If ascii.txt is missing, fastfetch falls back to the image logo (needs a
#      terminal with kitty/sixel/iterm2 image protocol support) or the distro's
#      built-in fallback.
#   2. Run:  chmod +x install-ativos-branding.sh && sudo ./install-ativos-branding.sh
#      (it needs sudo for the system files; it will pick up your real user's
#       home directory automatically via SUDO_USER for the KDE bits)
#   3. Log out and back in to Plasma for the icon theme / start button to refresh.
#
set -euo pipefail

# ---------- 0. figure out real user (script is expected to run via sudo) ----------
if [[ $EUID -ne 0 ]]; then
    echo "Please run this with sudo: sudo ./install-ativos-branding.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/ativos-assets/logo.png" ]]; then
    ASSETS_DIR="$SCRIPT_DIR/ativos-assets"
else
    ASSETS_DIR="$REAL_HOME/ativos-assets"
fi

LOGO_SRC="$ASSETS_DIR/logo.png"
ASCII_SRC="$ASSETS_DIR/ascii.txt"
START_SRC="$ASSETS_DIR/start.png"

echo "==> AtivOS branding installer"
echo "    Target user : $REAL_USER"
echo "    Assets dir  : $ASSETS_DIR"

if [[ ! -f "$LOGO_SRC" ]]; then
    echo "!! Warning: $LOGO_SRC not found. Image-based branding (KDE icons, pixmap logo) will be skipped."
fi

# =========================================================================
# 1. /etc/os-release, lsb-release, issue  -> makes "About This System",
#    neofetch/fastfetch, KInfoCenter, and login banners show AtivOS
# =========================================================================
echo "==> Writing /etc/os-release"

OS_RELEASE_FILE="/etc/os-release"
# /etc/os-release is usually a symlink to /usr/lib/os-release on Arch; edit the real target
if [[ -L "$OS_RELEASE_FILE" ]]; then
    OS_RELEASE_FILE=$(readlink -f /etc/os-release)
fi
cp -a "$OS_RELEASE_FILE" "${OS_RELEASE_FILE}.bak.$(date +%s)" 2>/dev/null || true

BUILD_ID="$(date +%Y.%m.%d)"

cat > "$OS_RELEASE_FILE" <<EOF
NAME="AtivOS"
PRETTY_NAME="AtivOS"
ID=ativos
ID_LIKE=arch
BUILD_ID="$BUILD_ID"
ANSI_COLOR="38;2;120;170;255"
HOME_URL="https://ativos.local"
DOCUMENTATION_URL="https://ativos.local/docs"
SUPPORT_URL="https://ativos.local/support"
BUG_REPORT_URL="https://ativos.local/issues"
LOGO=ativos-logo
EOF

echo "==> Writing /etc/lsb-release"
cat > /etc/lsb-release <<EOF
DISTRIB_ID=AtivOS
DISTRIB_RELEASE=rolling
DISTRIB_CODENAME=ativos
DISTRIB_DESCRIPTION="AtivOS"
EOF

echo "==> Writing /etc/issue and /etc/issue.net"
cat > /etc/issue <<'EOF'
AtivOS \r (\l)

EOF
cp /etc/issue /etc/issue.net

# =========================================================================
# 2. Logo pixmap for tools that read the LOGO= key (GNOME Software, some
#    fetch tools, KInfoCenter icon) — installed as /usr/share/pixmaps
# =========================================================================
if [[ -f "$LOGO_SRC" ]]; then
    echo "==> Installing system logo pixmap"
    install -Dm644 "$LOGO_SRC" /usr/share/pixmaps/ativos-logo.png
    # Also register it in the icon theme so icon-name lookups (ativos-logo) resolve
    install -Dm644 "$LOGO_SRC" /usr/share/icons/hicolor/256x256/apps/ativos-logo.png
    gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

# =========================================================================
# 3. fastfetch custom logo
# =========================================================================
echo "==> Configuring fastfetch"

FASTFETCH_CFG_DIR="$REAL_HOME/.config/fastfetch"
sudo -u "$REAL_USER" mkdir -p "$FASTFETCH_CFG_DIR"

if [[ -f "$ASCII_SRC" ]]; then
    install -Dm644 "$ASCII_SRC" "$FASTFETCH_CFG_DIR/ativos-ascii.txt"
    chown "$REAL_USER":"$REAL_USER" "$FASTFETCH_CFG_DIR/ativos-ascii.txt"
    LOGO_JSON=$(cat <<EOF
  "logo": {
    "type": "file",
    "source": "$FASTFETCH_CFG_DIR/ativos-ascii.txt",
    "padding": { "top": 1, "left": 2 }
  },
EOF
)
elif [[ -f "$LOGO_SRC" ]]; then
    install -Dm644 "$LOGO_SRC" "$FASTFETCH_CFG_DIR/ativos-logo.png"
    chown "$REAL_USER":"$REAL_USER" "$FASTFETCH_CFG_DIR/ativos-logo.png"
    LOGO_JSON=$(cat <<EOF
  "logo": {
    "type": "kitty",
    "source": "$FASTFETCH_CFG_DIR/ativos-logo.png",
    "width": 30,
    "height": 15
  },
EOF
)
else
    LOGO_JSON=""
fi

CONFIG_JSONC="$FASTFETCH_CFG_DIR/config.jsonc"
if [[ ! -f "$CONFIG_JSONC" ]]; then
    cat > "$CONFIG_JSONC" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
$LOGO_JSON
  "display": {
    "separator": " -> "
  },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "de",
    "wm",
    "terminal",
    "cpu",
    "gpu",
    "memory",
    "disk",
    "break",
    "colors"
  ]
}
EOF
else
    echo "    Existing config.jsonc found — not overwriting. Add the 'logo' block above manually:"
    echo "$LOGO_JSON"
fi
chown -R "$REAL_USER":"$REAL_USER" "$FASTFETCH_CFG_DIR"

# fastfetch also reads a distro-detection string; force it via os-release ID/NAME
# already set above, so no extra fastfetch flag is required.

# =========================================================================
# 4. KDE Plasma — icon theme override + Kickoff (start button) icon
# =========================================================================
if command -v plasmashell >/dev/null 2>&1 || [[ -d "$REAL_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] || [[ -f "$REAL_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
    echo "==> Setting up KDE branding"

    ICON_THEME_DIR="/usr/share/icons/AtivOS"
    START_ICON="${START_SRC}"
    [[ -f "$START_ICON" ]] || START_ICON="$LOGO_SRC"

    if [[ -f "$START_ICON" ]]; then
        echo "    Building AtivOS icon theme (inherits Breeze) with custom start-here-kde icon"

        mkdir -p "$ICON_THEME_DIR"/{16x16,22x22,32x32,48x48,64x64,128x128,256x256}/{apps,actions}
        mkdir -p "$ICON_THEME_DIR/scalable/apps"

        cat > "$ICON_THEME_DIR/index.theme" <<EOF
[Icon Theme]
Name=AtivOS
Comment=AtivOS custom icon overrides
Inherits=Breeze,breeze-dark,hicolor
Directories=16x16/apps,22x22/apps,32x32/apps,48x48/apps,64x64/apps,128x128/apps,256x256/apps

[16x16/apps]
Size=16
Context=Applications
Type=Fixed

[22x22/apps]
Size=22
Context=Applications
Type=Fixed

[32x32/apps]
Size=32
Context=Applications
Type=Fixed

[48x48/apps]
Size=48
Context=Applications
Type=Fixed

[64x64/apps]
Size=64
Context=Applications
Type=Fixed

[128x128/apps]
Size=128
Context=Applications
Type=Fixed

[256x256/apps]
Size=256
Context=Applications
Type=Fixed
EOF

        # Same source image scaled into each bucket via ImageMagick if available,
        # otherwise just copied as-is (KDE will scale on render).
        for size in 16 22 32 48 64 128 256; do
            dest="$ICON_THEME_DIR/${size}x${size}/apps/start-here-kde.png"
            if command -v convert >/dev/null 2>&1; then
                convert "$START_ICON" -resize "${size}x${size}" "$dest"
            else
                cp "$START_ICON" "$dest"
            fi
        done

        gtk-update-icon-cache -f "$ICON_THEME_DIR" >/dev/null 2>&1 || true

        # Set AtivOS as the active Plasma icon theme for the real user
        sudo -u "$REAL_USER" kwriteconfig6 --file kdeglobals --group Icons --key Theme "AtivOS" 2>/dev/null \
            || sudo -u "$REAL_USER" kwriteconfig5 --file kdeglobals --group Icons --key Theme "AtivOS" 2>/dev/null \
            || true

        echo "    Icon theme installed at $ICON_THEME_DIR and set as active theme."
        echo "    NOTE: if your Kickoff/start-button applet has a manually pinned icon"
        echo "    (right-click widget -> icon), it overrides the theme icon. In that case,"
        echo "    right-click the start button -> Configure -> click the icon -> pick the"
        echo "    file at: $START_ICON"
    else
        echo "    Skipping KDE icon theme: no start.png or logo.png found in $ASSETS_DIR"
    fi
else
    echo "==> KDE Plasma not detected on this system — skipping KDE branding step"
fi

# =========================================================================
# 5. Done
# =========================================================================
echo ""
echo "==> AtivOS branding applied."
echo "    - Reopen a terminal and run 'fastfetch' to see the new logo/name."
echo "    - Log out and back into Plasma to refresh icon theme + start button."
echo "    - Original os-release backed up alongside the original file."

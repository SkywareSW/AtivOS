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
# 1b. Limine boot menu entry name
#
#     THE BUG: on systems using limine-entry-tool / limine-mkinitcpio-hook
#     (the standard Limine kernel-entry manager on Arch and Arch-based
#     distros like CachyOS), the boot menu title comes from TARGET_OS_NAME
#     in /etc/default/limine — NOT from /etc/os-release. If that variable
#     is unset (the default), the tool falls back to the hardcoded name
#     "Arch Linux", which is why entries kept showing "Arch Linux (linux)"
#     no matter what os-release said. Renaming is safe at any time — entries
#     are tracked by machine-id, not by name.
# =========================================================================
echo "==> Configuring Limine boot menu entry name"

LIMINE_DEFAULT="/etc/default/limine"
if command -v limine-entry-tool >/dev/null 2>&1 || [[ -f "$LIMINE_DEFAULT" ]] || [[ -f /etc/limine-entry-tool.conf ]]; then
    if [[ ! -f "$LIMINE_DEFAULT" ]]; then
        if [[ -f /etc/limine-entry-tool.conf ]]; then
            cp /etc/limine-entry-tool.conf "$LIMINE_DEFAULT"
        else
            touch "$LIMINE_DEFAULT"
        fi
    fi
    cp "$LIMINE_DEFAULT" "${LIMINE_DEFAULT}.bak.$(date +%s)" 2>/dev/null || true

    if grep -qE '^\s*#?\s*TARGET_OS_NAME=' "$LIMINE_DEFAULT"; then
        sed -i -E 's/^\s*#?\s*TARGET_OS_NAME=.*/TARGET_OS_NAME="AtivOS"/' "$LIMINE_DEFAULT"
    else
        echo 'TARGET_OS_NAME="AtivOS"' >> "$LIMINE_DEFAULT"
    fi
    echo "    Set TARGET_OS_NAME=\"AtivOS\" in $LIMINE_DEFAULT"

    # Also sweep any already-generated limine.conf so the rename is visible
    # immediately, without waiting on the next kernel install/update to
    # trigger regeneration.
    for conf in /boot/limine.conf /boot/EFI/limine/limine.conf /boot/limine/limine.conf; do
        [[ -f "$conf" ]] && sed -i 's/Arch Linux/AtivOS/g' "$conf" 2>/dev/null || true
    done

    if command -v limine-mkinitcpio >/dev/null 2>&1; then
        echo "    Regenerating Limine entries via limine-mkinitcpio"
        limine-mkinitcpio -P || true
    elif command -v limine-update >/dev/null 2>&1; then
        echo "    Regenerating Limine entries via limine-update"
        limine-update || true
    else
        echo "    No limine-mkinitcpio/limine-update found — entries already patched in place;"
        echo "    they'll read \"AtivOS\" from here on once regenerated."
    fi
else
    echo "    No Limine entry tool detected — skipping (GRUB/systemd-boot users: nothing to do here)."
fi

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

        # THE BUG: two things were wrong before.
        #  1. "Type=Fixed" buckets only match a size EXACTLY (16, 22, 32...).
        #     Any lookup for an in-between size (e.g. 20px, 24px — common at
        #     fractional display scaling) had no match in our theme and fell
        #     straight through to the inherited Breeze icon instead.
        #  2. Kickoff/Kicker most commonly looks up "start-here-kde-symbolic",
        #     not "start-here-kde" — we only ever shipped the non-symbolic
        #     name, so the symbolic lookup always resolved to Breeze.
        # Fix: use "Type=Scalable" with a generous MinSize/MaxSize range so
        # every requested size lands inside our bucket, and ship both icon
        # names.
        cat > "$ICON_THEME_DIR/index.theme" <<EOF
[Icon Theme]
Name=AtivOS
Comment=AtivOS custom icon overrides
Inherits=Breeze,breeze-dark,hicolor
Directories=16x16/apps,22x22/apps,32x32/apps,48x48/apps,64x64/apps,128x128/apps,256x256/apps

[16x16/apps]
Size=16
MinSize=8
MaxSize=20
Context=Applications
Type=Scalable

[22x22/apps]
Size=22
MinSize=20
MaxSize=28
Context=Applications
Type=Scalable

[32x32/apps]
Size=32
MinSize=28
MaxSize=40
Context=Applications
Type=Scalable

[48x48/apps]
Size=48
MinSize=40
MaxSize=56
Context=Applications
Type=Scalable

[64x64/apps]
Size=64
MinSize=56
MaxSize=96
Context=Applications
Type=Scalable

[128x128/apps]
Size=128
MinSize=96
MaxSize=192
Context=Applications
Type=Scalable

[256x256/apps]
Size=256
MinSize=192
MaxSize=512
Context=Applications
Type=Scalable
EOF

        # Same source image scaled into each bucket via ImageMagick if available,
        # otherwise just copied as-is (KDE will scale on render). Ship both the
        # regular and "-symbolic" icon names since different Kickoff/Kicker
        # configurations look up either one.
        for size in 16 22 32 48 64 128 256; do
            for name in start-here-kde start-here-kde-symbolic; do
                dest="$ICON_THEME_DIR/${size}x${size}/apps/${name}.png"
                if command -v convert >/dev/null 2>&1; then
                    convert "$START_ICON" -resize "${size}x${size}" "$dest"
                else
                    cp "$START_ICON" "$dest"
                fi
            done
        done

        gtk-update-icon-cache -f "$ICON_THEME_DIR" >/dev/null 2>&1 || true

        # Set AtivOS as the active Plasma icon theme for the real user
        sudo -u "$REAL_USER" kwriteconfig6 --file kdeglobals --group Icons --key Theme "AtivOS" 2>/dev/null \
            || sudo -u "$REAL_USER" kwriteconfig5 --file kdeglobals --group Icons --key Theme "AtivOS" 2>/dev/null \
            || true

        # THE OTHER COMMON CAUSE: the Kickoff/Kicker widget can have its icon
        # pinned directly in the applet's own config (set via right-click ->
        # Configure -> click the icon), which always wins over the icon
        # theme no matter what we do above. Patch that directly so it "just
        # works" without a manual step.
        APPLETSRC="$REAL_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
        if [[ -f "$APPLETSRC" ]]; then
            echo "    Checking for a pinned start-button icon override in Plasma config"
            sudo -u "$REAL_USER" python3 - "$APPLETSRC" "$START_ICON" <<'PYEOF'
import re, sys

path, icon_path = sys.argv[1], sys.argv[2]
with open(path, "r") as f:
    text = f.read()

# Split into (header, body) blocks. KDE ini files store nested group paths
# as one literal bracketed header string, e.g. "[Containments][2][Applets][3]".
blocks = re.split(r'^(\[.*\])$', text, flags=re.M)
# blocks[0] is any pre-content; then alternating header/body pairs
kickoff_prefixes = []
for i in range(1, len(blocks), 2):
    header, body = blocks[i], blocks[i + 1] if i + 1 < len(blocks) else ""
    m = re.match(r'^\[(Containments\]\[\d+\]\[Applets\]\[\d+)\]$', header)
    if m and re.search(r'^plugin=org\.kde\.plasma\.(kickoff|kicker)\s*$', body, flags=re.M):
        kickoff_prefixes.append(m.group(1))

if not kickoff_prefixes:
    print("    No Kickoff/Kicker applet found in config (nothing to patch).")
    sys.exit(0)

changed = False
for prefix in kickoff_prefixes:
    cfg_header = f"[{prefix}][Configuration][General]"
    idx = text.find(cfg_header)
    if idx == -1:
        # No Configuration][General block yet for this applet -- create one
        # after the *entire* applet section (header + body), not right after
        # the header line, or we'd split the header from its own "plugin="
        # body line.
        applet_header = f"[{prefix}]\n"
        pos = text.find(applet_header)
        if pos == -1:
            continue
        body_start = pos + len(applet_header)
        next_header = text.find("\n[", body_start)
        insert_at = next_header if next_header != -1 else len(text)
        insertion = f"\n{cfg_header}\nicon={icon_path}\n"
        text = text[:insert_at] + insertion + text[insert_at:]
        changed = True
    else:
        block_start = idx + len(cfg_header)
        next_header = text.find("\n[", block_start)
        block_end = next_header if next_header != -1 else len(text)
        block = text[block_start:block_end]
        if re.search(r'^icon=', block, flags=re.M):
            block = re.sub(r'^icon=.*$', f"icon={icon_path}", block, flags=re.M)
        else:
            block = f"\nicon={icon_path}" + block
        text = text[:block_start] + block + text[block_end:]
        changed = True

if changed:
    with open(path, "w") as f:
        f.write(text)
    print(f"    Pinned start-button icon overridden to {icon_path} for {len(kickoff_prefixes)} applet(s).")
PYEOF
        fi

        echo "    Icon theme installed at $ICON_THEME_DIR and set as active theme."
        echo "    Log out and back in (or run 'kquitapp6 plasmashell; kstart6 plasmashell')"
        echo "    for the new start-button icon to show up."
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

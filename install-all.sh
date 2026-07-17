#!/usr/bin/env bash
# install-all.sh — runs all AtivOS installers in sequence.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-all.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- styling ---------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
    C_ACCENT='\033[38;5;111m'; C_OK='\033[38;5;114m'; C_ERR='\033[38;5;203m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_ACCENT=''; C_OK=''; C_ERR=''
fi

TOTAL_STEPS=9
STEP_NUM=0
FAILED_STEPS=()

hr() { printf "${C_DIM}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 60))"; }

banner() {
    printf "\n${C_ACCENT}${C_BOLD}"
    cat <<'EOF'
      _   _   _         ___  ____
     / \ | |_(_)_   __ / _ \/ ___|
    / _ \| __| \ \ / /| | | \___ \
   / ___ \ |_| |\ V / | |_| |___) |
  /_/   \_\__|_| \_/   \___/|____/
EOF
    printf "${C_RESET}${C_DIM}  installing your system, step by step${C_RESET}\n\n"
}

step_header() {
    STEP_NUM=$((STEP_NUM + 1))
    echo ""
    hr
    printf "${C_ACCENT}${C_BOLD} [%d/%d]${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$STEP_NUM" "$TOTAL_STEPS" "$1"
    hr
}

run_step() {
    local name="$1" script="$2"
    step_header "$name"
    local start
    start=$(date +%s)
    if bash "$script"; then
        local elapsed=$(( $(date +%s) - start ))
        printf "${C_OK}  \xe2\x9c\x94 done${C_RESET} ${C_DIM}(%ss)${C_RESET}\n" "$elapsed"
    else
        local elapsed=$(( $(date +%s) - start ))
        printf "${C_ERR}  \xe2\x9c\x98 failed${C_RESET} ${C_DIM}(%ss)${C_RESET} \xe2\x80\x94 continuing with the remaining steps.\n" "$elapsed"
        FAILED_STEPS+=("$name")
    fi
}

# Make sure the sub-scripts are executable regardless of how this repo was
# transferred (unzip and some git configs can strip the +x bit).
chmod +x "$SCRIPT_DIR"/desktop/install-ativos-kde.sh \
         "$SCRIPT_DIR"/desktop/install-ativos-gnome.sh \
         "$SCRIPT_DIR"/branding/install-ativos-branding.sh \
         "$SCRIPT_DIR"/package-manager/setup-ativ.sh \
         "$SCRIPT_DIR"/package-manager/ativ \
         "$SCRIPT_DIR"/plymouth-theme/install-ativos-plymouth.sh \
         "$SCRIPT_DIR"/gpu-drivers/install-ativos-gpu-drivers.sh \
         "$SCRIPT_DIR"/apps/install-ativos-apps.sh \
         "$SCRIPT_DIR"/performance/install-ativos-performance.sh \
         "$SCRIPT_DIR"/shell/install-ativos-shell.sh \
         "$SCRIPT_DIR"/oobe/install-ativos-oobe.sh 2>/dev/null || true

banner

# ---- desktop environment choice --------------------------------------
# ATIVOS_DESKTOP can be set ahead of time (plasma|gnome) to skip the
# prompt entirely — useful for scripted/unattended installs, e.g.:
#   ATIVOS_DESKTOP=gnome sudo -E ./install-all.sh
DESKTOP_CHOICE="${ATIVOS_DESKTOP:-}"

# If a desktop is already installed on this system (e.g. re-running
# install-all.sh after the initial install, to pick up fixes to the other
# steps — branding, GPU drivers, Plymouth, etc.), don't make the person
# answer the same "which desktop" question again every time. Detect
# whichever one is actually present and reuse it silently. ATIVOS_DESKTOP
# above still wins if explicitly set, in case someone genuinely wants to
# switch desktops or install the other one alongside.
if [[ -z "$DESKTOP_CHOICE" ]]; then
    if pacman -Qi gnome-shell >/dev/null 2>&1; then
        DESKTOP_CHOICE="gnome"
        echo "GNOME already installed — reusing it, skipping the desktop prompt."
    elif pacman -Qi plasma-desktop >/dev/null 2>&1; then
        DESKTOP_CHOICE="plasma"
        echo "KDE Plasma already installed — reusing it, skipping the desktop prompt."
    fi
fi

if [[ -z "$DESKTOP_CHOICE" ]]; then
    if [[ -t 0 ]]; then
        echo "Which desktop would you like to install?"
        echo "  1) KDE Plasma  (default)"
        echo "  2) GNOME"
        read -r -p "Enter 1 or 2: " reply || true
        case "$reply" in
            2) DESKTOP_CHOICE="gnome" ;;
            *) DESKTOP_CHOICE="plasma" ;;
        esac
    else
        # No TTY to prompt on (e.g. piped into bash non-interactively) —
        # keep the previous default behavior rather than hanging on `read`.
        DESKTOP_CHOICE="plasma"
    fi
fi

case "$DESKTOP_CHOICE" in
    gnome)
        DESKTOP_LABEL="GNOME desktop"
        DESKTOP_SCRIPT="$SCRIPT_DIR/desktop/install-ativos-gnome.sh"
        ;;
    plasma|kde|*)
        DESKTOP_LABEL="KDE Plasma desktop"
        DESKTOP_SCRIPT="$SCRIPT_DIR/desktop/install-ativos-kde.sh"
        ;;
esac
printf "${C_DIM}Installing: ${C_RESET}${C_BOLD}%s${C_RESET}\n" "$DESKTOP_LABEL"

run_step "$DESKTOP_LABEL"                     "$DESKTOP_SCRIPT"
run_step "Branding"                           "$SCRIPT_DIR/branding/install-ativos-branding.sh"
run_step "ativ package manager"               "$SCRIPT_DIR/package-manager/setup-ativ.sh"
run_step "GPU drivers"                        "$SCRIPT_DIR/gpu-drivers/install-ativos-gpu-drivers.sh"
run_step "Plymouth boot splash"                "$SCRIPT_DIR/plymouth-theme/install-ativos-plymouth.sh"
run_step "Default apps (Firefox, Discord, Spotify, fastfetch)" "$SCRIPT_DIR/apps/install-ativos-apps.sh"
run_step "Performance stack (zram, ananicy-cpp, GameMode, reflector, scx_loader)" "$SCRIPT_DIR/performance/install-ativos-performance.sh"
run_step "Shell setup (fish + starship for new users)" "$SCRIPT_DIR/shell/install-ativos-shell.sh"
run_step "First-boot setup assistant (OOBE)"  "$SCRIPT_DIR/oobe/install-ativos-oobe.sh"

echo ""
hr
if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
    printf "${C_OK}${C_BOLD} \xe2\x9c\x94 All AtivOS components installed successfully.${C_RESET}\n"
else
    printf "${C_ERR}${C_BOLD} \xe2\x9c\x98 %d step(s) failed:${C_RESET}\n" "${#FAILED_STEPS[@]}"
    for s in "${FAILED_STEPS[@]}"; do
        printf "${C_ERR}   - %s${C_RESET}\n" "$s"
    done
    printf "${C_DIM}   Scroll up for details, fix the issue, and re-run the corresponding\n   script directly (each one is safe to re-run on its own).${C_RESET}\n"
fi
hr
echo ""
echo "Reboot to land on the SDDM login screen — the Setup Assistant will"
echo "greet you on first login."

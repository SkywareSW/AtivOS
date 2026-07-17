#!/usr/bin/env bash
# ativos-install.sh
#
# Full AtivOS installer — run this directly from the Arch ISO live
# environment instead of archinstall. Partitions a disk, pacstraps a base
# system, and hands off to ativos-chroot-setup.sh to finish configuration,
# the bootloader, and (optionally) the full AtivOS branding/driver/splash
# stack.
#
# UEFI only. If your firmware doesn't show a UEFI boot option, this script
# will refuse to run — enable UEFI in your firmware settings first.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

c_info()  { echo -e "\033[1;34m::\033[0m $*"; }
c_ok()    { echo -e "\033[1;32m==>\033[0m $*"; }
c_warn()  { echo -e "\033[1;33m!!\033[0m $*" >&2; }
c_err()   { echo -e "\033[1;31mxx\033[0m $*" >&2; }
die()     { c_err "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this as root from the Arch ISO (you already are, by default)."
[[ -d /sys/firmware/efi/efivars ]] || die "This system booted in BIOS/legacy mode. AtivOS's installer is UEFI-only — enable UEFI in your firmware settings and boot the ISO in UEFI mode."
[[ -f /etc/arch-release ]] || c_warn "This doesn't look like an Arch ISO — continuing anyway, but you're on your own if pacstrap isn't available."
command -v pacstrap >/dev/null 2>&1 || die "pacstrap not found. Run this from the Arch Linux ISO live environment."

c_info "Checking internet connectivity..."
if ! curl -fsS --max-time 5 https://archlinux.org >/dev/null 2>&1; then
    die "No internet connection. Connect first (iwctl for Wi-Fi, or plug in ethernet) and try again."
fi
c_ok "Online."

# ---- gather disks -------------------------------------------------------
echo ""
c_info "Available disks:"
lsblk -dpno NAME,SIZE,MODEL | grep -Ev 'loop|sr[0-9]' || true
echo ""

DISK=""
while true; do
    read -rp "Disk to install AtivOS on (e.g. /dev/sda, /dev/nvme0n1): " DISK
    [[ -b "$DISK" ]] && break
    c_err "'$DISK' is not a block device. Try again."
done

case "$DISK" in
    *nvme*|*mmcblk*) PART_SUFFIX="p" ;;
    *) PART_SUFFIX="" ;;
esac
ESP_PART="${DISK}${PART_SUFFIX}1"
ROOT_PART="${DISK}${PART_SUFFIX}2"

echo ""
c_warn "ALL DATA ON $DISK WILL BE ERASED."
read -rp "Type the disk path again to confirm ($DISK): " CONFIRM_DISK
[[ "$CONFIRM_DISK" == "$DISK" ]] || die "Confirmation didn't match. Aborting, nothing was touched."

# ---- gather config --------------------------------------------------------
read -rp "Hostname [ativos]: " HOSTNAME
HOSTNAME="${HOSTNAME:-ativos}"

USERNAME=""
while [[ -z "$USERNAME" ]]; do
    read -rp "Username to create: " USERNAME
done

while true; do
    read -rsp "Password for $USERNAME: " USER_PASSWORD; echo ""
    read -rsp "Confirm password: " USER_PASSWORD_CONFIRM; echo ""
    [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" && -n "$USER_PASSWORD" ]] && break
    c_err "Passwords didn't match or were empty. Try again."
done

read -rp "Also set a root password? (leave blank to lock the root account, sudo-only) [y/N]: " SET_ROOT_PW
ROOT_PASSWORD=""
if [[ "$SET_ROOT_PW" =~ ^[Yy]$ ]]; then
    while true; do
        read -rsp "Root password: " ROOT_PASSWORD; echo ""
        read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM; echo ""
        [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" && -n "$ROOT_PASSWORD" ]] && break
        c_err "Passwords didn't match or were empty. Try again."
    done
fi

DEFAULT_TZ="UTC"
DETECTED_TZ="$(curl -fsS --max-time 3 https://ipapi.co/timezone 2>/dev/null || true)"
[[ -n "$DETECTED_TZ" && -f "/usr/share/zoneinfo/$DETECTED_TZ" ]] && DEFAULT_TZ="$DETECTED_TZ"
read -rp "Timezone [$DEFAULT_TZ]: " TIMEZONE
TIMEZONE="${TIMEZONE:-$DEFAULT_TZ}"
[[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "Unknown timezone '$TIMEZONE' (expected e.g. Europe/Nicosia, America/New_York)."

read -rp "Locale [en_US.UTF-8]: " LOCALE
LOCALE="${LOCALE:-en_US.UTF-8}"

read -rp "Console keymap [us]: " KEYMAP
KEYMAP="${KEYMAP:-us}"

read -rp "Install the full AtivOS stack (branding, ativ, GPU drivers, boot splash) after the base system? [Y/n]: " INSTALL_ATIVOS
INSTALL_ATIVOS="${INSTALL_ATIVOS:-y}"

CPU_VENDOR="other"
grep -qi 'GenuineIntel' /proc/cpuinfo && CPU_VENDOR="intel"
grep -qi 'AuthenticAMD' /proc/cpuinfo && CPU_VENDOR="amd"

echo ""
c_info "Summary:"
echo "    Disk:        $DISK  (ESP: $ESP_PART, root: $ROOT_PART)"
echo "    Hostname:    $HOSTNAME"
echo "    User:        $USERNAME"
echo "    Root login:  $([[ -n "$ROOT_PASSWORD" ]] && echo 'password set' || echo 'locked (sudo only)')"
echo "    Timezone:    $TIMEZONE"
echo "    Locale:      $LOCALE"
echo "    Keymap:      $KEYMAP"
echo "    CPU:         $CPU_VENDOR"
echo "    Full stack:  $([[ "$INSTALL_ATIVOS" =~ ^[Yy]$ ]] && echo yes || echo 'base Arch only')"
echo ""
read -rp "Proceed? This is the last confirmation before disk changes. [y/N]: " GO
[[ "$GO" =~ ^[Yy]$ ]] || die "Aborted, nothing was touched."

# ---- partition --------------------------------------------------------
c_info "Wiping and partitioning $DISK"
wipefs -af "$DISK" >/dev/null
sgdisk --zap-all "$DISK" >/dev/null
sgdisk -n1:0:+1GiB -t1:ef00 -c1:ESP "$DISK" >/dev/null
sgdisk -n2:0:0     -t2:8300 -c2:ativos_root "$DISK" >/dev/null
partprobe "$DISK"
udevadm settle
sleep 2

c_info "Formatting partitions"
mkfs.fat -F32 -n ESP "$ESP_PART" >/dev/null
mkfs.ext4 -F -L ativos_root "$ROOT_PART" >/dev/null

c_info "Mounting"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$ESP_PART" /mnt/boot

# ---- base install -------------------------------------------------------
MICROCODE_PKG=""
[[ "$CPU_VENDOR" == "intel" ]] && MICROCODE_PKG="intel-ucode"
[[ "$CPU_VENDOR" == "amd" ]]   && MICROCODE_PKG="amd-ucode"

c_info "Installing base system (this will take a while)"
pacstrap -K /mnt base linux linux-firmware linux-headers \
    base-devel sudo networkmanager git vim nano \
    limine efibootmgr dosfstools e2fsprogs mkinitcpio pciutils \
    $MICROCODE_PKG

c_info "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

cp /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || true

# ---- hand off to the chroot stage ---------------------------------------
install -Dm755 "$SCRIPT_DIR/ativos-chroot-setup.sh" /mnt/root/ativos-chroot-setup.sh

# Stage a copy of the whole local repo (this exact checkout, with whatever
# fixes are currently in it) into the chroot. ativos-chroot-setup.sh uses
# this instead of git-cloning from GitHub when installing the full AtivOS
# stack, so the install no longer silently depends on network access *and*
# github.com/SkywareSW/AtivOS being reachable/up to date at that exact
# moment mid-chroot. THIS WAS THE BUG: a failed/slow clone there used to
# skip the entire branding/plymouth/oobe stack with no visible error.
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -f "$REPO_ROOT/install-all.sh" ]]; then
    c_info "Staging local AtivOS repo into the chroot"
    mkdir -p /mnt/root/AtivOS-src
    cp -a "$REPO_ROOT"/. /mnt/root/AtivOS-src/
    rm -rf /mnt/root/AtivOS-src/.git
else
    c_warn "Couldn't find install-all.sh next to this script — the chroot will fall back to cloning from GitHub instead of using this local copy."
fi

CONF_FILE=/mnt/root/ativos-install.conf
umask 077
cat > "$CONF_FILE" <<EOF
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
USER_PASSWORD="$USER_PASSWORD"
ROOT_PASSWORD="$ROOT_PASSWORD"
TIMEZONE="$TIMEZONE"
LOCALE="$LOCALE"
KEYMAP="$KEYMAP"
ROOT_PART="$ROOT_PART"
INSTALL_ATIVOS="$INSTALL_ATIVOS"
EOF

c_ok "Base system installed. Entering chroot to finish setup..."
arch-chroot /mnt /root/ativos-chroot-setup.sh

shred -u "$CONF_FILE" 2>/dev/null || rm -f "$CONF_FILE"
rm -f /mnt/root/ativos-chroot-setup.sh

c_info "Unmounting"
umount -R /mnt

echo ""
c_ok "Done. Remove the install media and reboot: reboot"

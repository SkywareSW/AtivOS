#!/usr/bin/env bash
# ativos-chroot-setup.sh
#
# Runs inside arch-chroot, called by ativos-install.sh. Not meant to be run
# standalone outside a freshly pacstrapped chroot.
#
set -euo pipefail

c_info()  { echo -e "\033[1;34m::\033[0m $*"; }
c_ok()    { echo -e "\033[1;32m==>\033[0m $*"; }
c_err()   { echo -e "\033[1;31mxx\033[0m $*" >&2; }
die()     { c_err "$*"; exit 1; }

CONF_FILE=/root/ativos-install.conf
[[ -f "$CONF_FILE" ]] || die "$CONF_FILE missing — this script must be run via ativos-install.sh."
# shellcheck disable=SC1090
source "$CONF_FILE"

# ---- timezone / clock ----------------------------------------------------
c_info "Setting timezone to $TIMEZONE"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

# ---- locale ---------------------------------------------------------------
c_info "Generating locale $LOCALE"
sed -i "s/^#\?\(${LOCALE//./\\.} UTF-8\)/\1/" /etc/locale.gen
grep -q "^${LOCALE} UTF-8" /etc/locale.gen || echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# ---- hostname / hosts -------------------------------------------------
c_info "Setting hostname to $HOSTNAME"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF

# ---- users ------------------------------------------------------------
c_info "Setting up accounts"
if [[ -n "$ROOT_PASSWORD" ]]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
else
    passwd -l root >/dev/null
fi

DEFAULT_SHELL=/bin/bash
[[ "$INSTALL_ATIVOS" =~ ^[Yy]$ ]] && DEFAULT_SHELL=/usr/bin/fish
useradd -m -G wheel,audio,video,storage,optical -s "$DEFAULT_SHELL" "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ---- networking ------------------------------------------------------
c_info "Enabling NetworkManager"
systemctl enable NetworkManager >/dev/null

# ---- initramfs ---------------------------------------------------------
c_info "Building initial initramfs"
mkinitcpio -P

# ---- bootloader: Limine -------------------------------------------------
# We deploy Limine to the ESP's default fallback path (esp/EFI/BOOT/BOOTX64.EFI)
# rather than registering an NVRAM entry with efibootmgr — this is the
# ArchWiki-recommended approach for maximum firmware compatibility (some
# boards ignore/mishandle efibootmgr-created entries).
c_info "Deploying Limine bootloader"
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

ROOT_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_PART")"
[[ -n "$ROOT_PARTUUID" ]] || die "Could not read PARTUUID for $ROOT_PART"

# /etc/default/limine holds the kernel command line as a bash-sourceable
# associative array. This exact format/location is what
# plymouth-theme/install-ativos-plymouth.sh already expects and appends
# "quiet splash" to — so the boot splash installer needs zero changes.
mkdir -p /etc/default
cat > /etc/default/limine <<EOF
declare -A KERNEL_CMDLINE
KERNEL_CMDLINE[default]="root=PARTUUID=$ROOT_PARTUUID rw"
EOF

# /usr/local/bin/limine-update regenerates /boot/limine.conf from whatever
# kernels are actually installed, reading the cmdline from
# /etc/default/limine. It's intentionally simple (no AUR dependency) and is
# the same command plymouth-theme/install-ativos-plymouth.sh looks for.
install -Dm755 /dev/stdin /usr/local/bin/limine-update <<'LIMINE_UPDATE'
#!/usr/bin/env bash
# limine-update — regenerates /boot/limine.conf from installed kernels.
set -euo pipefail

LIMINE_DEFAULT="/etc/default/limine"
declare -A KERNEL_CMDLINE=()
# shellcheck disable=SC1090
[[ -f "$LIMINE_DEFAULT" ]] && source "$LIMINE_DEFAULT"

CMDLINE_DEFAULT="${KERNEL_CMDLINE[default]:-}"
[[ -n "$CMDLINE_DEFAULT" ]] || { echo "limine-update: no KERNEL_CMDLINE[default] set in $LIMINE_DEFAULT" >&2; exit 1; }

{
    echo "timeout: 5"
    echo "default_entry: 1"
    echo ""

    shopt -s nullglob
    for vmlinuz in /boot/vmlinuz-*; do
        kname="${vmlinuz#/boot/vmlinuz-}"
        initramfs="/boot/initramfs-${kname}.img"
        fallback="/boot/initramfs-${kname}-fallback.img"
        cmdline="${KERNEL_CMDLINE[$kname]:-$CMDLINE_DEFAULT}"

        [[ -f "$initramfs" ]] || continue

        echo "/AtivOS ($kname)"
        echo "    protocol: linux"
        echo "    path: boot():/vmlinuz-${kname}"
        echo "    module_path: boot():/initramfs-${kname}.img"
        echo "    cmdline: $cmdline"
        echo ""

        if [[ -f "$fallback" ]]; then
            echo "/AtivOS ($kname, fallback initramfs)"
            echo "    protocol: linux"
            echo "    path: boot():/vmlinuz-${kname}"
            echo "    module_path: boot():/initramfs-${kname}-fallback.img"
            echo "    cmdline: $cmdline"
            echo ""
        fi
    done
} > /boot/limine.conf

echo "limine-update: wrote /boot/limine.conf"
LIMINE_UPDATE

mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-limine-update.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = linux
Target = linux-lts
Target = linux-zen
Target = linux-hardened
Target = mkinitcpio

[Action]
Description = Updating Limine boot entries...
When = PostTransaction
Exec = /usr/local/bin/limine-update
EOF

c_info "Writing initial /boot/limine.conf"
/usr/local/bin/limine-update

# ---- optional: full AtivOS stack ----------------------------------------
STACK_INSTALLED=1
if [[ "$INSTALL_ATIVOS" =~ ^[Yy]$ ]]; then
    ATIVOS_REPO_URL="https://github.com/SkywareSW/AtivOS.git"
    ATIVOS_REPO_DIR="/home/$USERNAME/AtivOS"

    # Prefer the local copy ativos-install.sh staged at /root/AtivOS-src
    # (the exact repo you ran the installer from). Only fall back to
    # cloning from GitHub if that wasn't staged for some reason (e.g. this
    # script got run standalone, outside the normal install flow).
    if [[ -d /root/AtivOS-src ]]; then
        c_info "Installing the full AtivOS stack (from the local copy)"
        cp -a /root/AtivOS-src "$ATIVOS_REPO_DIR"
        chown -R "$USERNAME:$USERNAME" "$ATIVOS_REPO_DIR"
        rm -rf /root/AtivOS-src
    else
        c_info "No local copy staged — cloning the AtivOS stack from GitHub"
        su - "$USERNAME" -c "git clone --quiet '$ATIVOS_REPO_URL' '$ATIVOS_REPO_DIR'" || {
            c_err "Could not clone $ATIVOS_REPO_URL — skipping the AtivOS stack. Base Arch install is otherwise complete."
            ATIVOS_REPO_DIR=""
        }
    fi

    if [[ -n "$ATIVOS_REPO_DIR" && -f "$ATIVOS_REPO_DIR/install-all.sh" ]]; then
        chmod +x "$ATIVOS_REPO_DIR/install-all.sh"
        if ! bash "$ATIVOS_REPO_DIR/install-all.sh"; then
            STACK_INSTALLED=0
            c_err "install-all.sh reported one or more failed steps (see output above)."
        fi
    else
        STACK_INSTALLED=0
        c_err "AtivOS stack was not installed (no repo available). Base Arch install is otherwise complete — after boot, run: sudo bash ~/AtivOS/install-all.sh (you may need to 'git clone $ATIVOS_REPO_URL ~/AtivOS' first)."
    fi
fi

if [[ "$INSTALL_ATIVOS" =~ ^[Yy]$ && $STACK_INSTALLED -eq 0 ]]; then
    c_err "Chroot setup complete, but the AtivOS stack did NOT fully install — see the errors above before rebooting."
else
    c_ok "Chroot setup complete."
fi

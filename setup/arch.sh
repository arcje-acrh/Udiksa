#!/usr/bin/env bash
# setup/arch.sh -- PART 1: install Arch Linux itself. Run as root from the Arch USB (UEFI mode, online).
# Builds the same layout as the reference machine, on ONE disk you choose (Windows disks are never offered):
#   EFI (FAT32, /boot/efi, 1 GiB) · /boot (ext4, 2 GiB) · btrfs (the rest) -- all three sizes are asked; defaults shown with subvolumes @ /, @home, @log, @pkg, @snapshots,
#   @swap (/swap: a swap file, asked, default the size of RAM, for hibernation) · zram swap in RAM first (no swap partition) · GRUB · NetworkManager · your user in the wheel group (sudo) · root locked
# Then it copies this dotfiles folder to /home/<you>/Udiksa. After reboot: log in, `nmtui` for Wi-Fi,
# then `~/Udiksa/install.sh apps rice`.
# Usage: setup/arch.sh [--dry-run]     (dry run: shows the disks and every step, changes nothing)
set -euo pipefail
REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*"; exit 1; }
run()  { if ((DRY)); then printf '    [dry] %s\n' "$*"; else "$@"; fi; }
ask()  { local q=$1 def=$2 a; read -rp "    $q [$def]: " a; echo "${a:-$def}"; }
# pick QUESTION DEFAULT ITEM...: a numbered list; the answer is a number from it (or the item's text); Enter = DEFAULT
pick() {
    local q=$1 def=$2 i=1 a x; shift 2
    for x in "$@"; do printf '    %3d) %s\n' "$i" "$x" >&2; i=$((i + 1)); done
    while :; do
        read -rp "    $q [$def]: " a; a=${a:-$def}
        if [[ $a =~ ^[0-9]+$ ]] && ((a >= 1 && a <= $#)); then echo "${!a}"; return; fi
        for x in "$@"; do [[ $x == "$a" ]] && { echo "$x"; return; }; done
        warn "type a number from the list"
    done
}

# ---------------------------------------------------------------- checks
((DRY)) || [[ $EUID -eq 0 ]] || die "run as root (from the Arch USB)"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (enable UEFI boot in the firmware, disable CSM)"
((DRY)) || ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "no internet: connect first (Wi-Fi: iwctl, then 'station wlan0 connect <name>')"

# ---------------------------------------------------------------- disk
windows_disk() { lsblk -rno FSTYPE,PARTTYPE "$1" | grep -qiE '^ntfs|e3c9e316-0b5c-4db8-817d-f92df00215ae'; }
usb_disk=$(lsblk -rno PKNAME "$(findmnt -rno SOURCE /run/archiso/bootmnt 2>/dev/null || echo /nonexistent)" 2>/dev/null || true)
say "Disks"
mapfile -t disks < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v zram)
choices=(); labels=()
for d in "${disks[@]}"; do
    info=$(lsblk -dno SIZE,MODEL "$d" | sed 's/  */ /g')
    if [[ $(basename "$d") == "$usb_disk" ]]; then printf '    %-14s %s   (the USB you booted from: not offered)\n' "$d" "$info"
    elif windows_disk "$d"; then printf '    %-14s %s   (has WINDOWS: not offered)\n' "$d" "$info"
    else choices+=("$d"); labels+=("$d  $info"); fi
done
((${#choices[@]})) || die "no disk without Windows found"
echo "    Install Arch on which disk? EVERYTHING on it is erased."
DISK=$(pick "Disk" "${labels[0]}" "${labels[@]}"); DISK=${DISK%% *}

# ---------------------------------------------------------------- you
say "About you and this machine"
while :; do
    HOST=$(ask "Computer name (letters, digits, -)" "arch")
    [[ $HOST =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && break; warn "not a valid computer name, again"
done
while :; do
    USERNAME=$(ask "User name (lowercase letters, digits, - or _)" "")
    [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break; warn "not a valid user name, again"
done
FULLNAME=$(ask "Your full name" "$USERNAME")
# time zone: pick the region, then the place (Enter keeps the default, Asia/Kolkata)
mapfile -t zones < <(timedatectl list-timezones 2>/dev/null | grep /)
((${#zones[@]})) || mapfile -t zones < <(cd /usr/share/zoneinfo && find Africa America Antarctica Asia Atlantic Australia Europe Indian Pacific -type f 2>/dev/null | sort)
echo "    Time zone: first the region"
REGION=$(pick "Region" "Asia" $(printf '%s\n' "${zones[@]%%/*}" | grep -xE "Africa|America|Antarctica|Arctic|Asia|Atlantic|Australia|Europe|Indian|Pacific" | sort -u))
mapfile -t places < <(printf '%s\n' "${zones[@]}" | grep "^$REGION/" | sed "s|^$REGION/||")
echo "    ... then the place"
PLACE=$(pick "Place" "$([[ $REGION == Asia ]] && echo Kolkata || echo "${places[0]}")" "${places[@]}")
TZONE="$REGION/$PLACE"
[[ -f /usr/share/zoneinfo/$TZONE ]] || die "unknown time zone $TZONE (see /usr/share/zoneinfo)"
if ((DRY)); then PASS=dry; else
    while :; do read -rsp "    Password for $USERNAME: " PASS; echo; read -rsp "    Again: " P2; echo; [[ -n $PASS && $PASS == "$P2" ]] && break; warn "empty or not the same, again"; done
fi
# partition sizes in GiB (Enter keeps the default). The system partition can be smaller than the rest of the disk: the
# space left over stays unallocated, for another system or data later.
RAM_G=$(( ($(awk '/^MemTotal/{print $2}' /proc/meminfo) + 1048575) / 1048576 ))
DISK_G=$(( $(lsblk -bdno SIZE "$DISK") / 1073741824 ))
say "Partition sizes on $DISK (${DISK_G} GiB)"
num() { local v; while :; do v=$(ask "$1" "$2"); [[ $v =~ ^[0-9]+$ ]] && (( v >= $3 )) && { echo "$v"; return; }; warn "a whole number of GiB, at least $3" >&2; done; }
EFI_G=$(num "EFI partition (GiB)" 1 1)
BOOT_G=$(num "/boot partition (GiB)" 2 1)
while :; do
    ROOT_ANS=$(ask "System partition (GiB, or 'rest' = all that is left)" "rest")
    if [[ $ROOT_ANS == rest ]]; then ROOT_G=0; break; fi
    [[ $ROOT_ANS =~ ^[0-9]+$ ]] && (( ROOT_ANS >= 40 && EFI_G + BOOT_G + ROOT_ANS <= DISK_G )) && { ROOT_G=$ROOT_ANS; break; }
    warn "at least 40 GiB, and EFI + /boot + system must fit in ${DISK_G} GiB"
done
SWAP_G=$(num "Swap file for hibernation (GiB; at least your RAM, ${RAM_G} GiB, to hibernate)" "$RAM_G" 1)
((SWAP_G >= RAM_G)) || warn "smaller than your RAM: hibernation may fail"

WIN=0; for d in "${disks[@]}"; do windows_disk "$d" && WIN=1; done

say "Summary"
printf '    disk %s (%s) will be ERASED\n    computer %s, user %s (%s), time zone %s%s\n' \
    "$DISK" "$(lsblk -dno SIZE,MODEL "$DISK" | sed 's/  */ /g')" "$HOST" "$USERNAME" "$FULLNAME" "$TZONE" \
    "$( ((WIN)) && echo ', Windows found on another disk: clock kept in local time')"
printf '    EFI %s GiB, /boot %s GiB, system %s, swap file %s GiB\n' "$EFI_G" "$BOOT_G" "$( ((ROOT_G)) && echo "${ROOT_G} GiB" || echo 'the rest of the disk')" "$SWAP_G"
if ((DRY)); then warn "dry run: nothing below is executed"; else
    read -rp "    Type the disk name ($(basename "$DISK")) to erase it and install: " c
    [[ $c == "$(basename "$DISK")" ]] || die "not confirmed, nothing changed"
fi

# ---------------------------------------------------------------- partitions + btrfs
say "Partitioning $DISK"
run sgdisk --zap-all "$DISK"
run sgdisk -n1:0:+${EFI_G}G -t1:ef00 -c1:EFI -n2:0:+${BOOT_G}G -t2:8300 -c2:boot -n3:0:$( ((ROOT_G)) && echo "+${ROOT_G}G" || echo 0 ) -t3:8300 -c3:arch "$DISK"
run partprobe "$DISK"; ((DRY)) || sleep 2
if ((DRY)); then P1=${DISK}p1; P2=${DISK}p2; P3=${DISK}p3; else
    mapfile -t parts < <(lsblk -rpno NAME,TYPE "$DISK" | awk '$2=="part"{print $1}')
    P1=${parts[0]}; P2=${parts[1]}; P3=${parts[2]}
fi
run mkfs.fat -F32 -n EFI "$P1"
run mkfs.ext4 -F -L boot "$P2"
run mkfs.btrfs -f -L arch "$P3"
run mount "$P3" /mnt
for sv in @ @home @log @pkg @snapshots @swap; do run btrfs subvolume create "/mnt/$sv"; done
run umount /mnt
O=rw,relatime,ssd,discard=async,space_cache=v2
run mount -o "$O,subvol=@" "$P3" /mnt
run mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots,boot,swap}
run mount -o "$O,subvol=@home" "$P3" /mnt/home
run mount -o "$O,subvol=@log" "$P3" /mnt/var/log
run mount -o "$O,subvol=@pkg" "$P3" /mnt/var/cache/pacman/pkg
run mount -o "$O,subvol=@snapshots" "$P3" /mnt/.snapshots
run mount -o "rw,noatime,ssd,discard=async,space_cache=v2,subvol=@swap" "$P3" /mnt/swap
# hibernation: a swap file the size of RAM (rounded up); the kernel finds it via resume= / resume_offset= below
run btrfs filesystem mkswapfile --size "${SWAP_G}g" --uuid clear /mnt/swap/swapfile
if ((DRY)); then ROOT_UUID="<uuid>"; RESUME_OFF="<offset>"; else
    ROOT_UUID=$(blkid -s UUID -o value "$P3"); RESUME_OFF=$(btrfs inspect-internal map-swapfile -r /mnt/swap/swapfile)
fi
run mount "$P2" /mnt/boot
run mkdir -p /mnt/boot/efi
run mount "$P1" /mnt/boot/efi

# ---------------------------------------------------------------- base system
say "Installing the base system"
UCODE=intel-ucode; grep -q AuthenticAMD /proc/cpuinfo && UCODE=amd-ucode
run pacman -Sy --noconfirm archlinux-keyring
run pacstrap -K /mnt base base-devel linux linux-headers linux-firmware "$UCODE" btrfs-progs grub efibootmgr \
    networkmanager sudo nano git zram-generator terminus-font
if ((DRY)); then echo "    [dry] genfstab -U /mnt >> /mnt/etc/fstab (+ /swap/swapfile line)"; else
    genfstab -U /mnt >> /mnt/etc/fstab
    printf '/swap/swapfile\tnone\tswap\tdefaults,pri=10\t0 0\n' >> /mnt/etc/fstab   # zram (100) is used first
fi

say "Configuring the new system"
CHROOT=$(cat <<EOF
set -e
ln -sf /usr/share/zoneinfo/$TZONE /etc/localtime
hwclock --systohc $( ((WIN)) && echo --localtime )
$( ((WIN)) && echo "printf '0.0 0 0.0\n0\nLOCAL\n' > /etc/adjtime" )
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
printf 'KEYMAP=us\nFONT=ter-v24n\n' > /etc/vconsole.conf
echo '$HOST' > /etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 $HOST.localdomain $HOST\n' > /etc/hosts
useradd -m -G wheel -s /bin/bash -c '$FULLNAME' '$USERNAME'
echo '$USERNAME ALL=(ALL) ALL' > /etc/sudoers.d/00_$USERNAME && chmod 440 /etc/sudoers.d/00_$USERNAME
passwd -l root
printf '[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
grep -qE '^HOOKS=.*\b(systemd|resume)\b' /etc/mkinitcpio.conf || sed -i -E 's/^(HOOKS=\(.*\bfilesystems)/\1 resume/' /etc/mkinitcpio.conf
sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)/\1 resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFF/' /etc/default/grub
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager systemd-timesyncd
EOF
)
if ((DRY)); then printf '%s\n' "$CHROOT" | sed 's/^/    [dry chroot] /'; else
    arch-chroot /mnt bash -c "$CHROOT"
    echo "$USERNAME:$PASS" | arch-chroot /mnt chpasswd
fi

say "Copying the dotfiles to /home/$USERNAME/Udiksa"
run cp -a "$REPO" "/mnt/home/$USERNAME/Udiksa"
if ((DRY)); then echo "    [dry] chown -R $USERNAME: /home/$USERNAME/Udiksa"; else arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Udiksa"; fi

say "Part 1 done."
cat <<EOF
    1. reboot (take the USB out)
    2. log in as $USERNAME on the text screen
    3. Wi-Fi: nmtui
    4. ~/Udiksa/install.sh apps rice   (apps, then the whole rice; about 20-40 minutes)
    5. reboot: the login screen appears; the first login sets the theme and default apps by itself
EOF

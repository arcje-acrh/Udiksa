#!/usr/bin/env bash
# setup-hibernation.sh -- hibernation on any Arch install (Udiksa part 3 runs it; part 1 installs already have it).
#   * already set up (resume= set and that swap active): says so, re-adds the kernel parameters if a shared
#     /etc/default/grub edit dropped them, and stops.
#   * otherwise ASKS: set it up? then: use a swap that exists (partition or file) or make a new swap file
#     (size asked, default = RAM; btrfs root -> its own @swap subvolume at /swap, so snapshots never include it).
#   * then: resume= / resume_offset= kernel parameters (GRUB: /etc/default/grub; other boot loaders: printed for
#     you to add) and the initramfs `resume` hook (mkinitcpio without the systemd hook; dracut does it by itself).
# Usage: sudo setup-hibernation.sh [--no-rebuild] [--yes SIZE_GIB]    (--yes: no questions, new swap file of SIZE)
# --no-rebuild: skip mkinitcpio -P / grub-mkconfig (apply.sh runs them itself afterwards). Safe to run again.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
REBUILD=1; AUTO=""
while (($#)); do case $1 in --no-rebuild) REBUILD=0 ;; --yes) AUTO=${2:?size}; shift ;; *) echo "unknown: $1"; exit 1 ;; esac; shift; done
say()  { printf '    %s\n' "$*"; }
ask()  { local a; read -rp "    $1 " a; echo "$a"; }
RAM=$(( ($(awk '/^MemTotal/{print $2}' /proc/meminfo) + 1048575) / 1048576 ))
GRUB=0; [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null && GRUB=1
MKI=0; [[ -f /etc/mkinitcpio.conf ]] && command -v mkinitcpio >/dev/null && MKI=1
ROOT_FS=$(findmnt -no FSTYPE /)

# ---- where the kernel finds the saved memory, for a swap device or file ----
resume_of() {                     # prints "UUID OFFSET" (offset empty for a partition)
    local s=$1
    if [[ -b $s ]]; then echo "$(blkid -s UUID -o value "$s") "; return; fi
    local fs dev off
    fs=$(findmnt -no FSTYPE -T "$s"); dev=$(findmnt -no SOURCE -T "$s" | sed 's/\[.*//')
    if [[ $fs == btrfs ]]; then off=$(btrfs inspect-internal map-swapfile -r "$s")
    else off=$(filefrag -v "$s" | awk '$1=="0:" {gsub(/\./,"",$4); print $4; exit}'); fi
    echo "$(blkid -s UUID -o value "$dev") $off"
}
current_resume() { sed -n 's/.*\bresume=UUID=\([^ "]*\).*/\1/p' /proc/cmdline /etc/default/grub 2>/dev/null | head -1; }

# ---- already set up? ----
active=$(swapon --show=NAME --noheadings | grep -v zram || true)
cur=$(current_resume)
if [[ -n $cur && -n $active ]]; then
    for s in $active; do
        read -r u o < <(resume_of "$s")
        if [[ $u == "$cur" ]]; then
            say "hibernation is set up (swap: $s)"
            if ((GRUB)) && ! grep -q 'resume=' /etc/default/grub; then
                sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)/\1 resume=UUID=$u${o:+ resume_offset=$o}/" /etc/default/grub
                say "kernel parameters re-added to /etc/default/grub"
            fi
            SWAP=$s; break
        fi
    done
fi

if [[ -z ${SWAP:-} ]]; then
    if [[ -z $AUTO ]]; then
        a=$(ask "Set up hibernation (save everything to disk and switch off; needs swap about the size of your RAM, ${RAM} GB)? [Y/n]")
        [[ ${a,,} == n* ]] && { say "skipped (run again any time: sudo $0)"; exit 0; }
    fi
    # swaps that could hold it: active or listed in fstab, not zram
    mapfile -t cands < <( { swapon --show=NAME --noheadings; blkid -t TYPE=swap -o device; awk '$3=="swap" && $1 !~ /^#/ {print $1}' /etc/fstab | sed 's/^UUID=/\/dev\/disk\/by-uuid\//'; } 2>/dev/null \
                          | grep -v zram | xargs -r -n1 readlink -f | sort -u )
    choice=new
    if [[ -z $AUTO && ${#cands[@]} -gt 0 ]]; then
        say "swap already on this machine:"
        for i in "${!cands[@]}"; do say "  $((i + 1))) ${cands[$i]}  ($(lsblk -no SIZE "${cands[$i]}" 2>/dev/null || du -h "${cands[$i]}" | cut -f1))"; done
        say "  n) make a new swap file"
        a=$(ask "Use which? [n]"); [[ $a =~ ^[0-9]+$ ]] && (( a >= 1 && a <= ${#cands[@]} )) && choice=${cands[$((a - 1))]}
    fi
    if [[ $choice == new ]]; then
        size=${AUTO:-}
        [[ -z $size ]] && { size=$(ask "Swap file size in GB [$RAM]"); size=${size:-$RAM}; }
        [[ $size =~ ^[0-9]+$ ]] || { echo "not a number: $size"; exit 1; }
        if [[ $ROOT_FS == btrfs ]]; then
            dev=$(findmnt -no SOURCE / | sed 's/\[.*//'); uuid=$(findmnt -no UUID /)
            if ! grep -qE '^[^#]\S*\s+/swap\s' /etc/fstab; then
                tmp=$(mktemp -d); mount -o subvolid=5 "$dev" "$tmp"
                [[ -d $tmp/@swap ]] || btrfs subvolume create "$tmp/@swap"
                umount "$tmp"; rmdir "$tmp"
                printf '\n# hibernation (setup-hibernation.sh)\nUUID=%s\t/swap\tbtrfs\trw,noatime,subvol=/@swap\t0 0\n' "$uuid" >> /etc/fstab
                systemctl daemon-reload
            fi
            mkdir -p /swap; mountpoint -q /swap || mount /swap
            SWAP=/swap/swapfile
            [[ -f $SWAP ]] || btrfs filesystem mkswapfile --size "${size}g" --uuid clear "$SWAP"
        else
            SWAP=/swapfile
            if [[ ! -f $SWAP ]]; then
                dd if=/dev/zero of="$SWAP" bs=1M count=$((size * 1024)) status=progress
                chmod 600 "$SWAP"; mkswap "$SWAP" >/dev/null
            fi
        fi
        grep -qE "^$SWAP\s" /etc/fstab || printf '%s\tnone\tswap\tdefaults,pri=10\t0 0\n' "$SWAP" >> /etc/fstab
    else
        SWAP=$choice
    fi
    swapon --show=NAME --noheadings | grep -qx "$SWAP" || swapon "$SWAP"
    read -r u o < <(resume_of "$SWAP")
    params="resume=UUID=$u${o:+ resume_offset=$o}"
    if ((GRUB)); then
        sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/ ?resume(_offset)?=[^ "]*//g' /etc/default/grub
        sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)/\1 $params/" /etc/default/grub
        say "kernel parameters added to /etc/default/grub: $params"
    else
        say "!! not GRUB: add these to your boot loader's kernel command line yourself: $params"
    fi
fi

# ---- the initramfs reads the saved memory back ----
if ((MKI)); then
    if ! grep -qE '^HOOKS=.*\b(resume|systemd)\b' /etc/mkinitcpio.conf; then
        sed -i -E 's/^(HOOKS=\(.*\bfilesystems)/\1 resume/' /etc/mkinitcpio.conf; say "mkinitcpio: resume hook added"
    fi
elif ! command -v dracut >/dev/null; then say "!! no mkinitcpio / dracut found: make sure your initramfs can resume"; fi

if ((REBUILD)); then
    ((MKI)) && mkinitcpio -P
    ((GRUB)) && grub-mkconfig -o /boot/grub/grub.cfg
fi
say "hibernation ready (swap: $SWAP)"

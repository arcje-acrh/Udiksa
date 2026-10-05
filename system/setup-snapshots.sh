#!/usr/bin/env bash
# setup-snapshots.sh -- system snapshots (your undo button): snapper takes one before + after every pacman update
# (snap-pac) and on a timer; with GRUB they are also bootable from the menu (grub-btrfs, "Arch Linux snapshots").
# NEEDS BTRFS: a snapshot is a btrfs feature (an instant, space-sharing copy of the root subvolume); on ext4 / xfs
# there is nothing to snapshot with, so this explains that and stops.
#   * part 1 installs (the @snapshots subvolume at /.snapshots): set up without asking
#   * any other btrfs install: asked first
#   * already set up (/etc/snapper/configs/root): only makes sure the services run
# Usage: sudo setup-snapshots.sh [--yes]     Safe to run again.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
YES=0; [[ ${1:-} == --yes ]] && YES=1
say() { printf '    %s\n' "$*"; }

if [[ $(findmnt -no FSTYPE /) != btrfs ]]; then
    say "snapshots need btrfs: this system's root is $(findmnt -no FSTYPE /), which cannot take snapshots (skipped)."
    say "(a fresh install with part 1 of the rice uses btrfs and gets them automatically)"
    exit 0
fi
part1=0; grep -qE '^[^#]\S*\s+/\.snapshots\s+btrfs\s.*subvol=/?@snapshots' /etc/fstab && part1=1
if [[ ! -f /etc/snapper/configs/root ]] && ((!part1)) && ((!YES)); then
    read -rp "    Set up system snapshots (snapper: automatic before/after every update, bootable from GRUB)? [Y/n] " a
    [[ ${a,,} == n* ]] && { say "skipped (later: sudo $0)"; exit 0; }
fi

grub=0; command -v grub-mkconfig >/dev/null && [[ -f /etc/default/grub ]] && grub=1
pkgs=(snapper snap-pac btrfs-assistant); ((grub)) && pkgs+=(grub-btrfs inotify-tools)      # btrfs-assistant = the snapshot window (launcher: "Btrfs Assistant")
pacman -S --needed --noconfirm "${pkgs[@]}" >/dev/null 2>&1
say "installed: ${pkgs[*]}"

if [[ ! -f /etc/snapper/configs/root ]]; then
    if mountpoint -q /.snapshots; then
        # part 1 layout: @snapshots is already mounted at /.snapshots; snapper's create-config wants to make its own
        # nested subvolume there, so: step aside, let it, drop its subvolume, mount ours back
        umount /.snapshots; rmdir /.snapshots
        snapper --no-dbus -c root create-config /
        btrfs subvolume delete /.snapshots >/dev/null
        mkdir /.snapshots; mount /.snapshots
    else
        snapper --no-dbus -c root create-config /          # a nested .snapshots subvolume inside /
    fi
    # the rice's defaults: enough to undo a bad update or last week, capped at half the disk
    sed -i -E \
        -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="20"/' -e 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="10"/' \
        -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' \
        -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
        -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="2"/' -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
        -e 's/^SPACE_LIMIT=.*/SPACE_LIMIT="0.5"/' /etc/snapper/configs/root
    chmod 750 /.snapshots
    say "snapper config 'root' created"
else say "snapper config 'root' already there"; fi

# Btrfs Assistant runs as root (pkexec), and root has no Qt settings: link root's qt6ct + Kvantum folders to the user's, so the
# window wears the rice's colours and follows every theme switch (udiksa theme rewrites those files). Never replaces a real root config.
if [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
    uh=$(getent passwd "$SUDO_USER" | cut -d: -f6); mkdir -p /root/.config
    for d in qt6ct Kvantum; do
        [[ -d $uh/.config/$d && ! -e /root/.config/$d && ! -L /root/.config/$d ]] && ln -s "$uh/.config/$d" "/root/.config/$d"
    done
    say "Btrfs Assistant themed (root's Qt config follows $SUDO_USER's)"
fi

systemctl enable --now snapper-timeline.timer snapper-cleanup.timer >/dev/null 2>&1
((grub)) && systemctl enable --now grub-btrfsd >/dev/null 2>&1
say "snapshots ready$( ((grub)) && echo ' (also bootable from GRUB)')"

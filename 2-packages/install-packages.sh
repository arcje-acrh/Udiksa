#!/usr/bin/env bash
# 2-packages/install-packages.sh -- PART 2: every app of the rice.
# Run as your normal user (sudo is used where needed), on an installed Arch (part 1), with internet.
#   repo.txt        official-repo apps              aur.txt   AUR apps (yay)
#   hw-nvidia.txt   only with an NVIDIA GPU         (optional apps: asked, see 3-rice/optional/)
#   hw-intel.txt    only with an Intel GPU
# Safe to run again: already installed packages are skipped (--needed).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
list() { grep -vE '^\s*(#|$)' "$1" | sed 's/\s*#.*//'; }        # package names from a list file

[[ $EUID -eq 0 ]] && { echo "Run as your user, not root (sudo is used when needed)."; exit 1; }

# ---- hardware ----
has_nvidia() { pacman -Qq nvidia-utils &>/dev/null || lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -q '\[10de:'; }   # reruns: the dGPU vanishes from lspci in Integrated mode
has_intel_gpu() { lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -q '\[8086:'; }

say "Enabling the multilib repository (32-bit NVIDIA libraries)"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi
sudo pacman -Sy --noconfirm >/dev/null

repo=( $(list repo.txt) )
has_nvidia    && { say "NVIDIA GPU found";  repo+=( $(list hw-nvidia.txt) ); }
has_intel_gpu && { say "Intel GPU found";   repo+=( $(list hw-intel.txt) ); }
aur=( $(list aur.txt) )

# optional apps (3-rice/optional/<app>): asked one by one; yes = the app + (in part 3) its rice files
say "Optional apps"
for o in "$(cd "$(dirname "$0")/.." && pwd)"/3-rice/optional/*/; do
    read -rp "    $(cat "$o/about")? [Y/n] " a
    [[ ${a,,} == n* ]] && continue
    while read -r p; do [[ $p == aur:* ]] && aur+=( "${p#aur:}" ) || repo+=( "$p" ); done < <(grep -vE '^\s*(#|$)' "$o/packages.txt")
done

say "Installing ${#repo[@]} packages from the official repositories"
sudo pacman -S --needed --noconfirm "${repo[@]}"

say "AUR helper (yay)"
# no -debug packages from AUR builds (they only clutter the system)
grep -qs '^OPTIONS=.*!debug' "$HOME/.makepkg.conf" || \
    echo 'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)   # rice: no -debug packages' >> "$HOME/.makepkg.conf"
if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

say "Installing ${#aur[@]} AUR packages"
yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake "${aur[@]}"

say "Part 2 done. Next: 3-rice/apply.sh"

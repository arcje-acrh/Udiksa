#!/usr/bin/env bash
# install.sh -- hybrid NVIDIA laptop support for Udiksa (see ./about): supergfxctl + its service. ~/Udiksa/install.sh
# offers it after part 3 when ./detect finds hybrid graphics; or run it yourself. Safe to run again.
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
[[ $EUID -eq 0 ]] && { echo "Run as your user, not root (sudo is used when needed)."; exit 1; }
say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
say "NVIDIA hybrid: supergfxctl"
yay -S --needed --noconfirm $(grep -vE '^\s*(#|$)' "$HERE/packages.txt" | sed 's/^aur://')
sudo systemctl enable --now supergfxd >/dev/null 2>&1 || true
# Standard -> Eco is queued for the next boot (a live switch fails while Hyprland uses the card): root helper + sudoers
sudo install -m 755 "$HERE/udiksa-gpu-next" /usr/local/bin/udiksa-gpu-next
sudo install -m 440 "$HERE/sudoers" /etc/sudoers.d/udiksa-gpu
printf '    %s\n' "supergfxd enabled: GPU mode in the notch and Settings > GPU (a mode change asks you to log out or reboot)"

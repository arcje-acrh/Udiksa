#!/usr/bin/env bash
# install.sh -- face unlock for Udiksa (see ./about). ~/Udiksa/install.sh offers it after part 3 when ./detect finds an
# IR camera; or run it yourself any time. Safe to run again (run it again to add your face later).
#   packages.txt (howdy-next) | face models | camera = the IR camera (by-path, stable across reboots) |
#   /etc/pam.d/sudo + /etc/pam.d/greetd (boot login): one line, face first, password still works | the lock screen uses it by itself
#   (~/.config/quickshell/pam/face.conf, only when Howdy is installed) | your face, if you say yes
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
[[ $EUID -eq 0 ]] && { echo "Run as your user, not root (sudo is used when needed)."; exit 1; }
say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

say "Face unlock: Howdy"
yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake $(grep -vE '^\s*(#|$)' "$HERE/packages.txt" | sed 's/^aur://')
sudo howdy download-models >/dev/null && note "face models downloaded"

say "Face unlock: camera"
cam=""
for d in /sys/class/video4linux/video*; do
    [[ $(cat "$d/index") == 0 ]] && grep -qiE '\bIR\b|infrared' "$d/name" && { cam=/dev/$(basename "$d"); break; }
done
[[ -n $cam ]] || { echo "  ! no IR camera found"; exit 1; }
for l in /dev/v4l/by-path/*; do [[ $(readlink -f "$l") == "$cam" ]] && { cam=$l; break; }; done
sudo howdy set device_path "$cam" >/dev/null && note "camera: $cam"

say "Face unlock: sudo"
if grep -q pam_howdy /etc/pam.d/sudo; then note "already there"
else sudo sed -i '0,/^auth/s//auth\t\tsufficient\tpam_howdy.so workaround=native\n&/' /etc/pam.d/sudo; note "added (face first, then your password)"; fi

say "Face unlock: boot login"
if grep -q pam_howdy /etc/pam.d/greetd 2>/dev/null; then note "already there"
else sudo sed -i '/pam_nologin.so/a auth       sufficient   pam_howdy.so' /etc/pam.d/greetd; note "added (face first, then your password)"; fi

say "Face unlock: your face"
read -rp "    Add your face now (look at the camera)? [Y/n] " a || a=n     # no terminal (run from a script): later
if [[ ${a,,} != n* ]]; then sudo howdy add && note "added: lock the screen to try it (Super+L)"
else note "later: sudo howdy add"; fi

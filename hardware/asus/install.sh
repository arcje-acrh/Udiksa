#!/usr/bin/env bash
# install.sh -- ASUS laptop support for Udiksa (see ./about). ~/Udiksa/install.sh offers it after part 3 when
# ./detect finds an ASUS laptop; or run it yourself any time. Safe to run again.
#   packages.txt (asusctl) | rice-kbd + rice-slash -> ~/.local/bin (keyboard light, Slash lid light) | asus-fnlock service (ROG keyboards start
#   with Fn-lock ON; this turns it off at boot and after sleep) | asusd on | battery charge limit 80 % (Settings changes it)
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
[[ $EUID -eq 0 ]] && { echo "Run as your user, not root (sudo is used when needed)."; exit 1; }
say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

say "ASUS: packages"
sudo pacman -S --needed --noconfirm $(grep -vE '^\s*(#|$)' "$HERE/packages.txt")

say "ASUS: files"
mkdir -p "$HOME/.local/bin"
t="$HOME/.local/bin/rice-kbd"; [[ -L $t && ! -e $t ]] && rm "$t"
stow -d "$HERE" -t "$HOME" --restow dots              # dots/ mirrors ~ (dots/.local/bin -> ~/.local/bin)
note "rice-kbd, rice-slash -> ~/.local/bin"
while IFS= read -r -d '' f; do
    sudo install -D -m "$(stat -c %a "$f")" "$f" "${f#"$HERE/system"}"
done < <(find "$HERE/system" -type f -print0)
note "asus-fnlock service installed"

say "ASUS: services"
sudo systemctl enable --now asusd >/dev/null 2>&1 || true
sudo systemctl reenable asus-fnlock >/dev/null 2>&1 && note "asusd + asus-fnlock enabled"
if asusctl battery limit 80 >/dev/null 2>&1; then note "battery charge limit: 80 %"
else note "battery charge limit: set it later in Settings > Battery & sleep"; fi
"$HOME/.local/bin/rice-kbd" apply >/dev/null 2>&1 && note "keyboard light follows the theme (Settings > Keyboard & touchpad)" || true

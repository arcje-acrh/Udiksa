#!/usr/bin/env bash
# install.sh -- Udiksa: a fresh (or existing) Arch -> this rice, in three parts:
#   1  Arch itself        OPTIONAL, only for a blank machine: wipes the disk you pick (from the Arch USB, as root)
#   2  the apps           core apps + the optional ones you say yes to (Zen, OnlyOffice, ncspot, Tailscale, Ollama)
#   3  the rice           configs, themes, shell, login screen, boot splash + GRUB theme (if GRUB), hibernation (asked)
#   after 3              hardware support, offered only where it fits (hardware/<name>/detect): ASUS laptops,
#                        hybrid NVIDIA laptops. Run one by hand: hardware/<name>/install.sh
# The rice adapts to the machine (screens, GPU, battery, boot loader); your own choices live in
# ~/.config/hypr/local (the personal layer, not in the repo).
# Usage:  ./install.sh 1        from the Arch USB (blank machine only)
#         ./install.sh 2 3      on any installed Arch (archinstall, part 1, your own)
#         ./install.sh 3        re-apply the rice only (safe to repeat)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
[[ $# -eq 0 ]] && { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
for part in "$@"; do
    case $part in
        1) ./1-arch/install-arch.sh ;;
        2) ./2-packages/install-packages.sh ;;
        3) ./3-rice/apply.sh
           for hw in hardware/*/; do
               "$hw/detect" 2>/dev/null || continue
               printf '\n\033[1;32m==>\033[0m Found: %s\n' "$(head -1 "$hw/about")"
               read -rp "    Install $(basename "$hw") support? [Y/n] " a
               [[ ${a,,} == n* ]] || "$hw/install.sh"
           done ;;
        *) echo "unknown part: $part (1, 2 or 3)"; exit 1 ;;
    esac
done

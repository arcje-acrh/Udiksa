#!/usr/bin/env bash
# title: Refresh mirrors
# desc: Fastest up-to-date Arch mirrors near you (reflector); old list kept as mirrorlist.bak
# terminal: yes
set -e
echo "Saving the current list as /etc/pacman.d/mirrorlist.bak ..."
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
echo "Testing mirrors (India + Singapore, HTTPS, synced within 12 h) ..."
sudo reflector --country India,Singapore --protocol https --age 12 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
echo; echo "Top mirrors now:"; grep '^Server' /etc/pacman.d/mirrorlist | head -5
echo; sudo pacman -Syy

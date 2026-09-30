#!/usr/bin/env bash
# title: Update system
# desc: Update everything: official packages (pacman -Syu), then AUR packages (yay -Sua)
# terminal: yes
running=$(uname -r)

echo "==> Official packages (pacman)"
sudo pacman -Syu || { echo; echo ">>> pacman stopped with an error (see above); AUR update skipped."; exit 1; }

if command -v yay >/dev/null; then
    echo; echo "==> AUR packages (yay)"
    yay -Sua || echo ">>> An AUR package failed (see above); the official packages are already up to date."
fi

echo
installed=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | sed 's/\.arch/-arch/')
if [[ -n $installed && "$running" != "$installed"* ]]; then
    echo ">>> A new kernel was installed ($installed, running $running): reboot soon."
    # machines with a DKMS driver (e.g. the patched SSD driver on a Zephyrus G16): show that it was rebuilt
    dkms status 2>/dev/null | grep -q . && { echo; dkms status; }
fi

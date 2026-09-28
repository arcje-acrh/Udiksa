#!/usr/bin/env bash
# title: Update system
# desc: Update everything (yay -Syu), then check the SSD driver was rebuilt for a new kernel
# terminal: yes
running=$(uname -r)
yay -Syu
echo
installed=$(pacman -Q linux | awk '{print $2}' | sed 's/\.arch/-arch/')
echo "Running kernel: $running   installed: $installed"
dkms status || true
if ! [[ "$running" == "$installed"* ]]; then
    echo; echo ">>> A new kernel was installed: reboot soon, then run 'Check SSD driver'."
fi

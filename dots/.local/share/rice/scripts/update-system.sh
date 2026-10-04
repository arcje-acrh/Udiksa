#!/usr/bin/env bash
# title: Update system
# desc: Update everything: official packages (pacman -Syu), then AUR packages (yay -Sua), then Hyprland plugins
# terminal: yes
running=$(uname -r)

echo "==> Official packages (pacman)"
sudo pacman -Syu || { echo; echo ">>> pacman stopped with an error (see above); AUR update skipped."; exit 1; }

if command -v yay >/dev/null; then
    echo; echo "==> AUR packages (yay)"
    yay -Sua || echo ">>> An AUR package failed (see above); the official packages are already up to date."
fi

if command -v hyprpm >/dev/null && hyprpm list 2>/dev/null | grep -q Repository; then
    echo; echo "==> Hyprland plugins (hyprpm: rebuilt only when Hyprland changed)"
    hyprpm update || echo ">>> A plugin did not build (shake to find may be off until it does)."
fi

echo
installed=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | sed 's/\.arch/-arch/')
if [[ -n $installed && "$running" != "$installed"* ]]; then
    echo ">>> A new kernel was installed ($installed, running $running): reboot soon."
    # machines with a DKMS driver (e.g. the patched SSD driver on a Zephyrus G16): show that it was rebuilt
    dkms status 2>/dev/null | grep -q . && { echo; dkms status; }
fi

# .pacnew = a package's NEW default for a config file you (or the rice) changed. pacman never overwrites a changed
# config: yours stays in use, untouched, and the new default is saved beside it as <file>.pacnew. Nothing changes
# until you merge it yourself, so the rice's settings stay the default.
mapfile -t new < <(find /etc -name '*.pacnew' 2>/dev/null | sort)
if ((${#new[@]})); then
    echo; echo "==> New default config files (.pacnew): ${#new[@]}"
    echo "    Your files (and the rice's) are still the ones in use; nothing was changed."
    echo "    Each .pacnew is the package's new default, saved next to yours so you can look at it:"
    rice=" greetd/config.toml plymouth/plymouthd.conf default/grub mkinitcpio.conf "   # files the rice sets up
    for f in "${new[@]}"; do
        k=${f#/etc/}; k=${k%.pacnew}
        [[ $rice == *" $k "* ]] && tag="rice keeps its version" || tag="yours"
        echo "      $f   ($tag)"
    done
    echo "    Compare:  diff ${new[0]%.pacnew} ${new[0]}   (- = in use, + = new default)"
    echo "    Then copy over anything you want from the new one, and delete the .pacnew:  sudo rm <file>.pacnew"
    echo "    Leaving them does no harm."
fi

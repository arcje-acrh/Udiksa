#!/usr/bin/env bash
# title: Update system
# desc: Update everything: official packages (pacman -Syu), then AUR packages (yay -Sua), AUR rebuilds the update broke (e.g. quickshell after a Qt bump), then Hyprland plugins
# terminal: yes
running=$(uname -r)
qt_before=$(pacman -Q qt6-base 2>/dev/null | awk '{split($2,v,"."); print v[1]"."v[2]}')

echo "==> Official packages (pacman)"
sudo pacman -Syu || { echo; echo ">>> pacman stopped with an error (see above); AUR update skipped."; exit 1; }

if command -v yay >/dev/null; then
    echo; echo "==> AUR packages (yay)"
    yay -Sua || echo ">>> An AUR package failed (see above); the official packages are already up to date."
fi

# AUR packages are not rebuilt by pacman. Rebuild the ones this update just broke:
#  - Qt minor bump (6.11 -> 6.12): every AUR package depending on qt6 (e.g. quickshell-git), its Qt-private ABI changes
#  - any AUR program in /usr with a now-missing shared library (soname bump, e.g. yay vs libalpm)
if command -v yay >/dev/null; then
    qt_after=$(pacman -Q qt6-base 2>/dev/null | awk '{split($2,v,"."); print v[1]"."v[2]}')
    [[ -n $qt_before && $qt_before != "$qt_after" ]] && qt=$(pacman -Qmi | awk '/^Name/{n=$3} /^Depends On/ && /qt6/{print n}')
    broken=$(for pkg in $(pacman -Qqm); do
        for f in $(pacman -Qlq "$pkg" | grep -E '^/usr/(bin|lib)/[^/]+$'); do
            [[ -x $f && -f $f ]] && ldd "$f" 2>/dev/null | grep -q 'not found' && { echo "$pkg"; break; }
        done
    done)
    mapfile -t rebuild < <(printf '%s\n' $qt $broken | sort -u)
    if ((${#rebuild[@]})); then
        echo; echo "==> Rebuilding AUR packages broken by this update: ${rebuild[*]}"
        yay -S --rebuild "${rebuild[@]}" || echo ">>> Rebuild failed (see above); retry:  yay -S --rebuild ${rebuild[*]}"
        [[ " ${rebuild[*]} " == *quickshell* ]] && echo ">>> The shell keeps the old build until you log out and in."
    fi
fi

# optional machine-specific steps: every ~/.config/udiksa/update.d/*.sh runs here (none ship with Udiksa)
for h in "$HOME"/.config/udiksa/update.d/*.sh; do
    [[ -f $h ]] && { echo; echo "==> ${h##*/}"; bash "$h"; }
done

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

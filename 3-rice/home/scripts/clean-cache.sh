#!/usr/bin/env bash
# title: Clean package cache
# desc: Keep the last 2 versions of each package, drop cached copies of uninstalled ones
# terminal: yes
echo "Package cache before: $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
sudo paccache -rk2
sudo paccache -ruk0
echo "Package cache after:  $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
echo "yay build cache:      $(du -sh ~/.cache/yay 2>/dev/null | cut -f1)  (clean with: yay -Sc)"

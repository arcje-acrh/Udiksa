#!/usr/bin/env bash
# title: Remove orphans
# desc: List packages nothing needs any more and ask before removing them
# terminal: yes
orphans=$(pacman -Qdtq)
if [ -z "$orphans" ]; then echo "No orphans."; exit 0; fi
echo "Packages nothing depends on:"; echo "$orphans" | sed 's/^/  /'
echo; echo "Note: clang, cmake, go, meson, rust, ... are kept on purpose (needed to rebuild AUR packages)."
echo "pacman will list what it removes and ask first:"
sudo pacman -Rns $orphans

#!/usr/bin/env bash
# title: Reload Hyprland
# desc: Re-read the Hyprland config (after editing ~/.config/hypr)
# terminal: no
hyprctl reload >/dev/null && notify-send -a Hyprland "Config reloaded" "$(hyprctl configerrors | head -3)"

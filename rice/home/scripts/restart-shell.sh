#!/usr/bin/env bash
# title: Restart shell
# desc: Restart Quickshell (notch, notifications, launcher) if something looks stuck, or after a scale change
# terminal: no
hyprctl dispatch "hl.dsp.exec_cmd(\"$HOME/.local/bin/rice-shell --restart\")" >/dev/null

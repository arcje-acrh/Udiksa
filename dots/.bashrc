#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- rice: ble.sh (bash line editor; provides a real right-hand prompt) ---
# Must be sourced first; it is attached at the very end of this file.
# Settings: ~/.blerc. Remove this block and the last block to uninstall.
[[ -f ~/.local/share/blesh/ble.sh ]] && source -- ~/.local/share/blesh/ble.sh --attach=none

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# --- rice: prompt (starship, config: ~/.config/starship.toml) ---
if command -v starship >/dev/null 2>&1; then
    # the themed copy rice-theme writes (template: ~/.config/starship.toml)
    [[ -f ~/.local/state/rice/starship.toml ]] && export STARSHIP_CONFIG=~/.local/state/rice/starship.toml
    eval "$(starship init bash)"
fi

# --- rice: ble.sh attach (must be the last thing in this file) ---
[[ ! ${BLE_VERSION-} ]] || ble-attach

#!/bin/bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

set_tmux_option() {
    local option=$1
    local value=$2
    tmux set-option -gq "$option" "$value"
}

myblocks_show=$(get_tmux_option @myblocks_toggle "off")

if [[ "$myblocks_show" == "off" ]]; then
    set_tmux_option @myblocks_toggle "on"
elif [[ "$myblocks_show" == "on" ]]; then
    set_tmux_option @myblocks_toggle "off"
else
    printf "@myblocks_show option wrong: $myblocks_show"
fi

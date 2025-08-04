#!/bin/bash

## myblocks.tmux - Dynamic tmux status bar blocks
#
# This script replaces the custom tags (e.g #{battery}) in the tmux status bar  with scripts paths
# for each status block. It allows for lazy evaluation when Tmux updates the status line.
#
# Use "prefix+v" to toggle the blocks on or off.

CURRENT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

declare -A TAGS
TAGS=(
    [battery]="#(${CURRENT_DIR}/scripts/battery.sh)"
    [cpu_temp]="#(${CURRENT_DIR}/scripts/cpu_temp.sh)"
    [network-ip]="#(${CURRENT_DIR}/scripts/network.sh --ip)"
    [network-speed]="#(${CURRENT_DIR}/scripts/network.sh --speed)"
    [network-ping]="#(${CURRENT_DIR}/scripts/network.sh --ping)"
    [load_avg]="#(${CURRENT_DIR}/scripts/load_avg.sh)"
    [ram_use]="#(${CURRENT_DIR}/scripts/ram_use.sh)"
    [warp_status]="#(${CURRENT_DIR}/scripts/warp.sh)"
)

main() {
    local should_show=$(tmux show-option -gqv @myblocks_toggle)
    tmux bind-key v run-shell "$CURRENT_DIR/scripts/toggle.sh"

    for status_side in status-right status-left; do
        local status_value=$(tmux show-option -gqv "${status_side}")

        for key in "${!TAGS[@]}"; do
            local tag="#{${key}}"
            local script_path="${TAGS[$key]}"

            local value=""
            if [[ "${should_show}" == "on" ]]; then
                value="$script_path"
            fi
            status_value="${status_value//$tag/$value}"

            # echo "Tag: ${tag}" >>/tmp/tmux_my_blocks.log
            # echo "Value: ${value}" >>/tmp/tmux_my_blocks.log
        done

        tmux set-option -gq "${status_side}" "${status_value}"
    done
}

main

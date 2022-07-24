#!/bin/bash

get_tmux_option() {
    local option=$1
    local default_value=$2
    local option_value="$(tmux show-option -gqv "$option")"

    if [[ -z "$option_value" ]]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

set_tmux_option() {
    local option=$1
    local value=$2
    tmux set-option -gq "$option" "$value"
}

is_update_needed() {
    local update_file=$1

    local interval=$(get_tmux_option 'status-interval' 5)
    local update_time=$(read_file $update_file)
    local cur_time=$(date +%s)
    if [ $((update_time + interval)) -gt $cur_time ]; then
        return 1;
    fi;
    return 0;
}


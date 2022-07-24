#!/bin/bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/scripts/helpers.sh"
myblocks_show=$(get_tmux_option @myblocks_toggle "off")
tmux bind-key l run-shell "$CURRENT_DIR/scripts/toggle.sh"

#{battery} #{cpu_temp} #{ip_local} #{load_avg} #{ram_use} #{warp_status}
# @cpu_temp_type: "lm-sensor", "native"
# @net_interfaces: ""
# @net_show_name: "on", "off"
# @myblocks_toggle: "on", "off"

battery=""
cpu_temp=""
ip_local=""
load_avg=""
ram_use=""
warp_status=""

if [[ "$myblocks_show" == "on" ]]; then
    battery="#($CURRENT_DIR/scripts/battery.sh)"
    cpu_temp="#($CURRENT_DIR/scripts/cpu_temp.sh)"
    ip_local="#($CURRENT_DIR/scripts/ip_local.sh)"
    load_avg="#($CURRENT_DIR/scripts/load_avg.sh)"
    ram_use="#($CURRENT_DIR/scripts/ram_use.sh)"
    warp_status="#($CURRENT_DIR/scripts/warp.sh)"
fi

battery_interpolation="\#{battery}"
cpu_temp_interpolation="\#{cpu_temp}"
ip_local_interpolation="\#{ip_local}"
load_avg_interpolation="\#{load_avg}"
ram_use_interpolation="\#{ram_use}"
warp_status_interpolation="\#{warp_status}"


do_interpolation() {
    local input=$1
    local result=$input

    result=${result/$battery_interpolation/$battery}
    result=${result/$cpu_temp_interpolation/$cpu_temp}
    result=${result/$ip_local_interpolation/$ip_local}
    result=${result/$load_avg_interpolation/$load_avg}
    result=${result/$ram_use_interpolation/$ram_use}
    result=${result/$warp_status_interpolation/$warp_status}

    echo $result
}

update_tmux_option() {
    local option=$1
    local option_value=$(get_tmux_option "$option")
    local new_option_value=$(do_interpolation "$option_value")
    set_tmux_option "$option" "$new_option_value"
}

main() {
    update_tmux_option "status-right"
    update_tmux_option "status-left"
}

main

#!/bin/bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

get_interfaces() {
    local interfaces=$(get_tmux_option @net_interfaces "")
    if [[ -z "$interfaces" ]] ; then
        for interface in /sys/class/net/* ; do
            interfaces+=$(echo $(basename $interface) " ");
        done
    fi
    printf "$interfaces"
}

get_active_interfaces(){
    declare -a interfaces=$(get_interfaces)

    for iface in ${interfaces[@]}; do
        read status < /sys/class/net/$iface/operstate;
        if [ "$status" == "up" ] ; then
            printf "$iface"
        fi
    done
}

function ip_address() {
    local show_name=$(get_tmux_option @net_show_name "")
    declare -a interfaces=$(get_active_interfaces)

    for iface in ${interfaces[@]} ; do
        ip=$(ip addr show $iface | awk -F"[/ ]+" '/inet / {print $3}')
        if [[ "$show_name" == "on" ]]; then
            printf "$iface:$ip⏐"
        else
            printf "$ip⏐"
        fi
    done

}

ip_address

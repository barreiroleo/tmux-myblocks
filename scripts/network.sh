#!/bin/bash

# NOTE: Usage
# set-option -g status-right    "#{network} Things #h "
#                               '<Physical_name>:<alias> <Physical_name>:<alias>'
# set-option -g @net_interfaces 'wlan0:wlan enp0s13f0u1u4:eth'

declare -A IFACE_NAME_MAP
NET_INTERFACES=""

function process_interface_names() {
    # Side effect: mutates global IFACE_NAME_MAP and NET_INTERFACES
    local names="$1"
    for pair in ${names}; do
        local key="${pair%%:*}"
        local val="${pair#*:}"
        IFACE_NAME_MAP["${key}"]="${val}"
        NET_INTERFACES="${NET_INTERFACES} ${key}"
    done
}

function get_local_ips() {
    local ip_list=()
    for iface in ${NET_INTERFACES}; do
        local ip=$(ip addr show "${iface}" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
        local name="${IFACE_NAME_MAP[$iface]:-$iface}"
        [[ -n "${ip}" ]] && ip_list+=("${name}:${ip}")
    done
    local joined_ips="${ip_list[0]}"
    for ((i=1; i<${#ip_list[@]}; i++)); do
        joined_ips+=" | ${ip_list[i]}"
    done
    echo "${joined_ips}"
}

function get_external_ip() {
    local ext_ip=$(curl -s icanhazip.com)
    if [[ -n "${ext_ip}" ]]; then
        echo "${ext_ip}"
    else
        echo "-.-.-.-"
    fi
}

function get_ping() {
    local ping_output=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | grep 'time=' | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
    if [[ -n "${ping_output}" ]]; then
        echo "${ping_output}"
    else
        echo "--"
    fi
}

function ip_address() {
    local IP_local=""
    local IP_ext=""
    local ping_result=""

    local now_sec=$(date +%S)
    if [[ $((10#${now_sec} % 5)) -eq 0 ]]; then
        local NET_INTERFACE_NAMES=$(tmux show-option -gqv @net_interfaces)
        process_interface_names "${NET_INTERFACE_NAMES}"

        IP_local=$(get_local_ips)
        IP_ext=$(get_external_ip)
        ping_result=$(get_ping)

        tmux set-option -gq @local_ip "${IP_local}"
        tmux set-option -gq @external_ip "${IP_ext}"
        tmux set-option -gq @ping_8888 "${ping_result}"
    else
        IP_local=$(tmux show-option -gqv @local_ip)
        IP_ext=$(tmux show-option -gqv @external_ip)
        ping_result=$(tmux show-option -gqv @ping_8888)
    fi

    local output=$(printf "%s | Ext:%s | %sms" "${IP_local}" "${IP_ext}" "${ping_result}")

    # for iface in ${NET_INTERFACES}; do
    #     local iface_name="${IFACE_NAME_MAP[$iface]}"
    #     echo "Interface: ${iface_name} (${iface})" >>/tmp/tmux_ip_address.log
    # done
    # echo ${output} >>/tmp/tmux_ip_address.log
    echo ${output}
}

ip_address

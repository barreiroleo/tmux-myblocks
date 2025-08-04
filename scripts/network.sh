#!/bin/bash

# NOTE: Usage
# set-option -g status-right    "#{network} Things #h "
#                               '<Physical_name>:<alias> <Physical_name>:<alias>'
# set-option -g @net_interfaces 'wlan0:wlan enp0s13f0u1u4:eth'

declare -A IFACE_NAME_MAP
NET_INTERFACES=""

#########
# Helpers
#########

function should_update() {
    local now_sec=$(date +%S)
    return $((10#${now_sec} % 5))
}

function join_list() {
    local arr=("$@")
    if [ "${#arr[@]}" -gt 1 ]; then
        local str=$(printf "%s | " "${arr[@]}")
        echo "${str% | }"
    else
        echo "${arr[0]}"
    fi
}

function process_interface_names() {
    # Side effect: mutates global IFACE_NAME_MAP and NET_INTERFACES
    local names=$(tmux show-option -gqv @net_interfaces)
    for pair in ${names}; do
        local key="${pair%%:*}"
        local val="${pair#*:}"
        IFACE_NAME_MAP["${key}"]="${val}"
        NET_INTERFACES="${NET_INTERFACES} ${key}"
    done
}

#########
# IPs
#########

function get_local_ip() {
    local iface="$1"
    local ip=$(ip addr show "${iface}" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
    if [[ -n "${ip}" ]]; then
        echo "${ip}"
    else
        echo "-.-.-.-"
    fi
}

function get_local_ips_array() {
    local ips=()
    for iface in ${NET_INTERFACES}; do
        local alias="${IFACE_NAME_MAP[${iface}]}"
        local ip=$(get_local_ip "${iface}")
        ips+=("${alias}: ${ip}")
    done
    printf '%s\n' "${ips[@]}"
}

function get_external_ip() {
    local ext_ip=$(curl -s icanhazip.com)
    if [[ -n "${ext_ip}" ]]; then
        echo "${ext_ip}"
    else
        echo "-.-.-.-"
    fi
}

function update_local_ips() {
    if ! should_update; then
        echo $(tmux show-option -gqv "@cache_local_ips")
        return
    fi

    readarray -t ips < <(get_local_ips_array)
    local ips_str=$(join_list "${ips[@]}")
    tmux set-option -gq "@cache_local_ips" "${ips_str}"
    echo "${ips_str}"
}

function update_external_ip() {
    if ! should_update; then
        echo $(tmux show-option -gqv "@cache_external_ip")
        return
    fi

    local external_ip=$(get_external_ip)
    tmux set-option -gq "@cache_external_ip" "${external_ip}"
    echo "${external_ip}"
}

#########
# Speed
#########

function format_speed() {
    local speed_bytes="$1"
    if [[ -z "$speed_bytes" || "$speed_bytes" -eq 0 ]]; then
        echo "0 KB/s"
        return
    fi
    if ((speed_bytes < 1048576)); then
        printf "%d KB/s" $((speed_bytes / 1024))
    else
        printf "%.1f MB/s" "$(echo "scale=1; ${speed_bytes}/1048576" | bc)"
    fi
}

function get_speed() {
    local iface="$1"
    local tx_rx="$2" # "tx" for upload, "rx" for download

    local stat_file="/sys/class/net/${iface}/statistics/${tx_rx}_bytes"
    local tmux_key="@${tx_rx}_bytes_${iface}"
    local curr_bytes=$(cat "${stat_file}" 2>/dev/null)
    local prev_bytes=$(tmux show-option -gqv "${tmux_key}")
    tmux set-option -gq "${tmux_key}" "${curr_bytes}"

    if [[ -n "${curr_bytes}" && -n "${prev_bytes}" ]]; then
        local speed=$((curr_bytes - prev_bytes))
        if ((speed < 0)); then speed=0; fi
        echo "${speed}"
    fi
}

function update_speed() {
    local direction="$1" # "rx" for download, "tx" for upload
    local cache_var="@cache_${direction}_speed"

    if ! should_update; then
        local cached=$(tmux show-option -gqv "${cache_var}")
        echo "$(format_speed ${cached})"
        return
    fi

    local total_speed=0
    for iface in ${NET_INTERFACES}; do
        local alias="${IFACE_NAME_MAP[${iface}]}"
        local speed=$(get_speed "${iface}" "$direction")
        total_speed=$((total_speed + speed))
    done

    tmux set-option -gq "${cache_var}" "${total_speed}"
    echo "$(format_speed ${total_speed})"
}

function update_download_speed() {
    update_speed "rx"
}

function update_upload_speed() {
    update_speed "tx"
}

#########
# Ping
#########

function get_ping() {
    local ping_output=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | grep 'time=' | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
    if [[ -n "${ping_output}" ]]; then
        echo "${ping_output}"
    else
        echo "--"
    fi
}

function update_ping() {
    if ! should_update; then
        echo $(tmux show-option -gqv "@cache_ping")
        return
    fi

    local ping=$(get_ping)
    tmux set-option -gq "@cache_ping" "${ping}"
    echo "${ping}"
}

#########
# Report
#########

function print_ip() {
    setup_interfaces
    local ips_str=$(update_local_ips)
    local external_ip=$(update_external_ip)
    echo "${ips_str} | Ext:${external_ip}"
}

function print_speed() {
    setup_interfaces
    local download_speeds=$(update_download_speed)
    local upload_speeds=$(update_upload_speed)
    echo " ${download_speeds} |  ${upload_speeds}"
}

function print_ping() {
    setup_interfaces
    local ping=$(update_ping)
    echo "${ping} ms"
}

#########
# Args
#########

# Argument parsing and main logic
if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 --ip|--speed|--ping" >&2
    exit 1
fi

case "$1" in
--ip)
    process_interface_names
    print_ip
    ;;
--speed)
    process_interface_names
    print_speed
    ;;
--ping)
    process_interface_names
    print_ping
    ;;
--all)
    process_interface_names
    print_ip
    print_speed
    print_ping
    ;;
*)
    echo "Unknown argument: $1" >&2
    echo "Usage: $0 --ip|--speed|--ping" >&2
    exit 1
    ;;
esac

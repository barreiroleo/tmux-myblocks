#!/bin/bash

# NOTE: Usage
# set-option -g status-right    "#{network} Things #h "
#                               '<Physical_name>:<alias> <Physical_name>:<alias>'
# set-option -g @net_interfaces 'wlan0:wlan enp0s13f0u1u4:eth'

declare -A IFACE_NAME_MAP
NET_INTERFACES=""

function should_update() {
    local now_sec=$(date +%S)
    return $((10#${now_sec} % 5))
}

function join_list() {
    # Receive an array and return a string with a " | " as separator
    local -n arr="$1"
    if [ "${#arr[@]}" -eq 1 ]; then
        echo "${arr[0]}"
    else
        local IFS=' | '
        echo "${arr[*]}"
    fi

}

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

function get_local_ip() {
    local iface="$1"
    local ip=$(ip addr show "${iface}" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
    if [[ -n "${ip}" ]]; then
        echo "${ip}"
    else
        echo "-.-.-.-"
    fi
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

function update_local_ips() {
    if ! should_update; then
        echo $(tmux show-option -gqv "@cache_local_ips")
        return
    fi

    local local_ips=()
    for iface in ${NET_INTERFACES}; do
        local alias="${IFACE_NAME_MAP[${iface}]}"
        local ip=$(get_local_ip "${iface}")
        local_ips+=("${alias}: ${ip}")
    done
    tmux set-option -gq "@cache_local_ips" "$(join_list local_ips)"
    echo "${local_ips[@]}"
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

function update_ping() {
    if ! should_update; then
        echo $(tmux show-option -gqv "@cache_ping")
        return
    fi

    local ping=$(get_ping)
    tmux set-option -gq "@cache_ping" "${ping}"
    echo "${ping}"
}

function update_download_speed() {
    if ! should_update; then
        local cached=$(tmux show-option -gqv "@cache_download_speed")
        echo "$(format_speed ${cached})"
        return
    fi

    local total_download=0
    for iface in ${NET_INTERFACES}; do
        local alias="${IFACE_NAME_MAP[${iface}]}"
        local download=$(get_speed "${iface}" "rx")
        total_download=$((total_download + download))
    done

    tmux set-option -gq "@cache_download_speed" "${total_download}"
    echo "$(format_speed ${total_download})"
}

function update_upload_speed() {
    if ! should_update; then
        local cached=$(tmux show-option -gqv "@cache_upload_speed")
        echo "$(format_speed ${cached})"
        return
    fi

    local total_upload=0
    for iface in ${NET_INTERFACES}; do
        local alias="${IFACE_NAME_MAP[${iface}]}"
        local upload=$(get_speed "${iface}" "tx")
        total_upload=$((total_upload + upload))
    done
    tmux set-option -gq "@cache_upload_speed" "${total_upload}"
    echo "$(format_speed ${total_upload})"
}

function main() {
    local NET_INTERFACE_NAMES
    NET_INTERFACE_NAMES=$(tmux show-option -gqv @net_interfaces)
    process_interface_names "${NET_INTERFACE_NAMES}"

    local local_ips=$(update_local_ips)
    local download_speeds=$(update_download_speed)
    local upload_speeds=$(update_upload_speed)
    local external_ip=$(update_external_ip)
    local ping=$(update_ping)

    # Logging
    echo "" >>/tmp/tmux_ip_address.log
    echo "Local IPs: ${local_ips}" >>/tmp/tmux_ip_address.log
    echo "Download Speeds: ${download_speeds}" >>/tmp/tmux_ip_address.log
    echo "Upload Speeds: ${upload_speeds}" >>/tmp/tmux_ip_address.log
    echo "External IP: ${external_ip}" >>/tmp/tmux_ip_address.log
    echo "Ping: ${ping}" >>/tmp/tmux_ip_address.log

    # Output summary
    local output=$(printf "%s | Ext:%s | %sms" "$(join_list local_ips)" "${external_ip}" "${ping}")
    echo "${output}"
}

main

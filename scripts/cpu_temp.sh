#!/bin/bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

local cpu_type=$(get_tmux_option @cpu_temp_type "")

function get_lmsensor() {
    # Display the temperature of CPU package.
    temp=$(sensors | awk -F "[+ ]" '/Package id/ {print $6+0}')
    printf "$temp°C⏐"
}

function get_thermal0(){
    local temp=""
    read temp < /sys/class/thermal/thermal_zone0/temp
    printf "$((temp/1000))°C⏐"
}

function get_thermal1(){
    local temp=""
    read temp < /sys/class/thermal/thermal_zone1/temp
    printf "$((temp/1000))°C⏐"
}

# Defaults
case $cpu_type in
    "lm-sensor") get_lmsensor
    ;;
    "native") get_thermal0
    ;;
    *) get_thermal0
    ;;
esac

#!/bin/bash

function load_average() {
    printf "%s⏐" "$(uptime | awk -F: '{printf $NF}' | tr -d ',')"
}

load_average

#!/bin/bash

function memory_usage() {
    if [ "$(which bc)" ]; then
        # Display used, total, and percentage of memory using the free command.
        read used total <<< $(free -m | awk '/Mem/{printf $2" "$3}')
        percent=$(bc -l <<< "100 * $total / $used")
        # awk -v u=$used -v t=$total -v p=$percent 'BEGIN {printf "%sMi/%sMi %.1f% ", t, u, p}'
        printf " %.1f%%⏐" "$percent"
    fi
}

memory_usage

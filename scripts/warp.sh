#!/bin/bash

function vpn_connection() {
    # Check for tun0 interface.
    [ -d /sys/class/net/CloudflareWARP ] && printf "⏐%s⏐" 'VPN'
}

vpn_connection

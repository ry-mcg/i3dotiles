#!/usr/bin/env bash
bt_icon=$''

get_status() {
    local powered device
    powered=$(bluetoothctl show | awk -F': ' '/^\tPowered:/{print $2}')

    if [ "$powered" != "yes" ]; then
        printf '%%{T2}%s%%{T-} Off\n' "$bt_icon"
        return
    fi

    device=$(bluetoothctl devices Connected | head -1 | cut -d' ' -f3-)
    if [ -n "$device" ]; then
        printf '%%{T2}%s%%{T-} %s\n' "$bt_icon" "$device"
    else
        printf '%%{T2}%s%%{T-} On\n' "$bt_icon"
    fi
}

get_status
bluetoothctl --monitor < <(sleep infinity) 2>/dev/null |
    grep --line-buffered -aE "Powered:|Connected:" |
    while read -r _; do
        get_status
    done

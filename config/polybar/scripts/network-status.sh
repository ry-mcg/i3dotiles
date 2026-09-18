#!/usr/bin/env bash
wired_state=$(nmcli -t -f DEVICE,STATE device status | grep "^eno2:" | cut -d: -f2)
if [ "$wired_state" = "connected" ]; then
    printf '%%{T2}%%{T-} Ethernet'
    exit 0
fi

wifi_state=$(nmcli -t -f DEVICE,STATE device status | grep "^wlan0:" | cut -d: -f2)
if [ "$wifi_state" = "connected" ]; then
    ssid=$(nmcli -t -f active,ssid dev wifi | grep "^yes:" | cut -d: -f2)
    printf '%%{T2}%%{T-} %s' "$ssid"
    exit 0
fi

printf 'Disconnected'

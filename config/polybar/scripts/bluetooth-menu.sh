#!/usr/bin/env bash
strip_ansi() { sed -r 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }

powered=$(bluetoothctl show | awk -F': ' '/^\tPowered:/{print $2}')

if [ "$powered" = "yes" ]; then
    power_entry="Turn Bluetooth Off"
else
    power_entry="Turn Bluetooth On"
fi

if [ "$powered" != "yes" ]; then
    choice=$(printf "%s\n" "$power_entry" | rofi -dmenu -i -p "Bluetooth")
    [ "$choice" = "$power_entry" ] && bluetoothctl power on
    exit 0
fi

connected_macs=$(bluetoothctl devices Connected | awk '{print $2}')

entries=("$power_entry")
declare -A mac_map
while IFS= read -r line; do
    [ -z "$line" ] && continue
    mac="${line%% *}"
    name="${line#* }"
    if grep -q "$mac" <<<"$connected_macs"; then
        label="$name (Connected)"
    else
        label="$name"
    fi
    entries+=("$label")
    mac_map["$label"]="$mac"
done < <(bluetoothctl devices Paired | cut -d' ' -f2-)
entries+=("Scan for devices")

choice=$(printf "%s\n" "${entries[@]}" | rofi -dmenu -i -p "Bluetooth")
[ -z "$choice" ] && exit 0

if [ "$choice" = "$power_entry" ]; then
    bluetoothctl power off
    exit 0
fi

if [ "$choice" = "Scan for devices" ]; then
    found=$(bluetoothctl --timeout 6 scan on 2>&1 |
        strip_ansi |
        grep -E '^\[NEW\] Device' |
        sed -E 's/^\[NEW\] Device ([0-9A-Fa-f:]+) (.*)/\1|\2/' |
        sort -u -t'|' -k2)
    [ -z "$found" ] && exit 0

    pick=$(cut -d'|' -f2 <<<"$found" | rofi -dmenu -i -p "Pair with")
    [ -z "$pick" ] && exit 0

    pick_mac=$(awk -F'|' -v n="$pick" '$2==n{print $1; exit}' <<<"$found")
    [ -z "$pick_mac" ] && exit 0

    bluetoothctl pair "$pick_mac"
    bluetoothctl trust "$pick_mac"
    bluetoothctl connect "$pick_mac"
    exit 0
fi

mac="${mac_map[$choice]}"
if grep -q "$mac" <<<"$connected_macs"; then
    bluetoothctl disconnect "$mac"
else
    bluetoothctl connect "$mac"
fi

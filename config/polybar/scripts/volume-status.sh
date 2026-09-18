#!/usr/bin/env bash
mute_icon=$''
low_icon=$''
high_icon=$''

get_status() {
    local vol mute icon
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
    vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | tr -d '%')

    if [ "$mute" = "yes" ]; then
        printf '%%{T2}%s%%{T-} muted\n' "$mute_icon"
    else
        if [ "$vol" -lt 30 ]; then
            icon="$low_icon"
        else
            icon="$high_icon"
        fi
        printf '%%{T2}%s%%{T-} %s%%\n' "$icon" "$vol"
    fi
}

get_status
pactl subscribe 2>/dev/null | grep --line-buffered "sink" | while read -r _; do
    get_status
done

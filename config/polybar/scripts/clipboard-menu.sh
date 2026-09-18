#!/usr/bin/env bash
count=$(copyq count)
[ "$count" -eq 0 ] && exit 0

max=$(( count < 50 ? count : 50 ))

items=""
for ((i = 0; i < max; i++)); do
    text=$(copyq read "$i" | head -c 80 | tr '\n' ' ')
    items+="$i: $text"$'\n'
done

choice=$(printf "%s" "$items" | rofi -dmenu -i -p "Clipboard")
[ -z "$choice" ] && exit 0

index="${choice%%:*}"
copyq select "$index"

#!/usr/bin/env bash
# Full-screen screenshot: saves to ~/Pictures/Screenshots and copies to clipboard.
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"

maim "$file" || exit 1
nohup xclip -selection clipboard -t image/png -i "$file" >/dev/null 2>&1 &
disown

nohup notify-send "Screenshot saved" "$file" -i "$file" >/dev/null 2>&1 &
disown

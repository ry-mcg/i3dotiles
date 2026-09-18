#!/usr/bin/env bash
killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

# only outputs that are connected AND currently active (have a mode set) -
# xrandr still reports a powered-off laptop panel as "connected".
for mon in $(xrandr --query | awk '/ connected/ && /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/{print $1}'); do
    MONITOR="$mon" polybar main &
done

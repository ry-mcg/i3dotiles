#!/usr/bin/env bash
choice=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | rofi -dmenu -i -p "Power")
case "$choice" in
    Lock) i3lock -c 000000 ;;
    Logout) i3-msg exit ;;
    Suspend) systemctl suspend ;;
    Reboot) systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac

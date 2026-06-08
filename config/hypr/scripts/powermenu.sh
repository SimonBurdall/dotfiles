#!/usr/bin/env bash

entries="  Lock\n  Suspend\n  Reboot\n⏻  Shutdown"

selected=$(echo -e "$entries" | rofi \
  -dmenu \
  -i \
  -p "power" \
  -theme-str 'window {width: 200px;}' \
  -theme-str 'listview {lines: 4;}')

case "$selected" in
  "  Lock")
    hyprlock ;;
  "  Suspend")
    systemctl suspend ;;
  "  Reboot")
    systemctl reboot ;;
  "⏻  Shutdown")
    systemctl poweroff ;;
esac

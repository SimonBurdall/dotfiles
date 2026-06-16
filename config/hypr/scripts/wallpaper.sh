#!/usr/bin/env bash
# Usage: wallpaper.sh /path/to/image.png

if [ -z "$1" ] || [ ! -f "$1" ]; then
    echo "Usage: wallpaper.sh /path/to/image"
    exit 1
fi

# Run pywal to generate colours
wal -i "$1" -q -t

# Set wallpaper via swaybg
pkill swaybg 2>/dev/null
swaybg -i "$1" -m fill &
disown

ags run ~/.config/ags

# Reload Hyprland colours
hyprctl reload

echo "Wallpaper and colours updated: $1"

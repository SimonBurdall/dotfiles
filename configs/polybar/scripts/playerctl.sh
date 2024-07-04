#!/usr/bin/env bash
VLC_ICON="󰕼"
BROWSER_ICON="󰖟" 
SPOTIFY_ICON="󰓇"
MUSIC_ICON="󰝚"
PAUSE_ICON="󰏤"
KON_ICON=""

status=$(playerctl status 2> /dev/null)

if [ "$status" == "Playing" ]; then
    PLAYER=$(playerctl metadata --format '{{playerName}}')
    ARTIST=$(playerctl metadata artist)
    TITLE=$(playerctl metadata title)
    case "$PLAYER" in
        "chromium" | "firefox")
            ICON=$BROWSER_ICON
            ;;
        "vlc")
            ICON=$VLC_ICON
            ;;
        "spotify")
            ICON=$SPOTIFY_ICON
            ;;
        *)
            ICON=$MUSIC_ICON
            ;;
    esac

    OUTPUT="$ARTIST - $TITLE"
    echo "$ICON $OUTPUT"
elif [ "$status" == "Paused" ]; then
    echo "$PAUSE_ICON Paused"
else
    echo "$KON_ICON \"Fun things are fun.\" - Yui"
fi


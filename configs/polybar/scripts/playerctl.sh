#!/usr/bin/env bash
VLC_ICON="󰕼"
BROWSER_ICON="󰖟" 
SPOTIFY_ICON="󰓇"
MUSIC_ICON="󰝚"
PAUSE_ICON="󰏤"

MAX_LENGTH=30

truncate_string() {
    local string="$1"
    local max_length="$2"
    if [ ${#string} -gt "$max_length" ]; then
        echo "$(echo "$string" | cut -b 1-$((max_length-3)))..."
    else
        echo "$string"
    fi
}

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

    if [ ${#OUTPUT} -gt $MAX_LENGTH ]; then
        AVAILABLE_LENGTH=$((MAX_LENGTH - ${#ICON} - 3))
        TRUNCATED_OUTPUT=$(truncate_string "$OUTPUT" $AVAILABLE_LENGTH)
        echo "$ICON $TRUNCATED_OUTPUT"
    else
        echo "$ICON $OUTPUT"
    fi
elif [ "$status" == "Paused" ]; then
    echo "$PAUSE_ICON Paused"
else
    echo "$MUSIC_ICON Fun things are fun."
fi


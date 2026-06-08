#!/usr/bin/env bash
# Shows "artist — title" when something is playing via MPRIS.
# When idle, shows a random quote.

BROWSER_ICON="󰖟"
VLC_ICON="󰕼"
SPOTIFY_ICON="󰓇"
MUSIC_ICON="󰝚"

quotes=(
  "Fun things are fun. — Yui"
  "After-school tea time."
  "Practice makes perfect."
  "One more song."
  "Keep it light, keep it moving."
)

status=$(playerctl status 2>/dev/null)

if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
    PLAYER=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)
    ARTIST=$(playerctl metadata artist 2>/dev/null)
    TITLE=$(playerctl metadata title 2>/dev/null)
    case "$PLAYER" in
        firefox|brave|chromium|floorp) ICON=$BROWSER_ICON ;;
        vlc) ICON=$VLC_ICON ;;
        spotify) ICON=$SPOTIFY_ICON ;;
        *) ICON=$MUSIC_ICON ;;
    esac
    if [ -n "$ARTIST" ]; then
        TEXT="$ICON $ARTIST — $TITLE"
    else
        TEXT="$ICON $TITLE"
    fi
    printf '{"text":"%s","class":"playing"}\n' "$(echo "$TEXT" | sed 's/"/\\"/g')"
else
    QUOTE="${quotes[$RANDOM % ${#quotes[@]}]}"
    printf '{"text":"%s","class":"idle"}\n' "$(echo "$QUOTE" | sed 's/"/\\"/g')"
fi

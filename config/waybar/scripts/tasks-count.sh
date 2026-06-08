#!/usr/bin/env bash
# Fetches active task count from Todoist REST API.
# Put your API token in ~/.config/waybar/todoist-token (single line, chmod 600).

TOKEN_FILE="$HOME/.config/waybar/todoist-token"

if [ ! -f "$TOKEN_FILE" ]; then
    echo "0"
    exit 0
fi

TOKEN=$(cat "$TOKEN_FILE")

COUNT=$(curl -s --max-time 5 \
    -H "Authorization: Bearer $TOKEN" \
    "https://api.todoist.com/rest/v2/tasks" \
    | grep -o '"id"' | wc -l)

if [ -z "$COUNT" ] || [ "$COUNT" = "0" ]; then
    echo "0"
else
    echo "$COUNT"
fi

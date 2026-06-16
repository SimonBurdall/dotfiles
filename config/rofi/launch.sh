#!/usr/bin/env bash
source "${HOME}/.cache/wal/colors.sh" 2>/dev/null

exec rofi -show drun -theme "${HOME}/.config/rofi/launcher.rasi" \
  -theme-str "* {
      bg:          ${background:-#111217}EB;
      fg:          ${foreground:-#c3c3c5};
      accent:      ${color4:-#d98a5a};
      accent-soft: ${color4:-#d98a5a}1a;
      accent-sel:  ${color4:-#d98a5a}66;
      muted:       ${color8:-#6a6f7d};
  }"

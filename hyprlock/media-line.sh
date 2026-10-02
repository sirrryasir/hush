#!/bin/sh
# One line for the lock screen: "Artist - Title" while something plays, else a blank
# braille cell (hyprlock shows "Sample Text" for an empty or whitespace-only label).
if [ "$(playerctl -s status 2>/dev/null)" = Playing ]; then
  playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | cut -c1-60
else
  printf '\342\240\200\n'
fi

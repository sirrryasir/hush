#!/bin/sh
# Caps lock glyph for the lock screen pill (Material Symbols ligature), polled every 250 ms.
# hyprlock shows "Sample Text" for an empty label, so print a blank braille cell instead.
if hyprctl devices -j 2>/dev/null | grep -q '"capsLock": true'; then
  echo keyboard_capslock
else
  printf '\342\240\200\n'
fi

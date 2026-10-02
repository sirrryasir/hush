#!/usr/bin/env bash
# Hush build timelapse: one JPEG every 120 s while the build runs. Stop with: pkill -f timelapse/record.sh
cd "$(dirname "$0")"
while true; do
  hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null 2>&1
  grim -t jpeg -q 70 "frame-$(date +%Y%m%d-%H%M%S).jpg" 2>/dev/null
  sleep 120
done

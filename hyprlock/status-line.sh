#!/bin/sh
# Top-right lock screen status: battery and network as Material Symbols ligatures, icons only.
# Hidden (a blank braille cell; hyprlock shows "Sample Text" for empty labels) on mains with no
# battery or a full one, over a wired link.
icons=""
for b in /sys/class/power_supply/BAT*; do
  [ -r "$b/capacity" ] || continue
  cap=$(cat "$b/capacity"); st=$(cat "$b/status" 2>/dev/null)
  if [ "$st" = Charging ]; then icons="battery_charging_full"
  elif [ "$cap" -lt 100 ] || [ "$st" = Discharging ]; then
    bars=$(( (cap * 6 + 50) / 100 ))
    case $bars in 0) icons="battery_0_bar" ;; 6) icons="battery_full" ;; *) icons="battery_${bars}_bar" ;; esac
  fi
  break
done
net=""
if command -v nmcli >/dev/null; then
  case "$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep ':connected$' | head -1 | cut -d: -f1)" in
    wifi) net="wifi" ;;
    ethernet) net="" ;;
    *) net="wifi_off" ;;
  esac
fi
line=$(printf '%s %s' "$icons" "$net" | sed 's/^ *//; s/ *$//')
[ -n "$line" ] && echo "$line" || printf '\342\240\200\n'

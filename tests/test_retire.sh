#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
t_gone() {
  pkill -x waybar 2>/dev/null; pkill -x swaync 2>/dev/null; pkill -x dunst 2>/dev/null; sleep 1
  pgrep -x waybar >/dev/null && fail "waybar running" || pass "waybar not running"
  pgrep -x swaync >/dev/null && fail "swaync running" || pass "swaync not running"
  hyprctl layers -j | grep -q '"namespace": "waybar"' && fail "waybar layer present" || pass "no waybar layer"
  assert_eq "0" "$(grep -cE 'rofi|swaync|wlogout|dunst|waybar' "$CFG"/hypr/modules/binds.lua)" "binds.lua has no retired tools"
  assert_eq "0" "$(grep -cE 'waybar|dunst|swaync' "$CFG"/hypr/modules/autostart.lua)" "autostart has no retired tools"
  grep -q 'hush shell start' "$CFG"/hypr/modules/autostart.lua && pass "autostart starts the shell" || fail "autostart lacks hush shell start"
  grep -q 'Exec=/bin/true' ~/.local/share/dbus-1/services/org.erikreider.swaync.service && pass "swaync activation neutralized" || fail "swaync dbus override missing"
  [[ -z "$(hyprctl configerrors | grep -v '^$')" ]] && pass "no configerrors" || fail "configerrors present"
}
t_zone() {
  bin/hush shell start >/dev/null; sleep 1
  hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class retire-probe")' >/dev/null; sleep 2
  local y; y=$(hyprctl clients -j | python3 -c "
import json,sys
c=[c for c in json.load(sys.stdin) if c['class']=='retire-probe']
print(c[0]['at'][1] if c else '')")
  hyprctl dispatch 'hl.dsp.window.close({ window = "class:retire-probe" })' >/dev/null 2>&1; pkill -f '^kitty --class retire-prob[e]' 2>/dev/null
  [[ -n "$y" ]] && (( y >= 64 )) && pass "window starts at y=$y >= 64" || fail "window y='$y' < 64"
}
t_fallback() {
  bin/hush fallback >/dev/null; sleep 2
  pgrep -x waybar >/dev/null && pass "fallback brings waybar back" || fail "waybar not started"
  shell_alive && fail "shell still running in fallback" || pass "fallback stopped the shell"
  bin/hush shell start >/dev/null
  pgrep -x waybar >/dev/null && fail "shell start left waybar" || pass "shell start stopped waybar"
  pkill -x swaync 2>/dev/null; true
}
run_test "gone" t_gone; run_test "zone" t_zone; run_test "fallback" t_fallback
finish

#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
NMON=$(hyprctl monitors -j | jq length)
# The rest layout's own width (independent of which state the island is showing).
width() { shell_ipc restWidth; }
settle() { sleep 0.3; width; }
t_rest() {
  shell_restart; sleep 3
  pkill -f tests/fakempris.py 2>/dev/null; sleep 1
  assert_eq "rest" "$(shell_ipc islandState)" "island at rest"
  local narrow; narrow=$(settle)
  [[ "$narrow" -le 112 ]] && pass "pill is narrow with no media (${narrow}px)" || fail "pill not narrow with no media (${narrow}px)"
  assert_eq "0" "$((narrow % 8))" "pill width on the 8 px grid"
  local w
  python3 tests/fakempris.py & local fp=$!; sleep 3
  if kill -0 "$fp" 2>/dev/null; then
    w=$(settle)
    [[ "$w" -gt "$narrow" ]] && pass "pill grows with a media player (${narrow} -> ${w}px)" || fail "pill did not grow (${narrow} -> ${w})"
    kill "$fp" 2>/dev/null; wait "$fp" 2>/dev/null; sleep 6
    assert_eq "$narrow" "$(settle)" "pill shrinks again when the player goes"
  else echo "SKIPPED: fake MPRIS needs dbus-python and PyGObject"; fi
}
t_clock() {
  local d s; d=$(date +%H:%M); s=$(shell_ipc restClock)
  assert_eq "$d" "$s" "rest clock shows $d"
}
t_corners() {
  local n; n=$(hyprctl layers -j | jq '[.. | objects | select((.namespace? // "") | startswith("hush-corner"))] | length')
  assert_eq "0" "$n" "no corner layers"
}
t_workspace() {
  local cur; cur=$(hyprctl activeworkspace -j | jq .id)
  assert_eq "$cur" "$(shell_ipc focusedWorkspace)" "focusedWorkspace matches hyprctl"
  local other=2; [[ "$cur" == "2" ]] && other=3
  hyprctl dispatch "hl.dsp.focus({ workspace = $other })" >/dev/null; sleep 0.5
  assert_eq "$other" "$(shell_ipc focusedWorkspace)" "focusedWorkspace follows dispatch"
  hyprctl dispatch "hl.dsp.focus({ workspace = $cur })" >/dev/null; sleep 0.5
  assert_eq "$cur" "$(shell_ipc focusedWorkspace)" "focusedWorkspace follows switch back"
}
t_go() {
  local cur other=2; cur=$(hyprctl activeworkspace -j | jq .id)
  [[ "$cur" == "2" ]] && other=3
  shell_ipc goWorkspace "$other" >/dev/null; sleep 0.5
  assert_eq "$other" "$(hyprctl activeworkspace -j | jq .id)" "Hypr.go switches workspace via Lua dispatcher"
  shell_ipc goWorkspace "$cur" >/dev/null; sleep 0.5
  assert_eq "$cur" "$(hyprctl activeworkspace -j | jq .id)" "Hypr.go switches back"
}
t_status() {
  local bat q d; bat=$(cat /sys/class/power_supply/BAT0/capacity); q=$(shell_ipc batteryPercent)
  d=$(( bat - q )); d=${d#-}
  [[ "$d" -le 1 ]] && pass "batteryPercent $q within 1 of $bat" || fail "batteryPercent $q vs sysfs $bat"
  assert_eq "true" "$(shell_ipc netConnected)" "netConnected true"
}
# Status ring centre: the battery percent by default; island.statusCenter flips it to a glyph.
t_center() {
  local c sj="$CFG/hush/settings.json" sbak=""; c=$(shell_ipc ringCenter)
  if [[ "$(shell_ipc batteryPresent)" != "true" ]]; then
    [[ "$c" == glyph:* ]] && pass "no battery: centre is the Wi-Fi glyph ($c)" || fail "no battery: centre $c"; return; fi
  if [[ "$(shell_ipc batteryCharging)" == "true" ]]; then
    assert_eq "glyph:bolt" "$c" "charging: the bolt replaces the percent"
  else
    assert_eq "percent:$(shell_ipc batteryPercent)" "$c" "status centre shows the battery percent"
  fi
  [[ -f "$sj" ]] && sbak=$(cat "$sj")
  shell_ipc settingsSet island.statusCenter '"wifi"' >/dev/null; sleep 0.5
  c=$(shell_ipc ringCenter)
  [[ "$c" == glyph:* ]] && pass "statusCenter wifi: centre is a glyph ($c)" || fail "statusCenter wifi: centre $c"
  shell_ipc settingsSet island.statusCenter '"none"' >/dev/null; sleep 0.5
  c=$(shell_ipc ringCenter)
  [[ "$c" == none || "$c" == glyph:bolt ]] && pass "statusCenter none: empty centre ($c)" || fail "statusCenter none: centre $c"
  shell_ipc settingsSet island.statusCenter '"percent"' >/dev/null; sleep 0.5
  [[ "$(shell_ipc ringCenter)" == percent:* || "$(shell_ipc batteryCharging)" == "true" ]] && pass "statusCenter percent restores the number" || fail "percent not restored"
  if [[ -n "$sbak" ]]; then printf '%s\n' "$sbak" >"$sj"; else rm -f "$sj"; fi
  [[ -n "$(shell_ipc batterySummary)" ]] && pass "battery summary: $(shell_ipc batterySummary)" || fail "empty battery summary"
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "rest" t_rest
run_test "clock" t_clock
run_test "corners" t_corners
run_test "workspace" t_workspace
run_test "go" t_go
run_test "status" t_status
run_test "center" t_center
run_test "log" t_log
finish

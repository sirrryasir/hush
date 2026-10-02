#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
layer_count() { hyprctl layers -j | jq "[.. | objects | select(.namespace? == \"$1\")] | length"; }
NMON=$(hyprctl monitors -j | jq length)
t_layers() {
  shell_restart; sleep 2
  assert_eq "$NMON" "$(layer_count hush-corner-left)" "corner-left on every monitor"
  assert_eq "$NMON" "$(layer_count hush-corner-right)" "corner-right on every monitor"
  local ys; ys=$(hyprctl layers -j | jq '[.. | objects | select((.namespace? // "") | startswith("hush-corner")) | .y] | max')
  [[ "$ys" -lt 30 ]] && pass "corners at the top edge (max y=$ys)" || fail "corners pushed down (max y=$ys)"
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
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "layers" t_layers
run_test "workspace" t_workspace
run_test "go" t_go
run_test "status" t_status
run_test "log" t_log
finish

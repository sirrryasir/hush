#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
# Monitors that carry a hush-island layer (hyprctl layers -j keys are monitor names).
island_monitors() {
  hyprctl layers -j | python3 -c "
import json,sys
for name, mon in sorted(json.load(sys.stdin).items()):
  if any(l['namespace']=='hush-island' for lvl in mon['levels'].values() for l in lvl): print(name)"
}
t_layer() {
  shell_restart
  shell_has_layer hush-island && pass "hush-island layer present" || fail "hush-island layer missing"
  local mons; mons=$(island_monitors | tr '\n' ' ')
  local m
  for m in $(hyprctl monitors -j | python3 -c "import json,sys;print(' '.join(m['name'] for m in json.load(sys.stdin)))"); do
    [[ " $mons" == *" $m "* ]] && pass "island on $m" || fail "island missing on $m (got: $mons)"
  done
}
t_state() {
  assert_eq "rest" "$(shell_ipc islandState)" "island starts at rest"
  shell_ipc toggleControlCenter; sleep 0.5
  assert_eq "expanded" "$(shell_ipc islandState)" "toggleControlCenter expands"
  shell_ipc toggleControlCenter; sleep 0.5
  assert_eq "rest" "$(shell_ipc islandState)" "toggle again collapses"
}
t_geometry() {
  # Every island layer window is islandExpanded (560x320) + 40/20.
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
print(' '.join(sorted({'%dx%d' % (l['w'], l['h']) for mon in json.load(sys.stdin).values() for lvl in mon['levels'].values() for l in lvl if l['namespace']=='hush-island'})))")
  assert_eq "600x340" "$g" "island layer windows are 600x340"
  # The body springs to the active state's size.
  assert_eq "320x36" "$(shell_ipc islandSize)" "pill is 320x36 at rest"
  shell_ipc toggleControlCenter; sleep 0.6
  assert_eq "560x320" "$(shell_ipc islandSize)" "pill springs to 560x320 expanded"
  shell_ipc toggleControlCenter; sleep 0.6
  assert_eq "320x36" "$(shell_ipc islandSize)" "pill springs back to 320x36"
}
t_zone() {
  # The island sits at y=6 on every monitor and reserves the top band: tiled windows start at
  # or below exclusiveTop (48) + gaps_out (16).
  local ys; ys=$(hyprctl layers -j | python3 -c "
import json,sys
print(' '.join(sorted({str(l['y']) for mon in json.load(sys.stdin).values() for lvl in mon['levels'].values() for l in lvl if l['namespace']=='hush-island'})))")
  assert_eq "6" "$ys" "island layer y is 6 on every monitor"
  local k; k=$(hyprctl clients -j | python3 -c "
import json,sys
cs=[c for c in json.load(sys.stdin) if c['class']=='kitty' and not c['floating']]
print(min(c['at'][1] for c in cs) if cs else '')")
  if [[ -z "$k" ]]; then fail "no tiled kitty window to measure"
  elif (( k >= 64 )); then pass "tiled kitty starts at y=$k >= 64"
  else fail "tiled kitty at y=$k < 64"; fi
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
t_cpu() { local c; c=$(shell_cpu_idle); python3 -c "import sys; sys.exit(0 if float('$c') < 1.0 else 1)" && pass "idle cpu ${c}% < 1%" || fail "idle cpu ${c}%"; }
run_test "layer" t_layer; run_test "state" t_state; run_test "geometry" t_geometry; run_test "zone" t_zone; run_test "log" t_log; run_test "cpu" t_cpu
finish

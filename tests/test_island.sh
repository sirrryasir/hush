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
  # v2 surface: every island layer is its monitor's full width x 360 and never resizes (test_surface.sh
  # covers it per state); the body springs to the active state's size inside it.
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
print(' '.join(sorted({'%d' % l['h'] for mon in json.load(sys.stdin).values() for lvl in mon['levels'].values() for l in lvl if l['namespace']=='hush-island'})))")
  assert_eq "360" "$g" "island layer windows are 360 tall"
  local rest; rest=$(shell_ipc islandSize)
  [[ "$rest" =~ ^[0-9]+x36$ ]] && pass "pill is ${rest} at rest" || fail "pill at rest is $rest"
  shell_ipc toggleControlCenter; sleep 0.6
  assert_eq "560x320" "$(shell_ipc islandSize)" "pill springs to 560x320 expanded"
  shell_ipc toggleControlCenter; sleep 0.6
  assert_eq "$rest" "$(shell_ipc islandSize)" "pill springs back to $rest"
}
t_zone() {
  # The island surface sits at the top edge of every monitor and reserves 40 px (settings
  # island.reserve): tiled windows start at or below 40 + gaps_out (16).
  local ys; ys=$(hyprctl layers -j | python3 -c "
import json,sys
ms={m['name']:m['y'] for m in json.loads(sys.argv[1])}
print(' '.join(sorted({str(l['y']-ms[n]) for n,mon in json.load(sys.stdin).items() for lvl in mon['levels'].values() for l in lvl if l['namespace']=='hush-island'})))" "$(hyprctl monitors -j)")
  assert_eq "0" "$ys" "island layer is flush with the top of every monitor"
  local k; k=$(hyprctl clients -j | python3 -c "
import json,sys
cs=[c for c in json.load(sys.stdin) if not c['floating'] and c['workspace']['id']>0]
print(min(c['at'][1] - next(m['y'] for m in json.loads(sys.argv[1]) if m['id']==c['monitor']) for c in cs) if cs else '')" "$(hyprctl monitors -j)")
  if [[ -z "$k" ]]; then pass "no tiled window to measure (skipped)"
  elif (( k >= 56 )); then pass "tiled windows start at y=$k >= 56"
  else fail "tiled window at y=$k < 56"; fi
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
t_cpu() { local c; c=$(shell_cpu_idle); python3 -c "import sys; sys.exit(0 if float('$c') < 1.0 else 1)" && pass "idle cpu ${c}% < 1%" || fail "idle cpu ${c}%"; }
run_test "layer" t_layer; run_test "state" t_state; run_test "geometry" t_geometry; run_test "zone" t_zone; run_test "log" t_log; run_test "cpu" t_cpu
finish

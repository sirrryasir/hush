#!/usr/bin/env bash
# The island that IPC drives (and expands) is the one on the FOCUSED monitor.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
mons() { hyprctl monitors -j | python3 -c "import json,sys;print(' '.join(m['name'] for m in json.load(sys.stdin)))"; }
focused() { hyprctl monitors -j | python3 -c "import json,sys;print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))"; }
ORIG_MON=$(focused)
restore() { hyprctl dispatch "hl.dsp.focus({ monitor = \"$ORIG_MON\" })" >/dev/null 2>&1; shell_ipc islandState 2>/dev/null | grep -q expanded && shell_ipc toggleControlCenter >/dev/null 2>&1; }
trap restore EXIT
t_follow() {
  local m
  if [[ $(mons | wc -w) -lt 2 ]]; then pass "single monitor: focus-follow check skipped"; return; fi
  shell_restart; sleep 3
  for m in $(mons | tr ' ' '\n' | head -2); do
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$m\" })" >/dev/null; sleep 0.7
    assert_eq "$m" "$(focused)" "focused monitor is $m"
    assert_eq "$m" "$(shell_ipc islandScreen)" "idle: IPC island follows focus to $m"
    shell_ipc toggleControlCenter >/dev/null; sleep 1.2
    assert_eq "expanded" "$(shell_ipc islandState)" "control center opens ($m focused)"
    assert_eq "$m" "$(shell_ipc islandScreen)" "expanded island is on $m"
    # Focus moves away while expanded: it must stay put until collapsed.
    local other; other=$(mons | tr ' ' '\n' | grep -vx "$m" | head -1)
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$other\" })" >/dev/null; sleep 0.7
    assert_eq "$m" "$(shell_ipc islandScreen)" "expanded island stays on $m after focus moves to $other"
    shell_ipc toggleControlCenter >/dev/null; sleep 1
    assert_eq "rest" "$(shell_ipc islandState)" "collapses"
    assert_eq "$other" "$(shell_ipc islandScreen)" "after collapse the role follows focus to $other"
  done
  local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"
}
run_test "island follows focus" t_follow
finish

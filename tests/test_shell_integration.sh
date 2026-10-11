#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
mkdir -p "${HUSH_EVIDENCE_DIR:-$HOME/.cache/hush/evidence}"
primary_json() { python3 -c "import json;print(json.load(open('$HOME/.config/hush/Colors.json'))['primary'])"; }
wait_ipc() { local i; for i in $(seq 1 25); do [[ "$(shell_ipc "$1")" == "$2" ]] && return 0; sleep 0.2; done; return 1; }
wait_state() { local i; for i in $(seq 1 20); do [[ "$(shell_ipc islandState)" == "$1" ]] && return 0; sleep 0.3; done; return 1; }
t_themes() {
  shell_restart
  local t
  for t in harbor ember moss dusk paper fog; do
    bin/hush theme "$t" >/dev/null; sleep 3
    assert_eq "$(primary_json)" "$(shell_ipc primary)" "$t: shell primary matches Colors.json"
    wait_ipc islandState rest && pass "$t: island at rest" || fail "$t: island not at rest ($(shell_ipc islandState))"
    notify-send "Hush $t" "integration probe"; wait_state notification && pass "$t: island shows notification" || fail "$t: no notification state"
    wait_state rest && pass "$t: island returns to rest" || fail "$t: island stuck"
    wait_ipc islandState rest; wait_ipc launcherVisible false
    shell_ipc toggleLauncher; wait_ipc launcherVisible true && pass "$t: launcher opens" || fail "$t: launcher did not open"
    sleep 0.5; shell_ipc toggleLauncher; wait_ipc launcherVisible false && pass "$t: launcher closes" || fail "$t: launcher did not close"
    shell_screenshot "integration-$t-rest"
    wait_ipc islandState rest; sleep 0.5
    shell_ipc toggleControlCenter; wait_ipc islandState expanded && pass "$t: control center opens" || fail "$t: control center did not open"
    sleep 0.5
    shell_screenshot "integration-$t-cc"
    shell_ipc toggleControlCenter; wait_ipc islandState rest && pass "$t: control center closes" || fail "$t: control center did not close"
  done
}
t_perf() {
  bin/hush theme harbor >/dev/null; sleep 3
  hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class perf-probe")' >/dev/null
  local pl=""
  if command -v mpv >/dev/null; then
    [[ -f /tmp/hush-silence.wav ]] || ffmpeg -loglevel quiet -f lavfi -i anullsrc=r=44100:cl=mono -t 30 /tmp/hush-silence.wav
    mpv --no-video --really-quiet --audio-device=null --loop=inf /tmp/hush-silence.wav >/dev/null 2>&1 & pl=$!
  fi
  sleep 3
  local c; c=$(shell_cpu_idle)
  echo "  idle cpu: ${c}% (kitty open, mpv ${pl:+playing}${pl:-absent})" | tee "$HOME/.cache/hush/last-cpu.txt"
  [[ -n "$pl" ]] && kill "$pl" 2>/dev/null; session_pkill -f '^kitty --class perf-prob[e]' 2>/dev/null
  python3 -c "import sys; sys.exit(0 if float('$c') < 1.0 else 1)" && pass "idle cpu ${c}% < 1%" || fail "idle cpu ${c}%"
}
t_health() {
  local out; out=$(HUSH_CHECK_NO_HYPR= bin/hush check 2>&1); [[ $? -eq 0 ]] && pass "hush check ok" || fail "hush check: $out"
  [[ -z "$(hyprctl configerrors | grep -v '^$')" ]] && pass "no configerrors" || fail "configerrors"
  local e; e=$(shell_log_errors) && pass "no errors in shell log" || fail "shell log errors: $e"
}
run_test "themes" t_themes; run_test "perf" t_perf; run_test "health" t_health
bin/hush theme harbor >/dev/null
finish

#!/usr/bin/env bash
# Live-activity services (timer, recording, privacy, charging) in a windowless qs instance.
source "$(dirname "$0")/lib.sh"
T=$(mktemp -d); LOG=$T/log; TJ="${XDG_CACHE_HOME:-$HOME/.cache}/hush/timer.json"
cp "$TJ" "$T/timer.bak" 2>/dev/null
mkdir -p "$T/cfg"; cp "$HUSH_ROOT/tests/harness/activity.qml" "$T/cfg/shell.qml"
ln -s "$HUSH_ROOT/quickshell/hush/services" "$T/cfg/services"; ln -s "$HUSH_ROOT/quickshell/hush/config" "$T/cfg/config"
QS=(qs -p "$T/cfg/shell.qml")
SLEEPER=
cleanup() { [[ -n $SLEEPER ]] && kill "$SLEEPER" 2>/dev/null; session_pkill -f "qs -p $T/cfg" 2>/dev/null
  if [[ -f $T/timer.bak ]]; then cp "$T/timer.bak" "$TJ"; else rm -f "$TJ"; fi; rm -rf "$T"; }
trap cleanup EXIT
start() { "${QS[@]}" >"$LOG" 2>&1 & for _ in $(seq 40); do "${QS[@]}" ipc call activity timerRemaining >/dev/null 2>&1 && return; sleep 0.25; done; }
a() { "${QS[@]}" ipc call activity "$@"; }
t_timer() {
  start
  a timerStart 60 >/dev/null; sleep 1.2
  local r; r=$(a timerRemaining)
  [[ $r -ge 57 && $r -le 59 ]] && pass "timer remaining counts down ($r)" || fail "timer remaining ($r)"
  assert_file "$TJ" "timer persisted to timer.json"
  session_pkill -f "qs -p $T/cfg"; sleep 0.5; start
  r=$(a timerRemaining)
  [[ $r -ge 55 && $r -le 59 ]] && pass "timer survives a restart ($r)" || fail "timer after restart ($r)"
  a timerStop >/dev/null; sleep 0.3
  assert_eq "0" "$(a timerRemaining)" "stop zeroes remaining"
  assert_eq "{}" "$(cat "$TJ")" "stop clears the file"
}
t_recording() {
  assert_eq "false" "$(a recording)" "recording false at rest"
  if ! command -v pgrep >/dev/null; then pass "skipped: no pgrep"; return; fi
  # pgrep -x matches the process name (comm), which `exec -a` does not change: run a copy named wf-recorder.
  cp "$(command -v sleep)" "$T/wf-recorder"; "$T/wf-recorder" 30 & SLEEPER=$!
  local v=false; for _ in $(seq 12); do v=$(a recording); [[ $v == true ]] && break; sleep 0.5; done
  assert_eq "true" "$v" "recording true while a wf-recorder process runs"
  kill $SLEEPER; SLEEPER=; v=true; for _ in $(seq 12); do v=$(a recording); [[ $v == false ]] && break; sleep 0.5; done
  assert_eq "false" "$v" "recording false after it exits"
}
t_booleans() {
  local f; for f in micInUse cameraInUse justPlugged; do
    case "$(a $f)" in true|false) pass "$f is a boolean";; *) fail "$f not boolean";; esac
  done
}
t_log() { local e; e=$(grep -E 'ERROR|WARN' "$LOG" | grep -v "Failed to create.*display\|No platform" | head -3); [[ -z $e ]] && pass "no errors in harness log" || fail "log: $e"; }
run_test "timer" t_timer; run_test "recording" t_recording; run_test "privacy and charging" t_booleans; run_test "log" t_log
finish

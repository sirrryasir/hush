#!/usr/bin/env bash
# Live activities at rest, in a harness window (never touches the live shell).
source "$(dirname "$0")/lib.sh"
cd "$HUSH_ROOT"
EV="$HOME/.cache/hush/evidence"; mkdir -p "$EV"
QS=(qs -p tests/harness/activity_ui.qml)
LOG=$(mktemp)
cleanup() { session_pkill -f "qs -p tests/harness/activity_ui.qml" 2>/dev/null; rm -f "$LOG"; }
trap cleanup EXIT
h() { "${QS[@]}" ipc call activityui "$@"; }
shot() { # name: grim the harness layer
  local g; g=$(hyprctl layers -j | jq -r '[.. | objects | select((.namespace? // "") == "hush-harness-activity")][0] | "\(.x),\(.y) \(.w)x\(.h)"')
  sleep 0.6; grim -g "$g" "$EV/activity-$1.png" 2>/dev/null && assert_file "$EV/activity-$1.png" "screenshot activity-$1"
}
# set rec timer secs media mic cam plugged
t_activity_ui() {
  "${QS[@]}" >"$LOG" 2>&1 &
  for _ in $(seq 40); do h mode >/dev/null 2>&1 && break; sleep 0.25; done
  h set false false 0 false false false false >/dev/null; sleep 0.3
  assert_eq "false" "$(h shown)" "idle: slot hidden"
  h set false false 0 true false false false >/dev/null; sleep 0.3
  assert_eq "media" "$(h mode | tr -d '"')" "media only: media"; shot media
  h set false true 754 true false false false >/dev/null; sleep 0.3
  assert_eq "timer" "$(h mode | tr -d '"')" "timer beats media"
  assert_eq "12:34" "$(h timeText | tr -d '"')" "timer shows mm:ss"; shot timer
  h set true true 754 true false false false >/dev/null; sleep 0.3
  assert_eq "recording" "$(h mode | tr -d '"')" "recording beats timer and media"; shot recording
  h set true false 0 false false false false >/dev/null; sleep 0.3
  assert_eq "recording" "$(h mode | tr -d '"')" "recording alone"
  local w1 w2; w1=$(h width); h set false true 5 false false false false >/dev/null; sleep 0.3; w2=$(h width)
  [[ "$w2" -gt 24 ]] && pass "timer slot widens for mm:ss (${w2}px)" || fail "timer slot width ($w2)"
  assert_eq "00:05" "$(h timeText | tr -d '"')" "zero padded"
  h set false false 0 false true false false >/dev/null; sleep 0.3
  assert_eq "mic" "$(h glyph | tr -d '"')" "mic glyph"; shot mic
  h set false false 0 false true true false >/dev/null; sleep 0.3
  assert_eq "videocam" "$(h glyph | tr -d '"')" "camera beats mic"; shot camera
  h set false false 0 false false false true >/dev/null; sleep 0.8
  assert_eq "bolt" "$(h glyph | tr -d '"')" "charging bolt kept"; shot plugged
  local e; e=$(grep -E 'WARN|ERROR|TypeError|ReferenceError' "$LOG" | grep -v 'Implicitly' || true)
  [[ -z "$e" ]] && pass "no harness log errors" || fail "harness log: $e"
}
run_test "activity_ui" t_activity_ui
finish

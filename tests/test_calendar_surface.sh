#!/usr/bin/env bash
# Calendar surface in its own scratch Quickshell window (never touches the live shell).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H="tests/harness/calendar.qml"
hq() { qs -p "$H" ipc call harness-calendar "$@" 2>/dev/null; }
t_calendar() {
  qs -p "$H" >/dev/null 2>&1 & local pid=$!
  local up=0; for _ in $(seq 20); do sleep 0.3; [[ -n "$(hq todayText)" ]] && { up=1; break; }; done
  [[ $up == 1 ]] && pass "harness starts" || { fail "harness did not start"; kill "$pid" 2>/dev/null; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-calendar"' && pass "layer hush-harness-calendar present" || fail "layer missing"
  assert_eq "$(date +%-d)" "$(hq todayText)" "today's day number rendered in the grid"
  assert_eq "360x336" "$(hq size)" "declared size 360x336"
  assert_eq "$(LC_ALL=C date '+%B %Y')" "$(hq monthTitle)" "month title"
  hq next >/dev/null; sleep 0.2
  assert_eq "$(LC_ALL=C date -d "$(date +%Y-%m-01) +1 month" '+%B %Y')" "$(hq monthTitle)" "next month navigates"
  hq prev >/dev/null; sleep 0.2
  assert_eq "$(LC_ALL=C date '+%B %Y')" "$(hq monthTitle)" "prev month returns"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
}
run_test "calendar surface" t_calendar
finish

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
  # Hijri caption flips the grid to Hijri months and back.
  hq hijri true >/dev/null; sleep 0.6
  [[ "$(hq caption)" =~ (Muharram|Safar|Rabi|Jumada|Rajab|Sha\'ban|Ramadan|Shawwal|Dhu).*\ 14[0-9][0-9]$ ]] && pass "caption names the Hijri months" || fail "caption: '$(hq caption)'"
  hq toggleHijri >/dev/null; sleep 0.3
  [[ "$(hq monthTitle)" =~ ^(Muharram|Safar|Rabi|Jumada|Rajab|Sha\'ban|Ramadan|Shawwal|Dhu).*\ 14[0-9][0-9]$ ]] && pass "toggle shows a Hijri month title ($(hq monthTitle))" || fail "Hijri title: '$(hq monthTitle)'"
  [[ "$(hq caption)" == *"$(date +%Y)"* ]] && pass "Hijri view caption names the Gregorian months" || fail "caption: '$(hq caption)'"
  local h1; h1=$(hq monthTitle); hq next >/dev/null; sleep 0.2
  [[ "$(hq monthTitle)" != "$h1" ]] && pass "next moves one Hijri month" || fail "next stayed on '$h1'"
  hq prev >/dev/null; hq toggleHijri >/dev/null; sleep 0.3
  assert_eq "$(LC_ALL=C date '+%B %Y')" "$(hq monthTitle)" "toggle back returns to this Gregorian month"
  hq hijri false >/dev/null; sleep 0.3
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
}
run_test "calendar surface" t_calendar
finish

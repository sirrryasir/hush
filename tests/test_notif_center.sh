#!/usr/bin/env bash
# Notification center surface in its own scratch Quickshell window (fake host: never owns the server).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H="tests/harness/notifs.qml"
hq() { qs -p "$H" ipc call harness-notifs "$@" 2>/dev/null; }
t_notif_center() {
  qs -p "$H" >/dev/null 2>&1 & local pid=$!
  local up=0; for _ in $(seq 20); do sleep 0.3; [[ -n "$(hq count)" ]] && { up=1; break; }; done
  [[ $up == 1 ]] && pass "harness starts" || { fail "harness did not start"; kill "$pid" 2>/dev/null; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-notifs"' && pass "layer hush-harness-notifs present" || fail "layer missing"
  assert_eq "480x260" "$(hq size)" "declared size 480x260"
  assert_eq "3" "$(hq count)" "3 fake notifications"
  assert_eq "2" "$(hq groupCount)" "grouped into 2 apps"
  hq toggleDnd >/dev/null; sleep 0.1
  assert_eq "true" "$(hq dnd)" "DND toggles"
  hq clearAll >/dev/null; sleep 0.2
  assert_eq "0" "$(hq groupCount)" "clear all leaves 0 groups"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
}
run_test "notification center surface" t_notif_center
finish

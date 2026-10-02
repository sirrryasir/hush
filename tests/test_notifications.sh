#!/usr/bin/env bash
# Live test of the hush notification daemon, island notification state, and drawer.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
notif_ipc() { qs -c hush ipc call notifs "$@"; }
# Integer reply or the fallback, so a missing IPC target fails the assertion instead of bash.
int_or() { [[ $1 =~ ^[0-9]+$ ]] && echo "$1" || echo "$2"; }
t_daemon() {
  pkill -x swaync 2>/dev/null; sleep 0.3
  shell_restart; sleep 3
  local owner; owner=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | awk -F= '/^Comm=/{print $2}')
  assert_eq "qs" "$owner" "hush owns org.freedesktop.Notifications"
  shell_ipc clearNotifications >/dev/null
}
t_single() {
  notify-send -a hushtest "Hello" "one line"; sleep 0.5
  assert_eq "notification" "$(shell_ipc islandState)" "a notification shows on the island"
  assert_eq "36" "$(notif_ipc islandHeight)" "one-line body keeps the island at 36"
  [[ -n "${HUSH_SHOT:-}" ]] && shell_screenshot "${HUSH_SHOT}-notification"
  sleep 6
  assert_eq "rest" "$(shell_ipc islandState)" "island returns to rest after the hold"
}
t_storm() {
  shell_ipc clearNotifications >/dev/null
  for i in $(seq 1 30); do notify-send -a storm "n$i" "body $i"; done
  assert_eq "notification" "$(shell_ipc islandState)" "storm shows a notification"
  local max=0 h w maxw=0
  for _ in 1 2 3 4 5; do
    h=$(int_or "$(notif_ipc islandHeight)" 999); w=$(int_or "$(notif_ipc islandWidth)" 999)
    (( h > max )) && max=$h; (( w > maxw )) && maxw=$w
    sleep 0.6
  done
  (( max <= 56 )) && pass "island height stays within 56 (max $max)" || fail "island grew to $max"
  (( maxw <= 520 )) && pass "island width stays within 520 (max $maxw)" || fail "island width grew to $maxw"
  local q; q=$(int_or "$(notif_ipc queued)" 0)
  (( q >= 20 )) && pass "storm is queued, one at a time ($q waiting)" || fail "queue holds only $q"
  local u; u=$(int_or "$(shell_ipc unread)" 0)
  (( u >= 30 )) && pass "unread counts the storm ($u)" || fail "unread is $u"
  local c; c=$(int_or "$(notif_ipc count)" 0)
  (( c >= 30 )) && pass "all storm notifications land in the drawer list ($c)" || fail "drawer list has $c"
}
t_drawer() {
  shell_ipc toggleDrawer; sleep 0.5
  shell_has_layer hush-drawer && pass "drawer layer is mapped" || fail "no hush-drawer layer"
  assert_eq "0" "$(shell_ipc unread)" "opening the drawer marks all seen"
  [[ -n "${HUSH_SHOT:-}" ]] && shell_screenshot "${HUSH_SHOT}-drawer"
  shell_ipc clearNotifications; sleep 0.5
  assert_eq "0" "$(notif_ipc count)" "clear all empties the list"
  assert_eq "0" "$(shell_ipc unread)" "unread is 0 after clear"
  assert_eq "rest" "$(shell_ipc islandState)" "clear all returns the island to rest"
  shell_ipc toggleDrawer; sleep 0.6
  shell_has_layer hush-drawer && fail "drawer still mapped after toggle" || pass "drawer hides again"
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "daemon" t_daemon; run_test "single" t_single; run_test "storm" t_storm
run_test "drawer" t_drawer; run_test "log" t_log
finish

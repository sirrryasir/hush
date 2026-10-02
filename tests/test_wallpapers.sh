#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
MOSS="$HUSH_ROOT/themes/moss/wallpaper.png"
t_open() {
  shell_restart; sleep 2
  shell_ipc toggleWallpapers; sleep 1
  shell_has_layer hush-wallpapers && pass "layer hush-wallpapers present" || fail "layer missing"
  assert_eq "true" "$(shell_ipc wallpapersVisible)" "wallpapersVisible true"
  local n; n=$(shell_ipc wallpapersCount)
  [[ "$n" -ge 6 ]] && pass "wallpapersCount $n >= 6" || fail "wallpapersCount $n"
}
t_select() {
  shell_ipc wallpapersSelect "$MOSS"; sleep 5
  for _ in 1 2 3 4 5 6 7 8; do bin/hush status | grep -q "^wallpaper $MOSS" && break; sleep 2; done
  assert_eq "false" "$(shell_ipc wallpapersVisible)" "select hides the grid"
  bin/hush status | grep -q "^wallpaper $MOSS" && pass "status shows moss wallpaper" || fail "wallpaper not applied"
  bin/hush theme harbor >/dev/null 2>&1; sleep 3
  bin/hush status | grep -q '^theme harbor' && pass "harbor restored" || fail "harbor not restored"
}
t_close() {
  shell_ipc toggleWallpapers; sleep 0.5
  assert_eq "true" "$(shell_ipc wallpapersVisible)" "reopens"
  shell_ipc toggleWallpapers; sleep 0.5
  assert_eq "false" "$(shell_ipc wallpapersVisible)" "toggle closes"
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "open" t_open
run_test "select" t_select
run_test "close" t_close
run_test "log" t_log
finish

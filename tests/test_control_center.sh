#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
ORIG_THEME=$(bin/hush status | awk 'NR==1{print $2}')
restore_theme() { [[ -n "$ORIG_THEME" ]] && bin/hush theme "$ORIG_THEME" >/dev/null 2>&1; }
trap restore_theme EXIT
t_open() {
  shell_restart; sleep 3
  shell_ipc toggleControlCenter >/dev/null; sleep 1.5
  assert_eq "expanded" "$(shell_ipc islandState)" "toggle opens the control center"
  assert_eq "560x320" "$(shell_ipc islandSize)" "expanded size"
  assert_eq "6" "$(shell_ipc ccThemeCount)" "six themes listed"
  [[ -n "${HUSH_SHOT:-}" ]] && shell_screenshot "$HUSH_SHOT"
  shell_screenshot taskB7-cc-dark
}
t_theme() {
  shell_ipc ccSetTheme dusk >/dev/null; sleep 4
  assert_contains <(bin/hush status | head -1) "theme dusk" "theme switched to dusk"
  assert_eq "expanded" "$(shell_ipc islandState)" "still expanded after theme switch"
  shell_ipc ccSetTheme paper >/dev/null; sleep 4
  assert_contains <(bin/hush status | head -1) "theme paper" "theme switched to paper"
  assert_eq "expanded" "$(shell_ipc islandState)" "still expanded on light theme"
  shell_screenshot taskB7-cc-light
  shell_ipc ccSetTheme harbor >/dev/null; sleep 4
  assert_contains <(bin/hush status | head -1) "theme harbor" "back to harbor"
}
t_close() {
  shell_ipc toggleControlCenter >/dev/null; sleep 1
  assert_eq "rest" "$(shell_ipc islandState)" "toggle closes"
  local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"
}
run_test "open" t_open; run_test "theme" t_theme; run_test "close" t_close
finish

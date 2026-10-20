#!/usr/bin/env bash
# Reminders: added through the shell's IPC a few seconds ahead; the calendar dot and list row, the rest
# pill text and the notification when it falls due. The user's reminders.json is kept.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
EVI="${HUSH_EVIDENCE_DIR:-$HOME/.cache/hush/evidence}"; mkdir -p "$EVI"
RJ="$HOME/.config/hush/reminders.json"; BAK=$(mktemp); HAD=1; cp "$RJ" "$BAK" 2>/dev/null && HAD=0
r() { qs -c hush ipc call reminders "$@"; }
cleanup() { shell_ipc closeSurface >/dev/null 2>&1; shell_ipc clearNotifications >/dev/null 2>&1
  if [[ $HAD == 0 ]]; then cp "$BAK" "$RJ"; else rm -f "$RJ"; fi; rm -f "$BAK"; }
trap cleanup EXIT

t_due() {
  shell_restart; sleep 3; r clear >/dev/null; shell_ipc clearNotifications >/dev/null
  assert_eq "true" "$(r add 6 standup)" "a reminder 6 s ahead is accepted"
  assert_eq "false" "$(r add -5 late)" "a time in the past is refused"
  assert_eq "1" "$(r count)" "one reminder kept"
  assert_file "$RJ" "reminders.json written"
  sleep 7
  shell_wait_state notification 40 && pass "due: the island raises a notification" || fail "no notification (state $(shell_state))"
  assert_eq "standup" "$(qs -c hush ipc call notifs current | tr -d '"')" "the notification carries the text"
  assert_eq "0" "$(r count)" "a fired reminder is dropped"
  shell_ipc clearNotifications >/dev/null
}
run_test "due" t_due
finish

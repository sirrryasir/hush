#!/usr/bin/env bash
# Reminders: added through the shell's IPC a few seconds ahead; the calendar dot and list row, the rest
# pill text and the notification when it falls due. The user's reminders.json is kept.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
EVI="${HUSH_EVIDENCE_DIR:-$HOME/.cache/hush/evidence}"; mkdir -p "$EVI"
SHOTS="${HUSH_SHOTS:-$EVI}"; mkdir -p "$SHOTS"
RJ="$HOME/.config/hush/reminders.json"; BAK=$(mktemp); HAD=1; cp "$RJ" "$BAK" 2>/dev/null && HAD=0
r() { qs -c hush ipc call reminders "$@"; }
vis() { shell_ipc islandControlVisible "$1"; }
read -r MX MY MW MH < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']))")
shot() { sleep 0.8; grim -g "$((MX + MW / 2 - 300)),$MY 600x$1" "$SHOTS/$2.png" 2>/dev/null; assert_file "$SHOTS/$2.png" "screenshot $2"; }
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
t_calendar() {
  r clear >/dev/null; shell_ipc openSurface calendar; shell_wait_state calendar
  assert_eq "false" "$(vis reminderDot)" "no dot without reminders"
  assert_eq "false" "$(vis reminderRow)" "no list row without reminders"
  r add 600 "Standup" >/dev/null; sleep 0.5
  assert_eq "true" "$(vis reminderDot)" "a day with a reminder shows a dot"
  assert_eq "true" "$(vis reminderRow)" "the selected day lists it"
  shot 336 reminders-page
  if input_start; then
    local pos; pos=$(shell_ipc islandControl reminderRemove)
    input_move $((MX + ${pos% *})) $((MY + ${pos#* })); sleep 0.6; input_click; sleep 0.4
    assert_eq "0" "$(r count)" "remove deletes the reminder"
    assert_eq "false" "$(vis reminderDot)" "the dot goes with it"
    input_move $((MX + 50)) $((MY + MH - 50)); input_stop
  else pass "$(input_why): remove click skipped"; fi
  shell_ipc closeSurface >/dev/null; shell_wait_state rest
}
t_pill() {
  r clear >/dev/null; sleep 0.5
  assert_eq '' "$(r pillLabel)" "no reminder: the pill shows no reminder text"
  r add 720 Standup >/dev/null; sleep 1.5
  assert_eq 'Standup in 12 min' "$(r pill)" "the next reminder within the hour reads Standup in 12 min"
  assert_eq 'Standup in 12 min' "$(r pillLabel)" "the rest pill shows it"
  shot 80 reminders-pill
  r clear >/dev/null; r add 7200 Later >/dev/null; sleep 1.5
  assert_eq '' "$(r pillLabel)" "a reminder two hours out stays off the pill"
  r clear >/dev/null
}
run_test "due" t_due
run_test "calendar" t_calendar
run_test "pill" t_pill
finish

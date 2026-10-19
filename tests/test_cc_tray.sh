#!/usr/bin/env bash
# Tray in the control center (cc harness): the header button is absent without items and counts them
# once tests/fakesni.py registers a StatusNotifierItem; the tray page lists it, a tap activates it,
# the menu lists the item's DBusMenu entries and an entry triggers. Saves the page to $HUSH_SHOTS
# (default ../cc-shots next to the checkout). Without dbus-python and PyGObject only the
# hidden button is checked.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
LOG=$(mktemp); FLOG=$(mktemp); FPID=""
"${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID $FPID 2>/dev/null; rm -f "$LOG" "$FLOG"' EXIT
shot() {
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
for o in json.load(sys.stdin).values():
  for lv in o['levels'].values():
    for l in lv:
      if l['namespace']=='hush-harness-cc': print('%d,%d %dx%d' % (l['x'],l['y'],l['w'],l['h']))")
  [[ -n "$g" ]] && grim -g "$g" "$SHOTS/$1.png" 2>/dev/null
  assert_file "$SHOTS/$1.png" "saved $SHOTS/$1.png"
}
wait_eq() { local want=$1 i out; shift; for i in $(seq 30); do out=$("$@"); [[ "$out" == "$want" ]] && break; sleep 0.3; done; echo "$out"; }
t_up() {
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  assert_eq "main" "$(cc page)" "harness starts on the main page"
  assert_eq "0" "$(cc trayCount)" "no tray items in the sandbox"
  assert_eq "false" "$(cc trayButtonVisible)" "tray button hidden without items"
}
t_tray() {
  python3 -c 'import dbus, gi' 2>/dev/null || { pass "no dbus-python/PyGObject: tray item checks skipped"; return; }
  HUSH_FAKE_LOG="$FLOG" python3 tests/fakesni.py & FPID=$!
  assert_eq "1" "$(wait_eq 1 cc trayCount)" "the fake item registers with the shell's watcher"
  assert_eq "true" "$(cc trayButtonVisible)" "tray button shown with an item"
  cc openTray >/dev/null; sleep 0.5
  assert_eq "tray" "$(cc page)" "button opens the tray page"
  assert_eq "1" "$(cc rowCount trayPage)" "one row per item"
  shot tray-page
  cc trayTap "Fake Tray App" false >/dev/null
  local i; for i in $(seq 20); do grep -qx activate "$FLOG" && break; sleep 0.2; done
  grep -qx activate "$FLOG" && pass "tap calls Activate on the item" || fail "no Activate: $(cat "$FLOG")"
  cc trayTap "Fake Tray App" true >/dev/null
  assert_eq "true" "$(wait_eq true cc trayMenuOpen)" "right click opens the item's menu"
  assert_eq "2" "$(wait_eq 2 cc rowCount trayPage)" "menu entries listed as rows"
  shot tray-menu
  cc trayTap Quit false >/dev/null
  for i in $(seq 20); do grep -q "menu 2 clicked" "$FLOG" && break; sleep 0.2; done
  grep -q "menu 2 clicked" "$FLOG" && pass "an entry row triggers it" || fail "no menu event: $(cat "$FLOG")"
  assert_eq "false" "$(cc trayMenuOpen)" "the menu closes after an entry"
  assert_eq "true" "$(cc back)" "back leaves the tray page"; assert_eq "main" "$(cc page)" "back lands on main"
  kill $FPID; wait $FPID 2>/dev/null; FPID=""
  assert_eq "0" "$(wait_eq 0 cc trayCount)" "the item leaves when its app exits"
  assert_eq "false" "$(cc trayButtonVisible)" "tray button hidden again"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test up t_up; run_test tray t_tray; run_test log t_log
finish

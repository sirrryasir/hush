#!/usr/bin/env bash
# Power-profile page of the control center in the cc harness (tests/harness/cc.qml) with a fake
# powerprofilesctl on PATH: a fixed list, `get` and `set` through a state file. Saves a PNG of the page
# to $HUSH_SHOTS (default ../cc-shots next to the checkout).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
STUB=$(mktemp -d); echo balanced >"$STUB/state"
cat >"$STUB/powerprofilesctl" <<EOF
#!/bin/sh
case "\$1" in
  get) cat "$STUB/state" ;;
  set) echo "\$2" >"$STUB/state" ;;
  list) for p in performance balanced power-saver; do
          [ "\$p" = "\$(cat "$STUB/state")" ] && m='*' || m=' '
          printf '%s %s:\n    Driver:     fake\n\n' "\$m" "\$p"
        done ;;
esac
EOF
chmod +x "$STUB/powerprofilesctl"
LOG=$(mktemp); PATH="$STUB:$PATH" HUSH_BT_NO_ADAPTER=1 "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
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
wait_for() { local i; for i in $(seq 25); do eval "$1" && return 0; sleep 0.3; done; return 1; }
t_up() {
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  assert_eq "main" "$(cc page)" "harness starts on the main page"
}
# The page lists the three profiles with the current one marked.
t_rows() {
  cc openPower >/dev/null; assert_eq "power" "$(cc page)" "openPower opens the page"
  wait_for '[[ "$(cc rowCount powerPage)" == 3 ]]' || fail "profiles: $(cc rowCount powerPage)"
  sleep 0.5
  assert_eq "true" "$(cc rowActive powerPage balanced)" "balanced is marked from get"
  assert_eq "false" "$(cc rowActive powerPage performance)" "performance is not"
  shot power
}
# Tap selects through powerprofilesctl set; the mark follows; power-saver names itself on the chip.
t_select() {
  cc press powerPage power-saver "" >/dev/null
  wait_for '[[ "$(cat "$STUB/state")" == power-saver ]]'
  assert_eq "power-saver" "$(cat "$STUB/state")" "tap runs powerprofilesctl set"
  wait_for '[[ "$(cc powerChip)" == true* ]]'
  assert_eq "true" "$(cc rowActive powerPage power-saver)" "the mark follows"
  assert_contains <(cc powerChip) "true|" "chip knows power-saver is active"
  assert_contains <(cc powerChip) "power-saver|true" "chip shows the name in the muted role"
  cc press powerPage balanced "" >/dev/null
  wait_for '[[ "$(cc powerChip)" == false* ]]'
  assert_contains <(cc powerChip) "false|" "leaving power-saver clears the chip"
  assert_eq "true" "$(cc back)" "back leaves the page"; assert_eq "main" "$(cc page)" "back lands on main"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test up t_up; run_test rows t_rows; run_test select t_select; run_test log t_log
finish

#!/usr/bin/env bash
# Quickshell lock (quickshell/hush/lock.qml, lockscreen/Screen.qml) in a nested Hyprland with one
# headless 1920x1080 output: idle shows no pill; a key and four characters show the 340 px black pill;
# Return with HUSH_LOCK_TEST=fail turns the hairline and the status line red; HUSH_LOCK_TEST=ok
# unlocks and the process exits. PAM is never asked, and the live session is never locked.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/nested.sh"
cd "$(dirname "$0")/.."
EVID="$HOME/.cache/hush/evidence"
R=$(mktemp -d)
trap 'session_pkill -f "quickshell/hush/lock.qml" 2>/dev/null; nested_stop 2>/dev/null; rm -rf "$R"' EXIT
LOCK=quickshell/hush/lock.qml

t_static() {
  [[ "$(readlink -f quickshell/hush/lock/Screen.qml)" == "$PWD/lockscreen/Screen.qml" ]] && pass "lock/Screen.qml links to lockscreen/Screen.qml" || fail "lock/Screen.qml is not the shared screen"
  assert_contains $LOCK 'WlSessionLock' "session lock protocol"
  assert_contains $LOCK 'config: "login"' "password through PAM login"
  assert_contains lockscreen/pam/fprint 'pam_fprintd.so' "fingerprint PAM file"
  assert_contains bin/hush 'quickshell/hush/lock.qml' "hush lock runs the Quickshell lock"
  assert_contains bin/hush 'exec hyprlock' "hush lock --hyprlock keeps the fallback"
}

frame() { nest grim -t ppm -o SHOT "$R/$1.ppm"; }
evidence() { local f; for f in "$@"; do python3 -c "from PIL import Image; Image.open('$R/$f.ppm').save('$EVID/lock-qs-$f.png')"; done; }
lock_alive() { session_pgrep -f "$PWD/$LOCK" >/dev/null; }
start_lock() { # fail|ok
  (nest env HUSH_LOCK_TEST="$1" hush lock >"$R/lock-$1.log" 2>&1 &)
  local i; for ((i = 0; i < 50; i++)); do lock_alive && break; sleep 0.1; done
  sleep 2.5
}

t_nested() {
  command -v Hyprland >/dev/null && command -v grim >/dev/null && command -v wtype >/dev/null && command -v qs >/dev/null \
    || { pass "no Hyprland/grim/wtype/qs (skipped)"; return; }
  mkdir -p "$EVID"
  nested_start "$R/nest" SHOT:1920x1080 || { fail "nested Hyprland"; return; }
  nest hyprctl eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' >/dev/null; sleep 0.5
  nest hyprctl dispatch 'hl.dsp.cursor.move({ x = 20, y = 20 })' >/dev/null 2>&1
  local w r g b edge got want i err
  err=$(python3 -c "import json; print(json.load(open('$CFG/hush/Colors.json')).get('dark', {}).get('error', '#ffb4ab').lstrip('#'))" 2>/dev/null)
  start_lock fail
  lock_alive && pass "lock process up" || { fail "lock did not start: $(tail -3 "$R/lock-fail.log")"; return; }
  frame idle
  read -r w r g b < <(tests/lockshot.py pill "$R/idle.ppm")
  [[ "$r$g$b" != 000 ]] && pass "idle: no pill before a key" || fail "idle: pill shown before a key"
  read -r got want < <(tests/lockshot.py clock "$R/idle.ppm" ffffff)
  python3 -c "import sys; sys.exit(0 if abs($got-$want) <= 4 else 1)" 2>/dev/null \
    && pass "idle: clock centre y $got (spec $want)" || fail "idle: clock centre y $got (spec $want)"

  nest wtype 'abcd'; sleep 0.6
  frame typing
  read -r w r g b < <(tests/lockshot.py pill "$R/typing.ppm")
  [[ "$r$g$b" == 000 ]] && pass "typing: the black pill" || fail "typing: pill pixel $r,$g,$b"
  (( w >= 332 && w <= 348 )) && pass "typing: pill ${w} px wide (spec 340)" || fail "typing: pill ${w} px (spec 340)"
  (( $(tests/lockshot.py inside "$R/typing.ppm") > 150 )) && pass "typing: dots shown" || fail "typing: no dots"

  nest wtype -k Return
  for ((i = 0; i < 40; i++)); do
    frame error; edge=$(tests/lockshot.py edge "$R/error.ppm")
    python3 -c "import sys; a,b='$edge','$err'; sys.exit(0 if sum(abs(int(a[j:j+2],16)-int(b[j:j+2],16)) for j in (0,2,4)) <= 40 else 1)" 2>/dev/null && break
    sleep 0.1
  done
  [[ $i -lt 40 ]] && pass "wrong password: red hairline (#$edge)" || fail "hairline never turned #$err (#$edge)"
  (( $(tests/lockshot.py status "$R/error.ppm" "$err") > 20 )) && pass "wrong password: status line in the error colour" || fail "no red status line"
  lock_alive && pass "still locked after a wrong password" || fail "lock exited after a wrong password"

  session_pkill -f "$PWD/$LOCK"; sleep 0.5
  nest hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1; sleep 1
  start_lock ok
  nest wtype 'abcd'; sleep 0.3; nest wtype -k Return
  for ((i = 0; i < 40; i++)); do lock_alive || break; sleep 0.1; done
  ! lock_alive && pass "right password: the lock process exits" || fail "lock still running after a right password"
  sleep 0.3; frame unlocked
  (( $(tests/lockshot.py inside "$R/unlocked.ppm") < 60 && $(tests/lockshot.py status "$R/unlocked.ppm" ffffff) < 5 )) \
    && pass "unlocked: no lock screen and no crash notice" || fail "something still drawn after unlock"
  nested_stop
  evidence idle typing error
}

run_test "static" t_static
run_test "nested lock" t_nested
finish

#!/usr/bin/env bash
# Launcher surface in its own scratch Quickshell window (never touches the live shell).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H="tests/harness/launcher.qml"
hq() { qs -p "$H" ipc call harness-launcher "$@" 2>/dev/null; }
t_launcher() {
  qs -p "$H" >/tmp/hush-harness-launcher.$$.log 2>&1 & local pid=$!
  local up=0; for _ in $(seq 20); do sleep 0.3; [[ -n "$(hq size)" ]] && { up=1; break; }; done
  [[ $up == 1 ]] && pass "harness starts" || { fail "harness did not start"; kill "$pid" 2>/dev/null; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-launcher"' && pass "layer hush-harness-launcher present" || fail "layer missing"
  assert_eq "520x300" "$(hq size)" "declared size 520x300"
  assert_eq "true" "$(hq wantsKeyboard)" "wantsKeyboard"
  hq setQuery kitty >/dev/null; sleep 0.5
  hq first | grep -qi kitty && pass "kitty query: first result is $(hq first)" || fail "first result: $(hq first)"
  hq setQuery "=2*21" >/dev/null; sleep 1
  assert_eq "calc" "$(hq mode)" "= switches to calc mode"
  assert_eq "42" "$(hq first)" "=2*21 gives 42"
  hq setQuery ";" >/dev/null; sleep 0.8
  local n; n=$(hq count)
  [[ "$n" =~ ^[0-9]+$ ]] && pass "clip mode lists $n entries" || fail "clip mode count: '$n'"
  assert_eq "clip" "$(hq mode)" "; switches to clip mode"
  grep -qiE "error|binding loop" /tmp/hush-harness-launcher.$$.log && fail "harness log errors: $(grep -iE 'error|binding loop' /tmp/hush-harness-launcher.$$.log | head -3)" || pass "no errors in harness log"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rm -f /tmp/hush-harness-launcher.$$.log
}
run_test "launcher surface" t_launcher
finish

#!/usr/bin/env bash
# Offline WCAG gate over the island's role pairs for all six themes. Generates each palette with matugen
# into a scratch dir (never ~/.config, never the live session) and prints the theme x pair table.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_gate() {
  local out="${TMPDIR:-/tmp}/island-contrast.txt" err
  if python3 tests/contrast.py --island-gate >"$out" 2>"$out.err"; then pass "$(cat "$out.err")"
  else grep FAIL "$out"; fail "$(cat "$out.err")"; fi
}
run_test "island contrast gate (six themes)" t_gate
finish

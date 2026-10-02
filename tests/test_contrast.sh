#!/usr/bin/env bash
# WCAG contrast audit across all six themes. Leaves the last theme applied: restores the original.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
orig=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.config/hush/state.json'))).get('theme','harbor'))" 2>/dev/null || echo harbor)
t_theme() {
  local t=$T
  hush theme "$t" >/dev/null 2>&1 || { fail "hush theme $t failed"; return; }
  sleep 0.3
  if python3 tests/contrast.py "$t" > "${TMPDIR:-/tmp}/contrast-$t.txt" 2>"${TMPDIR:-/tmp}/contrast-$t.err"; then
    pass "$t: $(cat "${TMPDIR:-/tmp}/contrast-$t.err")"
  else
    cat "${TMPDIR:-/tmp}/contrast-$t.txt" | grep FAIL; fail "$t: $(cat "${TMPDIR:-/tmp}/contrast-$t.err")"
  fi
}
for T in harbor ember moss dusk paper fog; do run_test "contrast $T" t_theme; done
t_wall_random() {
  hush theme harbor >/dev/null 2>&1; hush wall random >/dev/null 2>&1 || { fail "hush wall random failed"; return; }
  local w; w=$(hush status | awk '$1=="wallpaper"{print $2}')
  if python3 tests/contrast.py harbor --quiet --wall "$w" 2>"${TMPDIR:-/tmp}/contrast-wall.err"; then pass "wall random ($(basename "$(dirname "$w")")): $(cat "${TMPDIR:-/tmp}/contrast-wall.err")"
  else fail "wall random ($w): $(cat "${TMPDIR:-/tmp}/contrast-wall.err")"; fi
}
run_test "contrast wall random" t_wall_random
hush theme "$orig" >/dev/null 2>&1
finish

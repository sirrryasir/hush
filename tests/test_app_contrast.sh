#!/usr/bin/env bash
# App contrast gate: kitty, nvim, fastfetch, p10k, waybar, GTK, qt6ct, Kvantum, hyprlock, SDDM and
# Helium, rendered offline for all six themes (never touches ~/.config or the live theme).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_gate() {
  local out err; out=$(mktemp); err=$(mktemp)
  if python3 tests/contrast_apps.py >"$out" 2>"$err"; then pass "$(cat "$err")"
  else cat "$out"; fail "$(tail -1 "$err")"; fi
  rm -f "$out" "$err"
}
t_detects() { # the gate must fail on the old base16 nvim palette (near-background syntax colours)
  local R; R=$(mktemp -d)
  mkdir -p "$R/ember"
  python3 - "$R" <<'PY' || { fail "could not build the regression fixture"; rm -rf "$R"; return; }
import sys, tests.contrast_apps as A, shutil
out = A.render("ember"); shutil.copytree(out, sys.argv[1] + "/ember", dirs_exist_ok=True)
p = sys.argv[1] + "/ember/nvim/colors/hush.lua"
s = open(p).read().replace('hi("String", { fg = p.string })', 'hi("String", { fg = c.bg1 })')
open(p, "w").write(s)
PY
  if python3 tests/contrast_apps.py --outputs "$R" ember >/dev/null 2>&1; then fail "gate passed a String coloured like the background"
  else pass "gate fails a String coloured like the background"; fi
  rm -rf "$R"
}
run_test "app contrast gate (6 themes)" t_gate
run_test "gate catches unreadable syntax" t_detects
finish

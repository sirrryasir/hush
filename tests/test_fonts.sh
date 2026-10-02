#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
t_fonts() {
  fc-list : family | grep -q '^Inter' && pass "Inter installed" || fail "Inter missing"
  fc-list : family | grep -q 'Material Symbols Rounded' && pass "Material Symbols Rounded installed" || fail "Material Symbols Rounded missing"
  fc-list : family | grep -q 'JetBrainsMono Nerd Font' && pass "JetBrainsMono Nerd Font installed" || fail "JetBrainsMono NF missing"
}
run_test "fonts" t_fonts
finish

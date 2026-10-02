#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_sources() {
  assert_contains "$CFG/hypr/hyprlock.conf" 'hush/hyprlock-wall.conf' "hyprlock.conf sources the hush wallpaper file"
  grep -q 'wall.set' hyprlock/layouts/layout_default.conf && fail "layout still references wall.set" || pass "layout no longer uses wall.set"
  assert_contains hyprlock/layouts/layout_default.conf 'font_family = Inter' "layout uses Inter"
}
t_parse() {
  # hyprlock has no --check; verify every referenced variable is defined.
  local undefined; undefined=$(grep -oE '\$[A-Za-z_0-9]+' hyprlock/layouts/layout_default.conf | sort -u | while read -r v; do
    grep -qF "${v} =" hyprlock/colors.conf ~/.config/hush/hyprlock-wall.conf 2>/dev/null || echo "$v"; done)
  [[ -z "$undefined" ]] && pass "all layout variables defined" || fail "undefined: $undefined"
}
t_prefix() {
  # hyprlang substitutes variables by prefix, so no defined name may be a prefix of another.
  local clash; clash=$(cat hyprlock/hyprlock.conf hyprlock/colors.conf ~/.config/hush/hyprlock-wall.conf hyprlock/layouts/layout_default.conf \
    | grep -oE '^\s*\$[A-Za-z_0-9]+\s*=' | grep -oE '[A-Za-z_0-9]+' | sort -u | awk '{a[NR]=$0} END{for(i=1;i<=NR;i++)for(j=1;j<=NR;j++)if(i!=j && index(a[j],a[i])==1)print a[i]" prefixes "a[j]}')
  [[ -z "$clash" ]] && pass "no hyprlock variable is a prefix of another" || fail "prefix clashes: $clash"
  grep -qE '\$(primary|text|accent)_[0-9]' hyprlock/colors.conf && fail "legacy aliases still defined" || pass "legacy aliases removed"
}
t_no_literals() {
  grep -nE "#[0-9a-fA-F]{6}|rgba\([0-9]" hyprlock/layouts/layout_default.conf && fail "layout has hardcoded colors" || pass "layout has no hardcoded colors"
}
run_test "sources" t_sources
run_test "variables" t_parse
run_test "prefixes" t_prefix
run_test "no literals" t_no_literals
finish

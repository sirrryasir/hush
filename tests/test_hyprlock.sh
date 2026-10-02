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
  local undefined; undefined=$(grep -oE '\$[A-Za-z_0-9]+' hyprlock/layouts/layout_default.conf | grep -vxE '\$(HOME|FPRINTPROMPT)' | sort -u | while read -r v; do
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
t_render() {
  # Render the colours for harbor and paper into a scratch dir (never touches the live theme), then
  # check every variable the layout uses is defined and the layout has the Apple-style pieces.
  local R; R=$(mktemp -d); local t
  for t in harbor paper; do
    mkdir -p "$R/$t"; test_matugen_cfg "$R/$t" hyprlock > "$R/$t.toml"
    local mode scheme contrast
    mode=$(sed -n 's/^mode = "\(.*\)"/\1/p' themes/$t/theme.toml); scheme=$(sed -n 's/^scheme = "\(.*\)"/\1/p' themes/$t/theme.toml)
    contrast=$(sed -n 's/^contrast = //p' themes/$t/theme.toml)
    matugen image "themes/$t/wallpaper.png" -c "$R/$t.toml" -m "$mode" -t "$scheme" --contrast "${contrast:-0}" --source-color-index 0 -q >/dev/null 2>&1
    assert_file "$R/$t/hyprlock/colors.conf" "$t colours render"
    local v undefined=""
    for v in $(grep -oE '\$hush[A-Za-z0-9]+' hyprlock/layouts/layout_default.conf | sort -u); do
      grep -qE "^\\${v} = rgba\\([0-9a-f]{8}\\)" "$R/$t/hyprlock/colors.conf" || undefined="$undefined $v"; done
    [[ -z "$undefined" ]] && pass "$t: every colour variable defined" || fail "$t: undefined:$undefined"
  done
  rm -rf "$R"
}
t_apple() {
  local L=hyprlock/layouts/layout_default.conf
  assert_contains "$L" 'blur_passes = 2' "background blurred"
  assert_contains "$L" 'font_size = 96' "clock is 96"
  assert_contains "$L" 'rounding = -1' "round avatar and pill"
  assert_contains "$L" '$FPRINTPROMPT' "fingerprint hint"
  assert_contains "$L" 'media-line.sh' "media line"
  [[ -x hyprlock/media-line.sh ]] && pass "media-line.sh executable" || fail "media-line.sh not executable"
  assert_file assets/brand/social/avatar-256.png "default avatar present"
  hyprlock --help 2>&1 | grep -q -- '--config' && pass "hyprlock --help sane" || fail "hyprlock --help"
  hyprlock --help 2>&1 | grep -q -- '--grace' && pass "hyprlock supports --grace" || fail "hyprlock --grace"
}
run_test "sources" t_sources
run_test "variables" t_parse
run_test "prefixes" t_prefix
run_test "no literals" t_no_literals
run_test "render" t_render
run_test "apple" t_apple
finish

#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
THEME_BAK=$(mktemp)
cp "$CFG/hypr/modules/theme.lua" "$THEME_BAK"
trap 'cp -f "$THEME_BAK" "$CFG/hypr/modules/theme.lua"; rm -f "$THEME_BAK"' EXIT
t_no_hardcoded() {
  local hits; hits=$(grep -nE 'rgba\([0-9a-fA-F]{6,8}\)|0x[0-9a-fA-F]{6,8}' $CFG/hypr/modules/decorations.lua $CFG/hypr/modules/misc.lua | grep -v 'theme\.' || true)
  [[ -z "$hits" ]] && pass "no hardcoded colors in decorations/misc" || fail "hardcoded colors: $hits"
}
t_opaque() {
  local bad; bad=$(grep -nE 'opacity *= *"' $CFG/hypr/modules/windowrules.lua | grep -vE '"1\.0( override)? 1\.0( override)?"|"0\.86 0\.78"' || true)
  [[ -z "$bad" ]] && pass "every window opacity rule is 1.0 (kitty glass 0.86/0.78 excepted)" || fail "translucent window rules: $bad"
  [[ $(grep -c '"0\.86 0\.78"' $CFG/hypr/modules/windowrules.lua) -eq 1 ]] && grep -B2 '"0\.86 0\.78"' $CFG/hypr/modules/windowrules.lua | grep -q 'kitty' && pass "only kitty is translucent" || fail "glass opacity not limited to kitty"
}
t_reload() {
  hyprctl reload >/dev/null && pass "hyprctl reload ok" || fail "hyprctl reload failed"
  local errs; errs=$(hyprctl configerrors | grep -v '^$' || true)
  [[ -z "$errs" ]] && pass "no config errors" || fail "config errors: $errs"
  assert_eq "14" "$(hyprctl getoption decoration:rounding -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["int"])')" "rounding is 14"
  assert_eq "2" "$(hyprctl getoption general:border_size -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["int"])')" "border_size is 2"
  assert_eq "2" "$(hyprctl getoption decoration:blur:passes -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["int"])')" "blur passes is 2"
}
t_check_catches_bad_lua() {
  echo 'this is not lua' >> "$CFG/hypr/modules/theme.lua"
  assert_exit 1 "hush check fails on broken theme.lua" bin/hush check
  cp -f "$THEME_BAK" "$CFG/hypr/modules/theme.lua"
}
t_missing_key() {
  sed -i '/outline_variant/d' $CFG/hypr/modules/theme.lua
  assert_exit 1 "hush check fails when theme.lua lacks outline_variant" bin/hush check
  bin/hush check | grep -q 'outline_variant' && pass "hush check names the missing key" || fail "hush check did not name the missing key"
  # decorations.lua must still evaluate (metatable fallback) with a stub hl API.
  lua -e '
    local stub; stub = setmetatable({}, { __index = function() return stub end, __call = function() return stub end })
    hl = stub
    dofile(os.getenv("CFG") .. "/hypr/modules/decorations.lua")' >/dev/null 2>&1 && pass "decorations.lua survives a missing key" || fail "decorations.lua aborts on a missing key"
  hyprctl reload >/dev/null
  local errs; errs=$(hyprctl configerrors | grep -v '^$' || true)
  [[ -z "$errs" ]] && pass "live reload with a missing key has no config errors" || fail "config errors with missing key: $errs"
  cp -f "$THEME_BAK" "$CFG/hypr/modules/theme.lua"
  hyprctl reload >/dev/null
}
t_check_needs_hypr() {
  assert_exit 1 "hush check fails without HYPRLAND_INSTANCE_SIGNATURE" env -u HYPRLAND_INSTANCE_SIGNATURE bin/hush check
  assert_exit 0 "HUSH_CHECK_NO_HYPR=1 skips the Hyprland check" env -u HYPRLAND_INSTANCE_SIGNATURE HUSH_CHECK_NO_HYPR=1 bin/hush check
}
t_fallback_sync() {
  if [[ "$(bin/hush status | awk '/^theme/{print $2}')" != harbor ]]; then bin/hush theme harbor >/dev/null; fi
  python3 - <<'EOF' && pass "decorations.lua fallbacks equal generated harbor" || fail "fallback palettes drift from generated harbor"
import os, re
gen = dict(re.findall(r'(\w+) = "(#[0-9a-f]{6}|dark|light)"', open(os.environ["CFG"] + "/hypr/modules/theme.lua").read()))
dec = open(os.environ["CFG"] + "/hypr/modules/decorations.lua").read()
i = dec.index("local DEFAULT = {")
fb = dict(re.findall(r'(\w+) = "([^"]+)"', dec[i:dec.index("}", i)]))
assert fb == gen, (fb, gen)
EOF
}
run_test "hardcoded colors" t_no_hardcoded
run_test "opaque windows" t_opaque
run_test "live reload" t_reload
run_test "check catches bad lua" t_check_catches_bad_lua
run_test "missing theme key" t_missing_key
run_test "fallback palettes" t_fallback_sync
run_test "check needs hyprland" t_check_needs_hypr
finish

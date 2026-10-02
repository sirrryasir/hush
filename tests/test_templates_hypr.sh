#!/usr/bin/env bash
# Renders the Hyprland-side templates with a fixed color and checks the outputs parse.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
R=$(mktemp -d); trap 'rm -rf "$R"' EXIT
mkdir -p "$R/hush"
cfg="$R/matugen.toml"
test_matugen_cfg "$R" hypr gloview waybar hyprlock colors-json \
  | sed "s|'$R/hypr/modules/|'$R/|; s|'$R/waybar/|'$R/|; s|'$R/hyprlock/|'$R/|" > "$cfg"
matugen color hex "#7fb3a3" -c "$cfg" -m dark -t scheme-fidelity -q
t_lua() {
  assert_file "$R/theme.lua" "theme.lua rendered"
  lua -e "local t=dofile('$R/theme.lua'); assert(t.primary:match('^#%x%x%x%x%x%x$')); assert(t.mode=='dark'); assert(t.surface_container)" \
    && pass "theme.lua is valid Lua with primary and mode" || fail "theme.lua invalid"
  assert_file "$R/gloview-colors.lua" "gloview-colors.lua rendered"
  lua -e "local t=dofile('$R/gloview-colors.lua'); assert(type(t.backdrop_color)=='number')" && pass "gloview colors are numbers" || fail "gloview colors invalid"
}
t_css() {
  assert_contains "$R/colors.css" "@define-color primary #" "waybar colors.css has primary"
  assert_contains "$R/colors.css" "@define-color surface_container #" "waybar colors.css has surface_container"
}
t_hyprlock() {
  assert_contains "$R/colors.conf" '$hushSurfaceBase = rgba(' "hyprlock colors define \$hushSurfaceBase"
  assert_contains "$R/colors.conf" '$hushPrimary = rgba(' "hyprlock colors define \$hushPrimary"
}
t_json() {
  python3 -c "import json; d=json.load(open('$R/hush/Colors.json')); assert d['mode']=='dark'; assert d['primary'].startswith('#'); assert len(d['base16'])==16; assert d['surface_container_high']" \
    && pass "Colors.json valid with base16" || fail "Colors.json invalid"
  python3 -c "import json; d=json.load(open('$R/hush/Colors.json')); assert d['dark']['on_surface'].startswith('#'); assert len(d['dark'])==50, len(d['dark']); n=len([k for k in d if k not in ('base16','dark')]); assert n==51, n; assert d['primary_fixed'] and d['on_tertiary_fixed_variant'] and d['dark']['secondary_fixed_dim']" \
    && pass "Colors.json has dark block and *_fixed roles (51 top-level keys)" || fail "Colors.json missing dark block or fixed roles"
}
run_test "lua templates" t_lua
run_test "waybar css" t_css
run_test "hyprlock" t_hyprlock
run_test "Colors.json" t_json
finish

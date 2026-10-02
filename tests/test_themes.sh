#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
THEMES=(harbor ember moss dusk paper fog)
t_toml() {
  for t in "${THEMES[@]}"; do
    assert_file "themes/$t/theme.toml" "$t has theme.toml"
    assert_contains "themes/$t/theme.toml" "name = \"$t\"" "$t toml names itself"
    grep -qE '^mode = "(dark|light)"' "themes/$t/theme.toml" && pass "$t has mode" || fail "$t mode missing"
    grep -qE '^scheme = "scheme-' "themes/$t/theme.toml" && pass "$t has scheme" || fail "$t scheme missing"
    grep -qE '^seed = [0-9]+' "themes/$t/theme.toml" && pass "$t has seed" || fail "$t seed missing"
  done
}
t_wallpapers() {
  for t in "${THEMES[@]}"; do
    assert_file "themes/$t/wallpaper.png" "$t wallpaper exists"
    local dim; dim=$(python3 -c "from PIL import Image; im=Image.open('themes/$t/wallpaper.png'); print(f'{im.width}x{im.height}')")
    assert_eq "2560x1440" "$dim" "$t wallpaper is 2560x1440"
  done
}
t_deterministic() {
  local a b
  a=$(md5sum themes/harbor/wallpaper.png | cut -d' ' -f1)
  bin/hush-wallgen harbor >/dev/null
  b=$(md5sum themes/harbor/wallpaper.png | cut -d' ' -f1)
  assert_eq "$a" "$b" "regenerating harbor gives identical bytes"
}
run_test "theme.toml files" t_toml
run_test "wallpapers" t_wallpapers
run_test "determinism" t_deterministic
finish

#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
R=$(mktemp -d); trap 'rm -rf "$R"' EXIT
mkdir -p "$R/gtk-3.0" "$R/gtk-4.0" "$R/qt6ct" "$R/Kvantum/hush"
cfg="$R/matugen.toml"
test_matugen_cfg "$R" gtk3 gtk4 qt6ct kvantum > "$cfg"
matugen color hex "#7fb3a3" -c "$cfg" -m dark -t scheme-fidelity -q
t_gtk() {
  assert_contains "$R/gtk-3.0/gtk.css" "@define-color accent_bg_color #" "gtk3 css has accent_bg_color"
  assert_contains "$R/gtk-4.0/gtk.css" "@define-color window_bg_color #" "gtk4 css has window_bg_color"
}
t_qt() {
  local n; n=$(grep '^active_colors=' "$R/qt6ct/colors.conf" | tr ',' '\n' | wc -l)
  assert_eq "21" "$n" "qt6ct active_colors has 21 entries"
  grep -q '##' "$R/qt6ct/colors.conf" && fail "qt6ct has doubled hashes" || pass "qt6ct hex values clean"
  assert_contains "$R/Kvantum/hush/hush.kvconfig" "[GeneralColors]" "kvconfig has GeneralColors"
  assert_contains "$R/Kvantum/hush/hush.kvconfig" "window.color=#" "kvconfig window.color set"
  grep -qi '#FCFCFC' "$R/Kvantum/hush/hush.kvconfig" && fail "kvconfig still hard-codes #FCFCFC" || pass "kvconfig has no hard-coded #FCFCFC"
  local lit; lit=$(grep -vn '^\(\[\|#\)' "$R/Kvantum/hush/hush.kvconfig" | grep -E 'text\.[a-z]+\.color=#' | grep -viE '=#(9cd1c1|00382d|e1e3e0|c0c9c4)$' || true)
  [[ -z "$lit" ]] && pass "kvconfig text colors all come from the palette" || fail "kvconfig text colors not from palette: $lit"
  assert_file "$R/Kvantum/hush/hush.svg" "kvantum svg rendered"
  grep -qiE '#(FCFCFC|2B2B2B|1D2021|3D3D3D)' "$R/Kvantum/hush/hush.svg" && fail "kvantum svg keeps static wallbash greys" || pass "kvantum svg colors come from the palette"
  assert_contains "$CFG/qt6ct/qt6ct.conf" "custom_palette=true" "live qt6ct.conf uses the custom palette"
}
run_test "gtk" t_gtk
run_test "qt" t_qt
finish

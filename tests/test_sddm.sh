#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
T=sddm/hush
t_theme() {
  assert_file $T/Main.qml "Main.qml present"
  assert_contains $T/metadata.desktop 'MainScript=Main.qml' "metadata names the main script"
  assert_contains $T/metadata.desktop 'ConfigFile=theme.conf' "metadata names theme.conf"
  assert_contains $T/theme.conf 'background=current/wallpaper.png' "theme.conf background goes through current/"
  assert_contains $T/theme.conf 'colorsQml=current/colors.qml' "theme.conf colour file"
  assert_file $T/assets/avatar.png "fallback avatar"
  bash -n sddm/install.sh && pass "install.sh parses" || fail "install.sh syntax"
  assert_contains sddm/install.sh 'Current=hush' "install.sh selects the theme"
}
t_qml() {
  if command -v qmllint >/dev/null; then
    qmllint $T/Main.qml >/dev/null 2>&1 && pass "qmllint clean" || fail "qmllint errors in Main.qml"
  else pass "qmllint absent (skipped)"; fi
}
t_sync() {
  local home out; home=$(mktemp -d); out=$home/.cache/hush/sddm
  mkdir -p "$home/.cache/hush" "$home/.config/hush"
  cp "$CFG/hush/Colors.json" "$home/.config/hush/Colors.json" 2>/dev/null || echo '{"mode":"dark","primary":"#9cd1c1","surface":"#111413","on_surface":"#e1e3e0"}' > "$home/.config/hush/Colors.json"
  HOME=$home "$HUSH_ROOT/bin/hush" sddm sync 2>"$home/err"
  assert_file "$out/wallpaper.png" "sync writes wallpaper.png"
  assert_file "$out/colors.conf" "sync writes colors.conf"
  assert_file "$out/colors.qml" "sync writes colors.qml"
  assert_contains "$out/colors.conf" 'primary=#' "colors.conf has primary"
  assert_eq "r-x" "$(stat -c %A "$out" | cut -c8-10)" "bundle dir is o+rx"
  assert_eq "r--" "$(stat -c %A "$out/wallpaper.png" | cut -c8-10)" "wallpaper is world-readable"
  chmod o-x "$home"
  HOME=$home "$HUSH_ROOT/bin/hush" sddm sync 2>"$home/err"
  assert_contains "$home/err" 'not world-executable' "warns when HOME lacks o+x"
  rm -rf "$home"
}
run_test "theme files" t_theme
run_test "qml" t_qml
run_test "sync" t_sync
finish

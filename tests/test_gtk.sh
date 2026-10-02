#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
t_theme_dirs() {
  [[ -f ~/.themes/adw-gtk3/gtk-3.0/gtk.css ]] && pass "adw-gtk3 installed" || fail "adw-gtk3 missing"
  [[ -f ~/.themes/adw-gtk3-dark/gtk-3.0/gtk.css ]] && pass "adw-gtk3-dark installed" || fail "adw-gtk3-dark missing"
}
t_settings() {
  assert_contains ~/.config/gtk-3.0/settings.ini "gtk-font-name=Inter 10" "gtk3 font is Inter"
  assert_contains ~/.config/gtk-4.0/settings.ini "gtk-font-name=Inter 10" "gtk4 font is Inter"
}
run_test "theme dirs" t_theme_dirs
run_test "settings" t_settings
finish

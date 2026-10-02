#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H=bin/hush
t_list() {
  local out; out=$($H list | tr '\n' ' ')
  assert_eq "dusk ember fog harbor moss paper " "$out" "hush list prints the six themes sorted"
  mkdir -p themes/zz-not-a-theme
  out=$($H list | tr '\n' ' '); rmdir themes/zz-not-a-theme
  assert_eq "dusk ember fog harbor moss paper " "$out" "hush list skips directories without theme.toml"
  # Commands that do not render must work without matugen on PATH.
  local nb; nb=$(mktemp -d)
  for f in /usr/bin/*; do [[ "${f##*/}" == matugen ]] || ln -s "$f" "$nb/${f##*/}"; done
  PATH="$nb" $H list >/dev/null 2>&1 && pass "list works without matugen" || fail "list needs matugen"
  PATH="$nb" $H status >/dev/null 2>&1 && pass "status works without matugen" || fail "status needs matugen"
  PATH="$nb" $H theme harbor 2>&1 | grep -q 'missing dependency: matugen' && pass "theme still requires matugen" || fail "theme ran without matugen"
  rm -rf "$nb"
}
t_bad_theme() {
  cp ~/.config/hush/state.json /tmp/hush-state-before.json 2>/dev/null || echo '{}' > /tmp/hush-state-before.json
  assert_exit 1 "unknown theme exits 1" $H theme nope
  $H theme nope 2>&1 | grep -q 'no theme named "nope"' && pass "unknown theme message" || fail "unknown theme message"
  if [[ -f ~/.config/hush/state.json ]]; then
    cmp -s ~/.config/hush/state.json /tmp/hush-state-before.json && pass "state untouched after bad theme" || fail "state changed after bad theme"
  fi
}
t_apply() {
  local ino_before; ino_before=$(stat -c %i ~/.config/hush/state.json 2>/dev/null || echo none)
  assert_exit 0 "hush theme harbor succeeds" $H theme harbor
  [[ "$(stat -c %i ~/.config/hush/state.json)" != "$ino_before" ]] && pass "state.json replaced atomically (new inode)" || fail "state.json rewritten in place"
  [[ ! -e ~/.config/hush/state.json.tmp ]] && pass "no leftover state.json.tmp" || fail "state.json.tmp left behind"
  [[ ~/.config/hush/state.json -nt ~/.config/hush/Colors.json ]] && pass "state.json written after Colors.json" || fail "state.json older than Colors.json"
  [[ ~/.config/hush/state.json -nt ~/.config/Kvantum/kvantum.kvconfig ]] && pass "state.json written after consumer reloads" || fail "state.json written before consumer reloads"
  assert_file ~/.config/hush/state.json "state.json written"
  assert_eq "harbor" "$(python3 -c "import json;print(json.load(open('$CFG/hush/state.json'))['theme'])")" "state records harbor"
  assert_file ~/.config/hush/Colors.json "Colors.json written"
  assert_file "$CFG/hypr/modules/theme.lua" "theme.lua written"
  assert_file "$CFG/kitty/theme.conf" "kitty theme written"
  assert_eq "harbor" "$($H status | head -1 | awk '{print $2}')" "status reports harbor"
}
t_atomic() {
  # Break one template, apply, expect failure and no changed outputs.
  local before; before=$(md5sum "$CFG/hypr/modules/theme.lua" | cut -d' ' -f1)
  cp matugen/templates/theme.lua /tmp/theme.lua.bak
  trap 'mv -f /tmp/theme.lua.bak matugen/templates/theme.lua 2>/dev/null; trap - RETURN' RETURN
  echo '{{colors.does_not_exist.default.hex}}' >> matugen/templates/theme.lua
  assert_exit 1 "broken template makes hush theme fail" $H theme harbor
  mv -f /tmp/theme.lua.bak matugen/templates/theme.lua
  assert_eq "$before" "$(md5sum "$CFG/hypr/modules/theme.lua" | cut -d' ' -f1)" "theme.lua untouched after failed render"
}
t_wall_spaces() {
  mkdir -p "/tmp/hush wall test"
  cp themes/moss/wallpaper.png "/tmp/hush wall test/my wall.png"
  assert_exit 0 "hush wall with spaces in path" $H wall "/tmp/hush wall test/my wall.png"
  grep -q 'hush wall test/my wall.png' ~/.config/hush/state.json && pass "state has the spaced path" || fail "state missing spaced path"
  $H theme harbor >/dev/null
}
t_reload_wall() {
  rm -f ~/.config/hush/hyprlock-wall.conf
  assert_exit 0 "hush reload succeeds" $H reload
  assert_eq "\$wall = $HOME/.cache/hush/current-wallpaper.png" "$(cat ~/.config/hush/hyprlock-wall.conf 2>/dev/null)" "reload writes hyprlock-wall.conf with the fixed path"
  assert_eq "$(realpath themes/harbor/wallpaper.png)" "$(realpath ~/.cache/hush/current-wallpaper.png)" "current-wallpaper.png points at the harbor wallpaper"
  if awww query >/dev/null 2>&1; then
    awww query | grep -q 'themes/harbor/wallpaper.png' && pass "reload sets the wallpaper in awww" || fail "awww not showing harbor after reload"
  fi
  mkdir -p "/tmp/hush #hash test"
  cp themes/moss/wallpaper.png "/tmp/hush #hash test/w#1.png"
  assert_exit 0 "hush wall with # in path" $H wall "/tmp/hush #hash test/w#1.png"
  grep -q '#' ~/.config/hush/hyprlock-wall.conf && fail "hyprlock-wall.conf contains #" || pass "hyprlock-wall.conf has no # for a # path"
  assert_eq "/tmp/hush #hash test/w#1.png" "$(realpath ~/.cache/hush/current-wallpaper.png)" "fixed path links to the # wallpaper"
  $H theme harbor >/dev/null
}
t_lock() {
  # A held lock makes a mutating command wait; two concurrent applies both succeed.
  flock ~/.cache/hush/lock sleep 2 &
  local holder=$! t0 t1; sleep 0.3
  t0=$(date +%s%N); $H check >/dev/null 2>&1; t1=$(date +%s%N)
  wait $holder
  (( (t1 - t0) / 1000000 >= 1200 )) && pass "hush waits for the lock" || fail "hush did not wait for the lock ($(( (t1 - t0) / 1000000 )) ms)"
  $H theme harbor >/dev/null 2>&1 & local a=$!
  $H theme harbor >/dev/null 2>&1 & local b=$!
  local ra=0 rb=0; wait $a || ra=$?; wait $b || rb=$?
  assert_eq "0 0" "$ra $rb" "two concurrent hush theme runs both succeed"
  python3 -c "import json;json.load(open('$CFG/hush/Colors.json'))" && pass "Colors.json valid after concurrent runs" || fail "Colors.json corrupt after concurrent runs"
}
t_next_prev() {
  $H theme harbor >/dev/null
  $H theme next >/dev/null; assert_eq "moss" "$($H status | head -1 | awk '{print $2}')" "theme next goes harbor -> moss"
  $H theme prev >/dev/null; assert_eq "harbor" "$($H status | head -1 | awk '{print $2}')" "theme prev goes moss -> harbor"
  local binds="$CFG/hypr/modules/binds.lua"
  ! grep -qE 'wallbash|themeselect|themestyle|swwwall|rofiselect' "$binds" && pass "no HyDE theme scripts bound" || fail "HyDE theme scripts still bound"
  assert_contains "$binds" 'hush theme prev' "Super+Alt+Left runs hush theme prev"
  assert_contains "$binds" 'hush wall random' "Super+Shift+W runs hush wall random"
}
t_wall_mode() {
  local st=~/.config/hush/state.json
  $H theme harbor >/dev/null
  assert_exit 0 "wall paper image succeeds" $H wall themes/paper/wallpaper.png
  assert_eq "light" "$($H status | awk '$1=="mode"{print $2}')" "light wallpaper yields mode light"
  assert_eq "harbor" "$($H status | head -1 | awk '{print $2}')" "wall keeps the theme name"
  assert_eq "wallpaper" "$($H status | awk '$1=="source"{print $2}')" "wall writes source=wallpaper"
  assert_eq "light" "$(python3 -c "import json;print(json.load(open('$st'))['mode'])")" "state mode light"
  assert_exit 0 "wall harbor image succeeds" $H wall themes/harbor/wallpaper.png
  assert_eq "dark" "$($H status | awk '$1=="mode"{print $2}')" "dark wallpaper yields mode dark"
  $H wall themes/harbor/wallpaper.png --mode light >/dev/null
  assert_eq "light" "$($H status | awk '$1=="mode"{print $2}')" "--mode overrides luminance"
  $H theme harbor >/dev/null
}
t_check() { assert_exit 0 "hush check passes on a good state" $H check; }
run_test "list" t_list
run_test "bad theme" t_bad_theme
run_test "apply harbor" t_apply
run_test "atomic render" t_atomic
run_test "wall with spaces" t_wall_spaces
run_test "reload sets wallpaper" t_reload_wall
run_test "lock" t_lock
run_test "next/prev" t_next_prev
run_test "wall mode from image" t_wall_mode
run_test "check" t_check
finish

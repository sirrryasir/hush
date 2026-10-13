#!/usr/bin/env bash
# SDDM greeter, layout B: theme files, `hush sddm sync` / `hush face`, then the real greeter
# (sddm-greeter-qt6 --test-mode) in a nested Hyprland with one headless 1920x1080 output: idle,
# typing, checking, error and the session list, typed with wtype. theme.conf testAuth=fail stands in
# for the daemon (test mode has none). The live session is never touched.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/nested.sh"
cd "$(dirname "$0")/.."
T=sddm/hush
EVID="$HOME/.cache/hush/evidence"
R=$(mktemp -d)
trap 'session_pkill -f "sddm-greeter-qt6 --test-mode --theme $R" 2>/dev/null; nested_stop 2>/dev/null; rm -rf "$R"' EXIT

t_theme() {
  assert_file $T/Main.qml "Main.qml present"
  assert_contains $T/metadata.desktop 'MainScript=Main.qml' "metadata names the main script"
  assert_contains $T/metadata.desktop 'ConfigFile=theme.conf' "metadata names theme.conf"
  assert_contains $T/theme.conf 'background=current/wallpaper.png' "theme.conf background goes through current/"
  assert_contains $T/theme.conf 'colorsQml=current/colors.qml' "theme.conf colour file"
  assert_contains $T/theme.conf 'layoutQml=current/layout.qml' "theme.conf layout file"
  grep -qx 'testAuth=' $T/theme.conf && pass "testAuth empty in the shipped theme" || fail "theme.conf ships a testAuth value"
  assert_file $T/assets/avatar.png "fallback avatar"
  bash -n sddm/install.sh && pass "install.sh parses" || fail "install.sh syntax"
  assert_contains sddm/install.sh 'Current=hush' "install.sh selects the theme"
  assert_contains sddm/install.sh 'InterVariable.ttf' "install.sh bundles Inter"
  assert_contains sddm/install.sh 'MaterialSymbolsRounded.ttf' "install.sh bundles the icon font"
  grep -q 'XMLHttpRequest(' $T/Main.qml && fail "Main.qml uses XMLHttpRequest (blocked in the greeter)" || pass "no XMLHttpRequest file reads"
  for k in 'blurEnabled: true' 'lay.blurSddmBlur' 'lay.pillFocusW' 'lay.motionShakePx' 'PathAngleArc' 'sddm.login(' 'sessionModel.lastIndex'; do
    assert_contains $T/Main.qml "$k" "Main.qml: $k"
  done
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
  assert_file "$out/layout.qml" "sync writes layout.qml"
  assert_contains "$out/colors.conf" 'primary=#' "colors.conf has primary"
  assert_contains "$out/colors.qml" 'islandError' "colors.qml has the island roles"
  assert_contains "$out/layout.qml" 'property real pillCy: 0.7037' "layout.qml carries the shared spec"
  assert_eq "r-x" "$(stat -c %A "$out" | cut -c8-10)" "bundle dir is o+rx"
  assert_eq "r--" "$(stat -c %A "$out/wallpaper.png" | cut -c8-10)" "wallpaper is world-readable"
  assert_eq "r--" "$(stat -c %A "$out/layout.qml" | cut -c8-10)" "layout.qml is world-readable"
  chmod o-x "$home"
  HOME=$home "$HUSH_ROOT/bin/hush" sddm sync 2>"$home/err"
  assert_contains "$home/err" 'not world-executable' "warns when HOME lacks o+x"
  chmod o+x "$home"; rm -rf "$home"
}
t_face() {
  local home; home=$(mktemp -d); mkdir -p "$home/.config/hush"
  cp "$CFG/hush/Colors.json" "$home/.config/hush/Colors.json" 2>/dev/null || echo '{"mode":"dark","primary":"#9cd1c1","surface":"#111413","on_surface":"#e1e3e0"}' > "$home/.config/hush/Colors.json"
  magick -size 800x600 xc:'#c04020' "$home/in.jpg"
  HOME=$home "$HUSH_ROOT/bin/hush" face "$home/in.jpg" >/dev/null 2>"$home/err" && pass "hush face runs" || fail "hush face: $(cat "$home/err")"
  assert_eq "512x512" "$(magick identify -format '%wx%h' "$home/.face" 2>/dev/null)" "~/.face is a 512 px square"
  assert_eq "0" "$(magick "$home/.face" -format '%[fx:int(p{2,2}.a*255)]' info: 2>/dev/null)" "corners are transparent (round crop)"
  assert_eq "255" "$(magick "$home/.face" -format '%[fx:int(p{256,256}.a*255)]' info: 2>/dev/null)" "centre is opaque"
  cmp -s "$home/.face" "$home/.cache/hush/sddm/face.png" && pass "sddm bundle updated (sync ran)" || fail "sddm face.png not updated"
  HOME=$home "$HUSH_ROOT/bin/hush" face "$home/missing.png" 2>/dev/null && fail "hush face accepts a missing file" || pass "hush face rejects a missing file"
  rm -rf "$home"
}

# ---- the real greeter ---------------------------------------------------------------------------
greeter_theme() { # bundle dir -> $R/theme (a copy with fonts, current/ and testAuth=fail)
  mkdir -p "$R/theme"; cp -a $T/. "$R/theme/"; rm -f "$R/theme/current"; ln -s "$1" "$R/theme/current"
  mkdir -p "$R/theme/fonts"
  cp "$(fc-match -f '%{file}' 'Inter Variable')" "$R/theme/fonts/InterVariable.ttf"
  cp "$(fc-match -f '%{file}' 'Material Symbols Rounded')" "$R/theme/fonts/MaterialSymbolsRounded.ttf"
  sed -i 's/^testAuth=.*/testAuth=fail/' "$R/theme/theme.conf"
}
qcol() { sed -n "s/^ *property color $2: \"#\(......\)\"/\1/p" "$1/colors.qml"; }
near() { python3 -c "import sys; a,b='$1','$2'; sys.exit(0 if len(a)==6 and len(b)==6 and sum(abs(int(a[i:i+2],16)-int(b[i:i+2],16)) for i in (0,2,4)) <= ${3:-40} else 1)"; }
# frames are grabbed as PPM (PNG encoding of a blurred 1080p frame takes ~1 s and would miss the
# 600 ms error flash); evidence PNGs are written once the greeter is gone
shot() { nest grim -t ppm -o SHOT "$R/$1.ppm"; }
evidence() { local f; for f in "$@"; do python3 -c "from PIL import Image; Image.open('$R/$f.ppm').save('$EVID/sddm-b-$f.png')"; done; }

t_greeter() {
  command -v sddm-greeter-qt6 >/dev/null && command -v Hyprland >/dev/null && command -v grim >/dev/null && command -v wtype >/dev/null \
    || { pass "no sddm-greeter-qt6/Hyprland/grim/wtype (skipped)"; return; }
  local home=$R/home; mkdir -p "$home/.config/hush" "$EVID"
  cp "$CFG/hush/Colors.json" "$home/.config/hush/Colors.json"
  HOME=$home "$HUSH_ROOT/bin/hush" sddm sync 2>/dev/null
  local B=$home/.cache/hush/sddm
  greeter_theme "$B"
  # Inter: the theme loads it from fonts/ (the sddm user cannot see ~/.local fonts); fc-match proves
  # the bundled file really is Inter
  [[ "$(fc-query -f '%{family}' "$R/theme/fonts/InterVariable.ttf" 2>/dev/null)" == *Inter* ]] && pass "bundled font is Inter ($(fc-match -f '%{family[0]}' 'Inter Variable'))" || fail "bundled InterVariable.ttf is not Inter"
  nested_start "$R/nest" SHOT:1920x1080 || { fail "nested Hyprland"; return; }
  # the greeter opens one window on the primary screen: leave only the headless output
  nest hyprctl eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' >/dev/null; sleep 0.5
  nest hyprctl dismissnotify >/dev/null 2>&1
  nest hyprctl dispatch 'hl.dsp.cursor.move({ x = 20, y = 20 })' >/dev/null 2>&1   # no hover on the pill
  local since; since=$(date '+%Y-%m-%d %H:%M:%S')
  (nest env QT_QPA_PLATFORM=wayland sddm-greeter-qt6 --test-mode --theme "$R/theme" >"$R/greeter.log" 2>&1 &)
  local i; for ((i = 0; i < 50; i++)); do nest hyprctl clients 2>/dev/null | grep -q 'class: sddm-greeter' && break; sleep 0.2; done
  sleep 2.5
  local pid; pid=$(nest hyprctl clients 2>/dev/null | sed -n 's/^\s*pid: //p' | head -1)
  [[ -n "$pid" ]] && pass "greeter window mapped (pid $pid)" || { fail "greeter did not map: $(tail -3 "$R/greeter.log")"; return; }
  local log; log=$({ cat "$R/greeter.log"; journalctl --user --since "$since" _PID="$pid" -o cat 2>/dev/null; journalctl --since "$since" _PID="$pid" -o cat 2>/dev/null; } | grep 'hush-greeter:' | tail -1)
  [[ $log == *"font=Inter"* ]] && pass "greeter font: ${log#*font=}" || fail "greeter font not Inter: '$log'"
  [[ $log == *"icons=true"* ]] && pass "icon font loaded" || fail "icon font missing"
  [[ $log == *"sessions=Hyprland"* ]] && pass "Hyprland first in the session list" || fail "session order: $log"
  [[ $log == *"selected=Hyprland"* ]] && pass "Hyprland preselected (nothing remembered)" || fail "selected: $log"

  local text err prim hi w c
  text=$(qcol "$B" wallText); err=$(qcol "$B" islandError); prim=$(qcol "$B" islandPrimary); hi=$(qcol "$B" islandSurfaceHigh)
  shot idle
  [[ $(tests/sddmshot.py px "$R/idle.ppm" 110 0) != 000000 ]] && pass "idle: no pill before a key press" || fail "idle: pill shown before a key press"
  read -r got want < <(tests/lockshot.py clock "$R/idle.ppm" "$text")
  python3 -c "import sys; sys.exit(0 if abs($got-$want) <= 4 else 1)" 2>/dev/null \
    && pass "idle: clock centre y $got (spec $want)" || fail "idle: clock centre y $got (spec $want)"
  # the three 40 px buttons, 12 px apart: centres x 908 / 960 / 1012, y 1008 (headless output is 16-bit: colour checks allow ~24)
  # (sleep is dimmed to 40 % in test mode: no logind behind the greeter, canSuspend is false)
  local bx ok=1; for bx in -52 0 52; do
    c=$(python3 -c "from PIL import Image; im=Image.open('$R/idle.ppm').convert('RGB'); p=im.getpixel((960+$bx, 1008-14)); print(int(max(p)))")
    (( bx == 0 ? c < 40 : c == 0 )) || ok=0; done
  (( ok )) && pass "three black circle buttons bottom-centre" || fail "power row buttons not black at y 1008"
  (( $(tests/sddmshot.py menu "$R/idle.ppm") < 5 )) && pass "session list closed at rest" || fail "session list visible at rest"

  nest wtype 'hush-wrong'; sleep 0.6
  shot typing
  w=$(tests/sddmshot.py width "$R/typing.ppm")
  [[ $(tests/sddmshot.py px "$R/typing.ppm" 110 0) == 000000 ]] && pass "typing: a key press shows the black pill" || fail "typing: pill pixel #$(tests/sddmshot.py px "$R/typing.ppm" 110 0)"
  (( w >= 412 && w <= 428 )) && pass "typing: pill grew to ${w} px (spec 420)" || fail "typing: pill ${w} px (spec 420)"
  c=$(tests/sddmshot.py px "$R/typing.ppm" $((210 - 12 - 24 - 14)) 0)   # inside the submit button, left of its arrow
  near "$c" "$hi" 24 && pass "typing: submit button (#$c)" || fail "typing: no submit button (#$c, want #$hi)"
  (( $(tests/lockshot.py inside "$R/typing.ppm") > 150 )) && pass "typing: dots shown" || fail "typing: no dots"

  # a virtual-keyboard Return is now and then dropped right after a burst of text: resend once
  for ((i = 0; i < 2; i++)); do
    nest wtype -k Return; sleep 0.45
    shot checking
    w=$(tests/sddmshot.py width "$R/checking.ppm")
    (( w < 200 )) && break
  done
  (( w >= 64 && w <= 80 )) && pass "checking: pill collapsed to a ${w} px circle" || fail "checking: pill ${w} px (want 72)"
  (( $(tests/sddmshot.py near "$R/checking.ppm" "$prim" 35) >= 8 )) && pass "checking: primary arc around the avatar" || fail "checking: no arc in #$prim"

  # burst of frames over the fake auth (900 ms) and the error flash (600 ms), analysed afterwards
  for ((i = 0; i < 30; i++)); do nest grim -t ppm -o SHOT "$R/e$i.ppm"; done
  local edge="" f=""; for ((i = 0; i < 30; i++)); do
    edge=$(tests/sddmshot.py edge "$R/e$i.ppm"); near "$edge" "$err" 40 && { f=e$i; break; }
  done
  [[ -n $f ]] && cp "$R/$f.ppm" "$R/error.ppm"
  [[ -n $f ]] && pass "error: red hairline (#$edge ~ #$err)" || fail "error: hairline never turned #$err"
  sleep 1
  nest hyprctl dispatch 'hl.dsp.cursor.move({ x = 30, y = 30 })' >/dev/null 2>&1; sleep 0.4   # the pill hides 2 s after the error: wake it
  shot after-error
  w=$(tests/sddmshot.py width "$R/after-error.ppm")
  (( w >= 372 && w <= 388 )) && pass "after error: field cleared, pill back to ${w} px" || fail "after error: pill ${w} px"
  near "$(tests/sddmshot.py edge "$R/after-error.ppm")" "$err" 40 && fail "after error: hairline still red" || pass "after error: hairline back to the 12 % outline"

  nest wtype -k Tab; sleep 0.2; nest wtype -k Return; sleep 0.6
  shot sessions
  (( $(tests/sddmshot.py menu "$R/sessions.ppm") >= 60 )) && pass "Tab, Return: session list opens upward" || fail "session list did not open"
  nest wtype -k Escape; sleep 0.4
  session_pkill -f "sddm-greeter-qt6 --test-mode --theme $R"
  nested_stop
  evidence idle typing checking after-error sessions; [[ -f "$R/error.ppm" ]] && evidence error
}

run_test "theme files" t_theme
run_test "qml" t_qml
run_test "sync" t_sync
run_test "face" t_face
run_test "greeter (nested)" t_greeter
finish

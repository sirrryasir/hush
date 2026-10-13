#!/usr/bin/env bash
# hyprlock fallback (`hush lock --hyprlock`), look A: static checks on the generated layout, then real screenshots in a nested
# Hyprland (headless 1920x1080 and 2560x1440 outputs) for harbor and paper. The live session is never
# locked: hyprlock runs inside the nested compositor and authenticates against the vlock PAM service
# (pam_unix only, no faillock), so the wrong-password check cannot lock the account.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/nested.sh"
cd "$(dirname "$0")/.."
EVID="$HOME/.cache/hush/evidence"
R=$(mktemp -d)
trap 'nested_stop 2>/dev/null; session_pkill -f "hyprlock -c $R" 2>/dev/null; rm -rf "$R"' EXIT
GEN=lockscreen/gen.py

render_theme() { # theme -> $R/$t/hyprlock/colors.conf, wall.conf
  local t=$1 mode scheme contrast
  mkdir -p "$R/$t"; test_matugen_cfg "$R/$t" hyprlock > "$R/$t.toml"
  mode=$(sed -n 's/^mode = "\(.*\)"/\1/p' themes/$t/theme.toml); scheme=$(sed -n 's/^scheme = "\(.*\)"/\1/p' themes/$t/theme.toml)
  contrast=$(sed -n 's/^contrast = //p' themes/$t/theme.toml)
  matugen image "themes/$t/wallpaper.png" -c "$R/$t.toml" -m "$mode" -t "$scheme" --contrast "${contrast:-0}" --source-color-index 0 -q >/dev/null 2>&1
  printf '$wall = %s\n' "$PWD/themes/$t/wallpaper.png" > "$R/$t/wall.conf"
}

t_sources() {
  assert_contains "$CFG/hypr/hyprlock.conf" 'hush/hyprlock-wall.conf' "hyprlock.conf sources the hush wallpaper file"
  assert_contains hyprlock/hyprlock.conf 'hush/hyprlock-layout.conf' "hyprlock.conf sources the generated layout"
  assert_contains bin/hush 'lock_layout' "hush generates the layout (reload, lock)"
  [[ -x hyprlock/status-line.sh ]] && pass "status-line.sh executable" || fail "status-line.sh not executable"
}
t_generator() {
  python3 $GEN hyprlock "$R/a.conf" SHOT:1080 BIG:1440 || { fail "generator failed"; return; }
  pass "generator writes per-monitor widgets"
  assert_contains "$R/a.conf" 'monitor = SHOT' "block set for SHOT"
  assert_contains "$R/a.conf" 'monitor = BIG' "block set for BIG"
  assert_contains "$R/a.conf" 'size = 340, 56' "pill 340x56 at 1080"
  assert_contains "$R/a.conf" 'size = 454, 74' "pill scales to 454x74 at 1440 (even px)"
  assert_contains "$R/a.conf" 'position = 0, 18.000%' "clock at +18 % (centre y 346 of 1080)"
  assert_contains "$R/a.conf" 'position = 0, -20.000%' "pill at -20 % (centre y 756)"
  assert_contains "$R/a.conf" 'position = 0, -25.460%' "status line at -25.46 % (centre y 815)"
  assert_contains "$R/a.conf" 'font_family = Inter Variable Thin' "clock Inter Variable Thin"
  assert_contains "$R/a.conf" 'font_size = 120' "clock 160 px (120 pt) at 1080"
  assert_contains "$R/a.conf" "date +'%A %-d %B' | tr a-z A-Z" "date in capitals"
  assert_contains "$R/a.conf" 'fade_on_empty = true' "field hidden until you type"
  [[ $(grep -c 'Material Symbols' "$R/a.conf") == 2 ]] && pass "icon font only for the top-right glyphs (no pill glyphs)" || fail "icon font labels: $(grep -c 'Material Symbols' "$R/a.conf") (want one per monitor)"
  assert_contains "$R/a.conf" 'inner_color = $hushIslandBg' "the field is the black pill"
  grep -qE '^(shape|image) ' "$R/a.conf" && fail "shape/image blocks left (the field is the pill)" || pass "no shape or image blocks"
  assert_contains "$R/a.conf" 'blur_passes = 3' "blur 3 passes"
  python3 - "$R/a.conf" <<'PY' && pass "brightness follows the theme mode" || fail "brightness does not follow the mode"
import json, os, re, sys, tomllib
b = tomllib.load(open("lockscreen/layout.toml", "rb"))["blur"]
try: mode = json.load(open(os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "hush", "state.json"))).get("mode")
except (OSError, ValueError): mode = None
want = b["brightness_light"] if mode == "light" else b["brightness"]
sys.exit(0 if re.search(r"^\s*brightness = %s$" % re.escape(str(want)), open(sys.argv[1]).read(), re.M) else 1)
PY
  assert_contains "$R/a.conf" 'fail_text =' "empty fail text"
  assert_contains "$R/a.conf" 'placeholder_text =' "no placeholder (the field shows only while typing)"
  assert_contains "$R/a.conf" 'check_color = $hushIslandCheck' "check colour = island primary"
  assert_contains "$R/a.conf" 'fail_color = $hushIslandFail' "fail colour = island error"
  python3 $GEN hyprlock "$R/b.conf"; assert_contains "$R/b.conf" 'monitor =' "no monitors: one set for every monitor"
  grep -nE "#[0-9a-fA-F]{6}|rgba\([0-9]" "$R/a.conf" hyprlock/layouts/layout_default.conf && fail "hardcoded colours" || pass "no hardcoded colours"
  local h; h=$(HOME="$R/home" HUSH_ROOT=$PWD bash -c 'source <(sed -n "/^lock_monitors()/,/^}/p;/^lock_layout()/,/^}/p" bin/hush); STATE_DIR=$HOME/.config/hush; HYPRLAND_INSTANCE_SIGNATURE= lock_layout' && echo ok)
  [[ $h == ok && -s "$R/home/.config/hush/hyprlock-layout.conf" ]] && pass "lock_layout writes ~/.config/hush/hyprlock-layout.conf" || fail "lock_layout"
}
t_variables() {
  local t v undefined
  for t in harbor paper; do
    render_theme $t
    undefined=""
    for v in $(cat "$R/a.conf" hyprlock/layouts/layout_default.conf | grep -oE '\$[A-Za-z_0-9]+' | sort -u | grep -vxE '\$(HOME|FPRINTPROMPT|FAIL|ATTEMPTS|wall)'); do
      grep -qE "^\\${v} = rgba\\([0-9a-f]{8}\\)" "$R/$t/hyprlock/colors.conf" || undefined="$undefined $v"; done
    [[ -z "$undefined" ]] && pass "$t: every variable defined" || fail "$t: undefined:$undefined"
  done
  local clash; clash=$(cat hyprlock/hyprlock.conf "$R/harbor/hyprlock/colors.conf" "$R/harbor/wall.conf" hyprlock/layouts/layout_default.conf \
    | grep -oE '^\s*\$[A-Za-z_0-9]+\s*=' | grep -oE '[A-Za-z_0-9]+' | sort -u | awk '{a[NR]=$0} END{for(i=1;i<=NR;i++)for(j=1;j<=NR;j++)if(i!=j && index(a[j],a[i])==1)print a[i]" prefixes "a[j]}')
  [[ -z "$clash" ]] && pass "no hyprlock variable is a prefix of another" || fail "prefix clashes: $clash"
}
t_version() {
  hyprlock --version 2>&1 | grep -q 'v0\.' && pass "$(hyprlock --version 2>&1 | head -1)" || fail "hyprlock --version"
  if strings "$(command -v hyprlock)" | grep -qx inputFieldWidth; then
    assert_contains hyprlock/layouts/layout_default.conf 'inputFieldWidth' "inputFieldWidth animation enabled (installed hyprlock has it)"
  else pass "installed hyprlock lacks inputFieldWidth (not used)"; fi
  assert_contains hyprlock/layouts/layout_default.conf 'fadeIn, 1, 2.5' "fadeIn 2.5"
  assert_contains hyprlock/layouts/layout_default.conf 'fadeOut, 1, 2.5' "fadeOut 2.5"
}

lock_conf() { # theme -> config path
  local t=$1
  python3 $GEN hyprlock "$R/$t/layout.conf" SHOT:1080 BIG:1440 WAYLAND-1:720
  cat > "$R/$t/hyprlock.conf" <<EOF
\$hyprlockDir = $PWD/hyprlock
source = $R/$t/wall.conf
source = $R/$t/hyprlock/colors.conf
source = $PWD/hyprlock/layouts/layout_default.conf
source = $R/$t/layout.conf
auth {
    pam {
        module = vlock
    }
    fingerprint {
        enabled = false
    }
}
EOF
  echo "$R/$t/hyprlock.conf"
}
hex_of() { sed -n "s/^\\\$$2 = rgba(\([0-9a-f]\{6\}\)..)/\1/p" "$R/$1/hyprlock/colors.conf"; }

t_nested() {
  command -v Hyprland >/dev/null && command -v grim >/dev/null || { pass "no Hyprland/grim (skipped)"; return; }
  [[ -f /etc/pam.d/vlock ]] || { pass "no /etc/pam.d/vlock (skipped: never test a wrong password against faillock)"; return; }
  mkdir -p "$EVID"
  nested_start "$R/nest" SHOT:1920x1080 BIG:2560x1440 || { fail "nested Hyprland"; return; }
  pass "nested Hyprland with SHOT 1920x1080 and BIG 2560x1440"
  local t cfg out H text w spec
  for t in harbor paper; do
    cfg=$(lock_conf $t)
    nest hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1
    nest hyprctl dismissnotify >/dev/null 2>&1
    (nest hyprlock -c "$cfg" --grace 0 >"$R/$t/hyprlock.log" 2>&1 &)
    sleep 3
    text=$(hex_of $t hushWallText)
    for out in SHOT BIG; do
      H=1080; [[ $out == BIG ]] && H=1440
      nest grim -o $out "$EVID/lock-b-$t-$H.png"
      read -r w r g b < <(tests/lockshot.py pill "$EVID/lock-b-$t-$H.png")
      [[ "$r$g$b" != 000 ]] && pass "$t $H: no pill before a key press" || fail "$t $H: pill shown before a key press"
      read -r got want _ < <(tests/lockshot.py clock "$EVID/lock-b-$t-$H.png" "$text")
      python3 -c "import sys; sys.exit(0 if abs($got-$want) <= 4 else 1)" 2>/dev/null \
        && pass "$t $H: clock centre y $got (spec $want)" || fail "$t $H: clock centre y $got (spec $want)"
    done
    nest wtype 'hu'; sleep 1
    for out in SHOT BIG; do
      H=1080; [[ $out == BIG ]] && H=1440
      nest grim -o $out "$EVID/lock-b-$t-$H-key.png"
      read -r w r g b < <(tests/lockshot.py pill "$EVID/lock-b-$t-$H-key.png")
      spec=$(python3 -c "print(2*round(340*$H/1080/2))")
      [[ "$r$g$b" == 000 ]] && pass "$t $H: a key press shows the black pill" || fail "$t $H: pill pixel $r,$g,$b after a key press"
      (( w >= spec - 8 && w <= spec + 8 )) && pass "$t $H: pill ${w} px wide (spec $spec)" || fail "$t $H: pill ${w} px (spec $spec)"
    done
    nest wtype -k BackSpace -k BackSpace; sleep 0.3
    nest grim -t ppm -o SHOT "$R/empty.ppm"   # placeholder, before the 2 s fade
    if [[ $t == harbor ]]; then
      nest wtype 'hush-not-the-password'; sleep 0.6
      nest grim -o SHOT "$EVID/lock-b-harbor-typing.png"
      (( $(tests/lockshot.py inside "$EVID/lock-b-harbor-typing.png") > 150 )) && pass "typing shows dots" || fail "no dots while typing"
      read -r lo hi < <(tests/lockshot.py dots "$EVID/lock-b-harbor-typing.png")
      (( lo >= 0 && hi >= 0 )) && pass "21 dots stay inside the pill (margins $lo/$hi px)" || fail "dots spill over the pill ends ($lo/$hi px)"
      nest wtype -k Return
      local i edge="" err; err=$(hex_of harbor hushIslandFail)
      # PNG encoding of a blurred frame takes ~2 s under hyprlock, longer than the 600 ms fail
      # flash: poll with uncompressed PPM frames, keep the first one showing the error hairline
      for ((i = 0; i < 60; i++)); do
        nest grim -t ppm -o SHOT "$R/fail.ppm"; edge=$(tests/lockshot.py edge "$R/fail.ppm")
        [[ $edge == "$err" ]] && break; sleep 0.05
      done
      python3 -c "from PIL import Image; Image.open('$R/fail.ppm').save('$EVID/lock-b-harbor-fail.png')"
      [[ $edge == "$err" ]] && pass "wrong password: hairline turns island error #$err" || fail "fail outline #$edge (want #$err)"
      # no fail text: nothing in the pill brighter than the idle placeholder (a fail text draws in
      # the full field colour, the placeholder at 60 %)
      local inside idle; inside=$(tests/lockshot.py inside "$R/fail.ppm"); idle=$(tests/lockshot.py inside "$R/empty.ppm")
      (( inside <= idle + 10 )) && pass "no fail text in the pill (max luminance $inside, idle placeholder $idle)" || fail "text in the pill on failure (luminance $inside > idle $idle)"
    fi
    session_pkill -f "hyprlock -c $R" ; sleep 0.5
  done
  nested_stop
}

run_test "sources" t_sources
run_test "generator" t_generator
run_test "variables" t_variables
run_test "version" t_version
run_test "nested screenshots" t_nested
finish

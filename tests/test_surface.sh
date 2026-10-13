#!/usr/bin/env bash
# Island surface: one full-width, fixed-height layer per monitor whose geometry never
# changes; only the input mask follows the pill. Clicks 2 px outside the pill reach the window below,
# a click on the pill does not; a fullscreen window retracts the pill. Runs on every monitor.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
A=hush-surface-probe-a; B=hush-surface-probe-b
shell_settings_save
ORIG_MON=$(mon_focused)
active() { hyprctl activewindow -j | python3 -c "import json,sys;print(json.load(sys.stdin).get('class',''))" 2>/dev/null; }
# "w h" of every hush-island layer, one line per monitor: "MON x y w h".
layers() {
  hyprctl layers -j | python3 -c "
import json,sys
for n, m in sorted(json.load(sys.stdin).items()):
  for lvl in m['levels'].values():
    for l in lvl:
      if l['namespace']=='hush-island': print(n, l['x'], l['y'], l['w'], l['h'])"
}
cleanup() {
  local c; for c in $A $B; do hyprctl dispatch "hl.dsp.window.close({ window = \"class:$c\" })" >/dev/null 2>&1; done
  input_stop
  shell_settings_restore
  [[ "$(shell_ipc islandState 2>/dev/null)" == expanded ]] && shell_ipc toggleControlCenter >/dev/null 2>&1
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$ORIG_MON\" })" >/dev/null 2>&1
}
trap cleanup EXIT
click() { # x y [settle]: warp the pointer and left-click (tests/lib/input.sh)
  hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })" >/dev/null; sleep "${3:-0.3}"
  input_click; sleep 0.5
}
spawn() { # class x y w h: a floating kitty at a fixed rect (never touches other windows)
  hyprctl dispatch "hl.dsp.exec_cmd(\"kitty --class $1\")" >/dev/null
  local i addr grouped; for i in $(seq 30); do hyprctl clients -j | grep -q "\"class\": \"$1\"" && break; sleep 0.2; done
  probe() { hyprctl clients -j | python3 -c "
import json,sys
c=next((c for c in json.load(sys.stdin) if c['class']=='$1'), None)
print(c['address'] if c else '', 1 if c and c['grouped'] else 0)"; }
  read -r addr grouped <<<"$(probe "$1")"
  [[ -z "$addr" ]] && return 1
  # A workspace with a window group auto-groups new windows; take the probe out first, or the
  # float/move below would carry the whole group (the user's windows) with it.
  if [[ $grouped == 1 ]]; then
    hyprctl dispatch "hl.dsp.window.move({ out_of_group = true, window = \"address:$addr\" })" >/dev/null; sleep 0.2
    read -r addr grouped <<<"$(probe "$1")"; [[ $grouped == 1 ]] && return 1
  fi
  hyprctl dispatch "hl.dsp.window.float({ action = \"enable\", window = \"address:$addr\" })" >/dev/null
  hyprctl dispatch "hl.dsp.window.resize({ x = $4, y = $5, window = \"address:$addr\" })" >/dev/null
  hyprctl dispatch "hl.dsp.window.move({ x = $2, y = $3, window = \"address:$addr\" })" >/dev/null
}

t_layers() {
  rm -f "$F"; shell_restart; sleep 3
  assert_eq "pong" "$(shell_ipc ping)" "shell up"
  local m mx my mw mh r line
  for m in $(mon_names); do
    read -r mx my mw mh r <<<"$(mon_geom "$m")"
    line=$(layers | grep "^$m ")
    assert_eq "$m $mx $my $mw 360" "$line" "$m: island layer is full width x 360 at the top"
    assert_eq "40" "$r" "$m: reserve mode reserves 40 px"
  done
}
t_constant() {
  local before after; before=$(layers)
  shell_ipc toggleControlCenter >/dev/null; sleep 0.8
  assert_eq "expanded" "$(shell_ipc islandState)" "control center opens"
  after=$(layers)
  assert_eq "$before" "$after" "layer geometry unchanged while expanded"
  local i; for i in $(seq 20); do [[ "$(shell_ipc islandSize)" == "560x304" ]] && break; sleep 0.1; done
  assert_eq "560x304" "$(shell_ipc islandSize)" "pill springs to 560x304 inside the fixed surface"
  shell_ipc toggleControlCenter >/dev/null; sleep 0.8
  assert_eq "$before" "$(layers)" "layer geometry unchanged after collapse"
}
t_mask() {
  input_start || { pass "$(input_why): click checks skipped"; return; }
  local m mx my mw mh r sz pw ph px py
  for m in $(mon_names | tr ' ' '\n' | head -2); do
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$m\" })" >/dev/null; sleep 0.6
    assert_eq "$m" "$(shell_ipc islandScreen)" "$m: focused island drives IPC"
    read -r mx my mw mh r <<<"$(mon_geom "$m")"
    # A covers the top band under the pill; B sits low on the screen and holds focus.
    if ! spawn $A $((mx + mw / 2 - 500)) "$my" 1000 300 || ! spawn $B $((mx + mw / 2 - 300)) $((my + mh - 360)) 600 300; then
      fail "$m: could not place the probe windows"; continue
    fi
    sz=$(shell_ipc islandSize); pw=${sz%x*}; ph=${sz#*x}
    px=$((mx + mw / 2)); py=$((my + 6 + ph / 2))
    # Outside: 2 px right of the pill's edge lands on A.
    hyprctl dispatch "hl.dsp.focus({ window = \"class:$B\" })" >/dev/null; sleep 0.3
    click $((px + pw / 2 + 2)) "$py"
    assert_eq "$A" "$(active)" "$m: click 2 px outside the pill reaches the window below"
    # Inside: the pill takes the click (opens the control center); focus does not move to A.
    hyprctl dispatch "hl.dsp.focus({ window = \"class:$B\" })" >/dev/null; sleep 0.3
    hyprctl dispatch "hl.dsp.cursor.move({ x = $px, y = $((my + mh - 210)) })" >/dev/null; sleep 0.3
    click "$px" "$py" 0.05 # before the v1 hover-to-expand timer (400 ms) can fire
    assert_eq "$B" "$(active)" "$m: click on the pill does not reach the window below"
    assert_eq "expanded" "$(shell_ipc islandState)" "$m: click on the pill opens the control center"
    # Leave the pill first, or the hover timer re-expands it after the collapse.
    hyprctl dispatch "hl.dsp.cursor.move({ x = $px, y = $((my + mh - 210)) })" >/dev/null; sleep 0.2
    shell_ipc toggleControlCenter >/dev/null; sleep 0.8
    # Fullscreen on this monitor retracts the pill; geometry stays put.
    local before; before=$(layers)
    hyprctl dispatch "hl.dsp.window.fullscreen({ action = \"toggle\", window = \"class:$A\" })" >/dev/null; sleep 0.8
    assert_eq "hidden" "$(shell_ipc islandState)" "$m: fullscreen window retracts the pill"
    assert_eq "$before" "$(layers)" "$m: layer geometry unchanged while hidden"
    hyprctl layers -j | python3 -c "import json,sys;d=json.load(sys.stdin)['$m']['levels'];sys.exit(0 if any(l['namespace']=='hush-island-reveal' for l in d.get('3',[])) else 1)" \
      && pass "$m: top-edge reveal strip live over the fullscreen window" || fail "$m: no reveal strip under fullscreen"
    hyprctl dispatch "hl.dsp.window.fullscreen({ action = \"toggle\", window = \"class:$A\" })" >/dev/null; sleep 0.8
    [[ "$(shell_ipc islandState)" != hidden ]] && pass "$m: pill returns after fullscreen" || fail "$m: pill still hidden"
    local c; for c in $A $B; do hyprctl dispatch "hl.dsp.window.close({ window = \"class:$c\" })" >/dev/null; done
    # Wait until both are gone, or the next spawn() matches a closing window.
    for c in $(seq 30); do hyprctl clients -j | grep -q 'hush-surface-probe' || break; sleep 0.2; done
  done
}
t_modes() {
  local m; m=$(mon_focused)
  shell_ipc settingsSet island.mode '"overlay"' >/dev/null; sleep 1
  assert_eq "0" "$(mon_geom "$m" | cut -d' ' -f5)" "overlay mode reserves nothing"
  shell_ipc settingsSet island.mode '"autohide"' >/dev/null; sleep 1
  assert_eq "0" "$(mon_geom "$m" | cut -d' ' -f5)" "auto-hide mode reserves nothing"
  hyprctl layers -j | grep -q '"namespace": "hush-island-reveal"' && pass "reveal strip present in auto-hide" || fail "reveal strip missing"
  [[ "$(shell_ipc islandState)" == hidden || "$(shell_ipc islandState)" == osd || "$(shell_ipc islandState)" == notification ]] \
    && pass "auto-hide retracts an idle pill" || fail "auto-hide pill state $(shell_ipc islandState)"
  shell_ipc toggleControlCenter >/dev/null; sleep 0.8
  assert_eq "expanded" "$(shell_ipc islandState)" "auto-hide: a raise >= OSD shows the pill"
  shell_ipc toggleControlCenter >/dev/null; sleep 0.8
  shell_ipc settingsSet island.mode '"reserve"' >/dev/null; sleep 1
  assert_eq "40" "$(mon_geom "$m" | cut -d' ' -f5)" "back to reserve: 40 px"
  hyprctl layers -j | grep -q '"namespace": "hush-island-reveal"' && fail "reveal strip left behind" || pass "no reveal strip in reserve mode"
}
run_test "layers" t_layers; run_test "constant" t_constant; run_test "mask" t_mask; run_test "modes" t_modes; run_test "log" shell_log_check
finish

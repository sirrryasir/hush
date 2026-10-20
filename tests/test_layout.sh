#!/usr/bin/env bash
# Island composition (settings key `layout`, config/Composer.qml) on the live shell:
#   settingsSet layout.hover reorders the hover face's chips (rendered order, read back from the
#   shown state), a disabled chip leaves it; a control center tile switched off in layout.cc.tiles
#   is absent from the grid, a 1x1 tile shares a row, layout.cc.sliders false hides the sliders,
#   layout.rest.left none drops the activity slot; settingsReset layout brings the defaults back.
# Note: qs ipc (CLI11) splits an argument that looks like "[a,b]" into several, so array JSON goes
# in with a leading space (JSON.parse ignores it).
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
shell_settings_save
read -r MX MY MW MH < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']))")
TOP=$(shell_ipc settingsGet island.topGap 2>/dev/null || echo 6); [[ -z "$TOP" ]] && TOP=6
PX=$((MX + MW / 2)); PY=$((MY + TOP + 18)); AX=$PX; AY=$((MY + MH / 2))
# Polls a command until it prints the expected value (layout writes go through settings.json).
wait_eq() { local want=$1 i out; shift; for i in $(seq 30); do out=$("$@"); [[ "$out" == "$want" ]] && break; sleep 0.1; done; echo "$out"; }
chips() { shell_ipc islandChips hoverChip_; }
tiles() { shell_ipc islandChips ccTile_; }
cleanup() {
  input_move "$AX" "$AY"
  shell_ipc closeSurface >/dev/null 2>&1
  shell_settings_restore
}
trap cleanup EXIT

shell_alive || { fail "shell not running"; exit 1; }
if session_pgrep -x hyprlock >/dev/null; then echo "  SKIP session locked (hyprlock takes the pointer)"; exit 0; fi

# Pointer onto the pill, then wait for the hover face's chips (the morph swaps the state item in).
hover_on() {
  input_move "$AX" "$AY"; shell_wait_state rest; input_move "$PX" "$PY"; shell_wait_state hover || return 1
  local i; for i in $(seq 30); do [[ -n "$(chips)" ]] && return 0; sleep 0.1; done; return 1
}

t_hover() {
  shell_ipc settingsReset layout >/dev/null; sleep 0.4
  assert_eq "workspaces,date,media,bluetooth,network,battery,keyboard,shelf" "$(shell_ipc layoutHover)" "default hover chips"
  hover_on || { fail "pointer on the pill did not show the hover face"; return; }
  # Rendered order: the chips with something to show (media only while playing, Bluetooth when on).
  local got want; got=$(chips)
  want=$(shell_ipc layoutHover | tr ',' '\n' | grep -xF -f <(tr ',' '\n' <<<"$got") | paste -sd,)
  assert_eq "workspaces,date" "$(cut -d, -f1-2 <<<"$got")" "hover face starts with workspaces, date"
  assert_eq "$want" "$got" "hover face renders the chips in layout order"
  shell_ipc settingsSet layout.hover ' [{"id":"battery","enabled":true},{"id":"date","enabled":true},{"id":"workspaces","enabled":true},{"id":"network","enabled":false}]' >/dev/null
  assert_eq "battery,date,workspaces" "$(wait_eq battery,date,workspaces shell_ipc layoutHover)" "settingsSet layout.hover reorders and drops the disabled chip"
  # No battery on this machine: that chip has nothing to show and leaves no gap.
  want="battery,date,workspaces"; [[ -z "$(shell_ipc batterySummary)" ]] && want="date,workspaces"
  assert_eq "$want" "$(wait_eq "$want" chips)" "the hover face follows: battery, date, workspaces, no network"
  input_move "$AX" "$AY"; shell_wait_state rest
}

t_cc() {
  shell_ipc openSurface expanded >/dev/null; shell_wait_state expanded || { fail "control center did not open"; return; }
  sleep 0.3
  assert_eq "wifi,bluetooth,dnd,nightlight" "$(tiles)" "default tiles"
  assert_eq "true" "$(shell_ipc islandControlVisible volumeSlider)" "sliders shown by default"
  shell_ipc settingsSet layout.cc.tiles ' [{"id":"wifi","enabled":true,"size":"2x1"},{"id":"bluetooth","enabled":false,"size":"2x1"},{"id":"dnd","enabled":true,"size":"1x1"},{"id":"lock","enabled":true,"size":"1x1"},{"id":"nightlight","enabled":true,"size":"2x1"}]' >/dev/null
  local got; got=$(wait_eq "wifi,dnd,lock,nightlight" tiles)
  assert_eq "wifi,dnd,lock,nightlight" "$got" "Bluetooth tile switched off is absent, Lock joins"
  assert_eq "false" "$(shell_ipc islandControlVisible ccTile_bluetooth)" "no Bluetooth tile in the grid"
  shell_ipc settingsSet layout.cc.sliders false >/dev/null
  assert_eq "false" "$(wait_eq false shell_ipc islandControlVisible volumeSlider)" "layout.cc.sliders false hides the volume slider"
  [[ "$(shell_ipc islandSize)" == 560x* ]] && pass "the control center keeps its 560 px width" || fail "control center size $(shell_ipc islandSize)"
  shell_ipc closeSurface >/dev/null; shell_wait_state rest
}

t_rest_reset() {
  shell_ipc settingsSet layout.rest.left '"none"' >/dev/null
  assert_eq "false" "$(wait_eq false shell_ipc islandControlVisible activityCircle)" "layout.rest.left none: no activity slot"
  shell_ipc settingsReset layout >/dev/null; sleep 0.5
  assert_eq "no" "$(python3 -c "import json;print('yes' if 'layout' in json.load(open('$F')) else 'no')" 2>/dev/null || echo no)" "settingsReset drops the layout override"
  assert_eq "workspaces,date,media,bluetooth,network,battery,keyboard,shelf" "$(shell_ipc layoutHover)" "after reset: default hover chips"
  assert_eq "wifi:2x1,bluetooth:2x1,vpn:1x1,dnd:2x1,nightlight:2x1" "$(shell_ipc layoutTiles)" "after reset: default tiles"
  shell_ipc openSurface expanded >/dev/null; shell_wait_state expanded; sleep 0.3
  assert_eq "wifi,bluetooth,dnd,nightlight" "$(tiles)" "after reset: the grid has the four default tiles"
  assert_eq "true" "$(shell_ipc islandControlVisible volumeSlider)" "after reset: sliders back"
  shell_ipc closeSurface >/dev/null; shell_wait_state rest
}

run_test "hover face from layout.hover" t_hover
run_test "control center from layout.cc" t_cc
run_test "rest slot and reset" t_rest_reset
finish

#!/usr/bin/env bash
# Caffeine: the control center's "Stay awake" tile (off in the default layout) in the cc harness,
# then the cup in the live rest pill's status ring while it is on. PNGs land in $HUSH_SHOTS.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
LOG=$(mktemp); HUSH_BT_NO_ADAPTER=1 "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -f "$LOG"' EXIT
layer_geom() { hyprctl layers -j | python3 -c "
import json,sys
for o in json.load(sys.stdin).values():
  for lv in o['levels'].values():
    for l in lv:
      if l['namespace']=='$1': print('%d,%d %dx%d' % (l['x'],l['y'],l['w'],l['h']))"; }
act() { qs -c hush ipc call activity "$@"; }
t_tile() {
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  assert_eq "main" "$(cc page)" "harness starts on the main page"
  assert_eq "false" "$(cc tileShown caffeine)" "caffeine tile off in the default layout"
  cc enableTile caffeine >/dev/null
  for i in $(seq 20); do [[ "$(cc tileShown caffeine)" == true ]] && break; sleep 0.3; done
  assert_eq "true" "$(cc tileShown caffeine)" "tile in the grid once enabled"
  assert_eq "Off" "$(cc tileSub caffeine)" "tile says Off"
  cc pressTile caffeine >/dev/null; sleep 0.3
  assert_eq "true" "$(cc tileChecked caffeine)" "tap turns it on"
  assert_eq "Until off" "$(cc tileSub caffeine)" "on reads Until off (plain toggle, no duration)"
  sleep 0.4; grim -g "$(layer_geom hush-harness-cc)" "$SHOTS/caffeine-tile.png" 2>/dev/null
  assert_file "$SHOTS/caffeine-tile.png" "saved $SHOTS/caffeine-tile.png"
  cc pressTile caffeine >/dev/null; sleep 0.3
  assert_eq "false" "$(cc tileChecked caffeine)" "second tap turns it off"
  local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"
  kill $HPID 2>/dev/null; wait $HPID 2>/dev/null
}
# The live shell: the cup joins the status ring while caffeine is on (the IdleInhibitor sits on the
# island window; a failure to bind it would land in the shell log).
t_ring() {
  shell_restart; sleep 2
  [[ "$(shell_ipc ringGlyph)" != coffee ]] && pass "no cup at rest" || fail "cup at rest"
  act caffeine true >/dev/null
  local i; for i in $(seq 20); do [[ "$(shell_ipc ringGlyph)" == coffee ]] && break; sleep 0.2; done
  assert_eq "true" "$(act caffeineOn)" "Caffeine.on set over IPC"
  assert_eq "coffee" "$(shell_ipc ringGlyph)" "the cup is the status ring's glyph"
  local x y w h r wh top; read -r x y w h r < <(mon_geom "$(shell_ipc islandScreen)"); wh=$(shell_ipc islandSize)
  top=$(shell_ipc settingsGet island.topGap); top=${top:-6}
  sleep 0.5; grim -g "$((x + (w - ${wh%x*}) / 2)),$((y + top)) $wh" "$SHOTS/caffeine-ring.png" 2>/dev/null
  assert_file "$SHOTS/caffeine-ring.png" "saved $SHOTS/caffeine-ring.png"
  act caffeine false >/dev/null; sleep 0.3
  [[ "$(shell_ipc ringGlyph)" != coffee ]] && pass "cup gone once off" || fail "cup stays after off"
}
run_test tile t_tile; run_test ring t_ring; run_test log shell_log_check
finish

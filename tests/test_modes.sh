#!/usr/bin/env bash
# Island modes, fullscreen reveal and OSD overlay, keyboard navigation (plan Task 16).
#   mode switch over IPC settingsSet: overlay reserves nothing and keeps the pill; auto-hide
#   retracts it, a workspace change and the 1 px top strip reveal it, the leave grace hides it;
#   fullscreen kitty: the pill retracts, the strip stays live on the Overlay layer, the pointer at
#   y = 0 reveals the pill within 300 ms and it hides again after the leave grace; an OSD while
#   fullscreen shows on the separate hush-island-osd layer for ~1.1 s;
#   keyboard: Tab puts a visible focus ring on a control, Enter clicks it, Esc closes.
# Timings come from the island's own history stamps (@shown/@hidden, shell wall clock), so IPC
# latency never counts. Every fullscreen check runs on each monitor (skipped beyond one).
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
K=hush-modes-probe
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hush-test-ydotool-modes.sock"; YPID=""
F="$HOME/.config/hush/settings.json"; BAK=$(mktemp)
if [[ -f "$F" ]]; then cp "$F" "$BAK"; HAD=1; else HAD=0; fi
mon_json() { hyprctl monitors -j; }
mons() { mon_json | python3 -c "import json,sys;print(' '.join(m['name'] for m in json.load(sys.stdin)))"; }
focused() { mon_json | python3 -c "import json,sys;print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))"; }
mon_geom() { mon_json | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['name']=='$1')
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']), m['reserved'][1])"; }
ORIG_MON=$(focused); ORIG_WS=$(hyprctl activeworkspace -j | jq .id)
O_DND=$(qs -c hush ipc call notifs dndOn 2>/dev/null)
state() { shell_ipc islandState; }
move() { hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })" >/dev/null; }
yd() { YDOTOOL_SOCKET="$SOCK" ydotool "$@" >/dev/null 2>&1; }
now() { date +%s%3N; }
# Shell time of the first "$1" mark at or after epoch-ms $2 (-1 if none).
mark_at() { shell_ipc islandHistory | python3 -c "
import json,sys
print(next((t for n,t in json.load(sys.stdin) if n=='$1' and t>=$2), -1))"; }
wait_mark() { local i t; for i in $(seq "${3:-40}"); do t=$(mark_at "$1" "$2"); [[ $t != -1 ]] && { echo "$t"; return 0; }; sleep 0.05; done; echo -1; return 1; }
wait_state() { local i; for i in $(seq "${2:-40}"); do [[ "$(state)" == "$1" ]] && return 0; sleep 0.05; done; return 1; }
layer_level() { hyprctl layers -j | python3 -c "
import json,sys
d=json.load(sys.stdin).get('$1',{}).get('levels',{})
print(' '.join(sorted({k for k,v in d.items() for l in v if l['namespace']=='$2'})))"; }
has_layer() { [[ -n "$(layer_level "$1" "$2")" ]]; }
cleanup() {
  hyprctl dispatch "hl.dsp.window.close({ window = \"class:$K\" })" >/dev/null 2>&1
  [[ -n "$YPID" ]] && kill "$YPID" 2>/dev/null; rm -f "$SOCK"
  shell_ipc closeSurface >/dev/null 2>&1
  [[ -n "$O_DND" && "$(qs -c hush ipc call notifs dndOn 2>/dev/null)" != "$O_DND" ]] && qs -c hush ipc call notifs toggleDnd >/dev/null
  if [[ $HAD == 1 ]]; then cp "$BAK" "$F"; else rm -f "$F"; fi; rm -f "$BAK"
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$ORIG_MON\" })" >/dev/null 2>&1
  hyprctl dispatch "hl.dsp.focus({ workspace = $ORIG_WS })" >/dev/null 2>&1
}
trap cleanup EXIT
spawn() { # class: a kitty taken out of any window group (never touches the user's windows)
  hyprctl dispatch "hl.dsp.exec_cmd(\"kitty --class $1\")" >/dev/null
  local i addr grouped; for i in $(seq 30); do hyprctl clients -j | grep -q "\"class\": \"$1\"" && break; sleep 0.2; done
  probe() { hyprctl clients -j | python3 -c "
import json,sys
c=next((c for c in json.load(sys.stdin) if c['class']=='$1'), None)
print(c['address'] if c else '', 1 if c and c['grouped'] else 0)"; }
  read -r addr grouped <<<"$(probe "$1")"
  [[ -z "$addr" ]] && return 1
  if [[ $grouped == 1 ]]; then
    hyprctl dispatch "hl.dsp.window.move({ out_of_group = true, window = \"address:$addr\" })" >/dev/null; sleep 0.2
    read -r addr grouped <<<"$(probe "$1")"; [[ $grouped == 1 ]] && return 1
  fi
  return 0
}
gone() { local i; for i in $(seq 30); do hyprctl clients -j | grep -q "$K" || return 0; sleep 0.2; done; }

shell_alive || { fail "shell not running"; exit 1; }
if pgrep -x hyprlock >/dev/null; then echo "  SKIP session locked (hyprlock takes the pointer)"; exit 0; fi

t_settings() {
  assert_eq "true" "$(shell_ipc settingsGet island.fullscreenReveal)" "island.fullscreenReveal defaults to true"
  assert_eq "true" "$(shell_ipc settingsGet island.fullscreenOsd)" "island.fullscreenOsd defaults to true"
  assert_eq "true" "$(shell_ipc settingsGet island.nowPlayingOsd)" "island.nowPlayingOsd defaults to true"
  assert_eq "1500" "$(shell_ipc settingsGet motion.revealMs)" "motion.revealMs defaults to 1500"
  local f; for f in Island.qml states/Rest.qml states/NotifState.qml states/HoverFace.qml states/MediaState.qml; do
    assert_contains "quickshell/hush/modules/island/$f" "Accessible.role" "$f: interactive items carry Accessible.role"
  done
}
t_modes() {
  local m mx my mw mh r; m=$(focused); read -r mx my mw mh r <<<"$(mon_geom "$m")"
  local cx=$((mx + mw / 2)) away=$((my + mh / 2))
  move "$cx" "$away"; sleep 0.4
  shell_ipc settingsSet island.mode '"overlay"' >/dev/null; sleep 1
  assert_eq "0" "$(mon_geom "$m" | cut -d' ' -f5)" "overlay: reserves nothing"
  [[ "$(state)" != hidden ]] && pass "overlay: the pill stays shown" || fail "overlay: pill hidden"
  has_layer "$m" hush-island-reveal && fail "overlay: reveal strip mapped" || pass "overlay: no reveal strip"

  shell_ipc settingsSet island.mode '"autohide"' >/dev/null
  wait_state hidden 80 && pass "auto-hide: idle pill retracts (after the mode-switch peek)" || fail "auto-hide: state $(state)"
  assert_eq "0" "$(mon_geom "$m" | cut -d' ' -f5)" "auto-hide: reserves nothing"
  assert_eq "3" "$(layer_level "$m" hush-island-reveal)" "auto-hide: reveal strip on the Overlay layer"
  # Workspace change reveals for motion.revealMs, then hides.
  local other=$((ORIG_WS == 9 ? 8 : 9)) t0 ts th
  t0=$(now); hyprctl dispatch "hl.dsp.focus({ workspace = $other })" >/dev/null
  ts=$(wait_mark @shown "$t0" 20)
  [[ $ts != -1 ]] && pass "auto-hide: workspace change reveals the pill ($((ts - t0)) ms)" || fail "auto-hide: no reveal on workspace change"
  th=$(wait_mark @hidden "$t0" 60)
  [[ $th != -1 && $((th - ts)) -ge 1400 && $((th - ts)) -le 1800 ]] && pass "auto-hide: hides $((th - ts)) ms later (revealMs 1500)" || fail "auto-hide: hide after $((th - ts)) ms"
  hyprctl dispatch "hl.dsp.focus({ workspace = $ORIG_WS })" >/dev/null; wait_state hidden 60
  # Top-edge strip reveals; leaving hides after the grace.
  t0=$(now); move "$cx" "$my"
  ts=$(wait_mark @shown "$t0" 20)
  [[ $ts != -1 && $((ts - t0)) -le 300 ]] && pass "auto-hide: pointer at y=0 reveals in $((ts - t0)) ms (<= 300)" || fail "auto-hide: strip reveal $ts"
  t0=$(now); move "$cx" "$away"
  th=$(wait_mark @hidden "$t0" 30)
  [[ $th != -1 && $((th - t0)) -ge 280 && $((th - t0)) -le 600 ]] && pass "auto-hide: hides $((th - t0)) ms after leaving (grace 300)" || fail "auto-hide: hide after leave $th"
  # An OSD (priority >= OSD) reveals the pill.
  shell_ipc osd volume >/dev/null; sleep 0.3
  assert_eq "osd" "$(state)" "auto-hide: an OSD shows the pill"
  wait_state hidden 60 && pass "auto-hide: hides again after the OSD (+ grace)" || fail "auto-hide: state $(state) after OSD"

  shell_ipc settingsSet island.mode '"reserve"' >/dev/null; sleep 1
  assert_eq "40" "$(mon_geom "$m" | cut -d' ' -f5)" "reserve: 40 px again"
  has_layer "$m" hush-island-reveal && fail "reserve: reveal strip left behind" || pass "reserve: no reveal strip"
}
t_fullscreen() {
  local m n=0
  for m in $(mons | tr ' ' '\n' | head -2); do
    n=$((n + 1))
    local mx my mw mh r; read -r mx my mw mh r <<<"$(mon_geom "$m")"
    local cx=$((mx + mw / 2)) away=$((my + mh / 2)) t0 ts th
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$m\" })" >/dev/null; move "$cx" "$away"; sleep 0.5
    spawn $K || { fail "$m: could not open the probe kitty"; continue; }
    hyprctl dispatch "hl.dsp.window.fullscreen({ action = \"toggle\", window = \"class:$K\" })" >/dev/null
    wait_state hidden 40 && pass "$m: fullscreen kitty retracts the pill" || fail "$m: state $(state) under fullscreen"
    assert_eq "3" "$(layer_level "$m" hush-island-reveal)" "$m: top strip stays live on the Overlay layer"
    t0=$(now); move "$cx" "$my"
    ts=$(wait_mark @shown "$t0" 20)
    [[ $ts != -1 && $((ts - t0)) -le 300 ]] && pass "$m: pointer at y=0 reveals the pill over fullscreen in $((ts - t0)) ms (<= 300)" \
      || fail "$m: no reveal from the top edge ($ts, state $(state))"
    [[ "$(state)" != hidden ]] && pass "$m: islandState left hidden ($(state))" || fail "$m: islandState still hidden"
    assert_eq "3" "$(layer_level "$m" hush-island)" "$m: island on the Overlay layer above the fullscreen window"
    grim -o "$m" "$HOME/.cache/hush/evidence/fullscreen-reveal-$m.png" 2>/dev/null
    t0=$(now); move "$cx" "$away"
    th=$(wait_mark @hidden "$t0" 30)
    [[ $th != -1 && $((th - t0)) -ge 280 && $((th - t0)) -le 600 ]] && pass "$m: hides $((th - t0)) ms after leaving (grace 300)" || fail "$m: hide after leave $th"
    # OSD while fullscreen: the separate overlay layer, for the 1.1 s hold; the island stays retracted.
    t0=$(now); shell_ipc osd volume >/dev/null; sleep 0.25
    assert_eq "true" "$(shell_ipc osdOverlayVisible)" "$m: OSD shows on the fullscreen overlay"
    assert_eq "hidden" "$(state)" "$m: the island itself stays retracted"
    assert_eq "3" "$(layer_level "$m" hush-island-osd)" "$m: hush-island-osd layer mapped on Overlay"
    grim -o "$m" "$HOME/.cache/hush/evidence/fullscreen-osd-$m.png" 2>/dev/null
    local i; for i in $(seq 40); do [[ "$(shell_ipc osdOverlayVisible)" == false ]] && break; sleep 0.05; done
    local dt=$(( $(now) - t0 ))
    [[ "$(shell_ipc osdOverlayVisible)" == false && $dt -ge 1000 && $dt -le 1700 ]] && pass "$m: overlay gone after ~$dt ms (hold 1100)" || fail "$m: overlay after $dt ms"
    sleep 0.3; has_layer "$m" hush-island-osd && fail "$m: OSD layer left mapped" || pass "$m: OSD layer unmapped"
    hyprctl dispatch "hl.dsp.window.fullscreen({ action = \"toggle\", window = \"class:$K\" })" >/dev/null
    wait_state rest 40 && pass "$m: pill returns after fullscreen" || fail "$m: state $(state) after fullscreen"
    has_layer "$m" hush-island-reveal && fail "$m: strip left after fullscreen (reserve mode)" || pass "$m: strip gone after fullscreen"
    hyprctl dispatch "hl.dsp.window.close({ window = \"class:$K\" })" >/dev/null; gone
  done
  (( n < 2 )) && pass "one monitor: second-monitor fullscreen checks skipped"
}
t_keyboard() {
  if ! [[ -w /dev/uinput ]] || ! command -v ydotoold >/dev/null; then pass "no writable uinput/ydotoold: keyboard checks skipped"; return; fi
  rm -f "$SOCK"; ydotoold -p "$SOCK" >/dev/null 2>&1 & YPID=$!; sleep 1.5
  local m mx my mw mh r; m=$(focused); read -r mx my mw mh r <<<"$(mon_geom "$m")"
  move $((mx + mw / 2)) $((my + mh / 2)); sleep 0.3
  # Control center: Tab focuses a control with a visible ring; Tab again moves on; arrows move.
  shell_ipc openSurface expanded >/dev/null; wait_state expanded; sleep 0.8
  assert_eq "" "$(shell_ipc islandFocus)" "no focus ring before the keyboard is used"
  yd key 15:1 15:0; sleep 0.2
  local f1 f2; f1=$(shell_ipc islandHistory | grep -c '@nav')
  [[ -n "$(shell_ipc islandFocus)" ]] && pass "Tab focuses a control ($(shell_ipc islandFocus))" || fail "Tab focused nothing"
  assert_eq "true" "$(shell_ipc islandFocusRing)" "the focus ring is visible"
  grim -o "$m" "$HOME/.cache/hush/evidence/keyboard-focus-ring.png" 2>/dev/null
  yd key 15:1 15:0; sleep 0.15; yd key 108:1 108:0; sleep 0.15; yd key 106:1 106:0; sleep 0.15
  f2=$(shell_ipc islandHistory | grep -o '@nav' | wc -l)
  [[ $f2 -ge 3 ]] && pass "Tab and the arrows move the focus ($f2 moves)" || fail "focus moved $f2 times"
  yd key 1:1 1:0; wait_state rest && pass "Esc closes the control center" || fail "Esc left $(state)"
  # Notification center, empty: the DND button is the only control; Enter clicks it.
  shell_ipc clearNotifications >/dev/null
  shell_ipc openSurface notifCenter >/dev/null; wait_state notifCenter; sleep 0.8
  local d0; d0=$(qs -c hush ipc call notifs dndOn)
  yd key 15:1 15:0; sleep 0.15; yd key 28:1 28:0; sleep 0.3
  [[ "$(qs -c hush ipc call notifs dndOn)" != "$d0" ]] && pass "Enter clicks the focused control (DND toggled)" || fail "Enter did nothing"
  yd key 57:1 57:0; sleep 0.3
  assert_eq "$d0" "$(qs -c hush ipc call notifs dndOn)" "Space clicks it again (DND restored)"
  yd key 1:1 1:0; wait_state rest && pass "Esc closes the notification center" || fail "Esc left $(state)"
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "settings" t_settings; run_test "modes" t_modes; run_test "fullscreen" t_fullscreen
run_test "keyboard" t_keyboard; run_test "log" t_log
finish

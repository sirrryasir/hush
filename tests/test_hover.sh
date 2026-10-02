#!/usr/bin/env bash
# Island v2 hover and input (design 2.2). The pointer is moved with hl.dsp.cursor.move and clicks,
# keys and the wheel go through a private ydotoold (skipped without a writable uinput). Timings come
# from the island's own history (state changes and pointer crossings stamped in the shell), so IPC
# latency never counts:
#   pointer onto the pill -> hover face (320x44) within 200 ms, not before the 120 ms dwell;
#   pointer away -> rest no sooner than the 300 ms grace;
#   pointer parked on the pill during an OSD -> hover within 350 ms of the OSD ending (re-arm);
#   a click 100 ms after the control center opened, on its DND button, does nothing (arming);
#   right click -> notification center, middle -> media, Esc and a click outside close, the
#   wheel changes the volume with the OSD inside the pill.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hush-test-ydotool-hover.sock"; YPID=""
F="$HOME/.config/hush/settings.json"; BAK=$(mktemp)
if [[ -f "$F" ]]; then cp "$F" "$BAK"; HAD=1; else HAD=0; fi
O_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); O_MUTE=0; [[ "$O_VOL" == *MUTED* ]] && O_MUTE=1; O_VOL=$(awk '{print $2}' <<<"$O_VOL")
O_DND=$(qs -c hush ipc call notifs dndOn 2>/dev/null)
read -r MX MY MW MH < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']))")
TOP=$(shell_ipc settingsGet island.topGap 2>/dev/null || echo 6)
PX=$((MX + MW / 2)); PY=$((MY + TOP + 18)); AX=$PX; AY=$((MY + MH / 2))
cleanup() {
  move "$AX" "$AY"
  [[ -n "$YPID" ]] && kill "$YPID" 2>/dev/null; rm -f "$SOCK"
  shell_ipc closeSurface >/dev/null 2>&1
  [[ -n "$O_VOL" ]] && { wpctl set-volume @DEFAULT_AUDIO_SINK@ "$O_VOL"; wpctl set-mute @DEFAULT_AUDIO_SINK@ "$O_MUTE"; }
  [[ -n "$O_DND" && "$(dnd)" != "$O_DND" ]] && qs -c hush ipc call notifs toggleDnd >/dev/null
  if [[ $HAD == 1 ]]; then cp "$BAK" "$F"; else rm -f "$F"; fi; rm -f "$BAK"
}
trap cleanup EXIT
move() { hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })" >/dev/null; }
yd() { YDOTOOL_SOCKET="$SOCK" ydotool "$@" >/dev/null 2>&1; }
dnd() { qs -c hush ipc call notifs dndOn; }
state() { shell_ipc islandState; }
wait_state() { local i; for i in $(seq 40); do [[ "$(state)" == "$1" ]] && return 0; sleep 0.05; done; return 1; }
# ms from the last "$1" mark to the first "$2" mark after it in the island history (-1 if absent).
gap() { shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin); a=None
for i,(n,t) in enumerate(h):
  if n=='$1': a=(i,t)
b=next((t for n,t in h[a[0]+1:] if n=='$2'), None) if a else None
print(-1 if b is None else b-a[1])"; }
# ms from the end of the last OSD (its first following state change) to the next hover.
osd_gap() { shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin)
i=max((i for i,(n,t) in enumerate(h) if n=='osd'), default=None)
end=next(((j,t) for j,(n,t) in enumerate(h) if i is not None and j>i and not n.startswith('@')), None)
hv=next((t for n,t in h[end[0]:] if n=='hover'), None) if end else None
print(-1 if hv is None else hv-end[1])"; }

shell_alive || { fail "shell not running"; exit 1; }
if pgrep -x hyprlock >/dev/null; then echo "  SKIP session locked (hyprlock takes the pointer)"; exit 0; fi

t_files() {
  assert_file quickshell/hush/modules/island/states/HoverFace.qml "hover face exists"
  assert_contains quickshell/hush/modules/island/Island.qml "HoverHandler" "island hover uses a HoverHandler"
  assert_eq "120" "$(shell_ipc settingsGet motion.hoverDwellMs)" "dwell from settings"
  assert_eq "300" "$(shell_ipc settingsGet motion.leaveGraceMs)" "grace from settings"
  assert_eq "500" "$(shell_ipc settingsGet motion.armMs)" "arming window from settings"
}
t_hover() {
  shell_ipc closeSurface >/dev/null; move "$AX" "$AY"; sleep 0.6
  for _ in $(seq 20); do [[ "$(state)" == rest ]] && break; sleep 0.5; done
  move "$PX" "$PY"
  wait_state hover && pass "pointer on the pill opens the hover face" || fail "no hover face (state $(state))"
  local g; g=$(gap @in hover)
  [[ $g -ge 110 && $g -le 200 ]] && pass "hover after $g ms (dwell 120, <= 200)" || fail "hover after $g ms"
  local i; for i in $(seq 20); do [[ "$(shell_ipc islandSize)" == "320x44" ]] && break; sleep 0.05; done
  assert_eq "320x44" "$(shell_ipc islandSize)" "hover face is 320x44"
  # The grace is read from the shell's own stamps (an IPC poll at 150 ms raced the 300 ms grace).
  move "$AX" "$AY"
  wait_state rest
  g=$(gap @out "$(state)")
  [[ $g -ge 300 && $g -le 450 ]] && pass "back to $(state) $g ms after leaving (grace 300)" || fail "left hover after $g ms"
}
t_rearm() {
  move "$AX" "$AY"; sleep 0.6
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30; sleep 1.5
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-; sleep 0.15
  assert_eq "osd" "$(state)" "volume change shows the OSD"
  move "$PX" "$PY"; sleep 0.2
  assert_eq "osd" "$(state)" "OSD stays while the pointer rests on it"
  wait_state hover; sleep 0.3; wait_state hover
  local g; g=$(osd_gap)
  [[ $g -ge 0 && $g -le 350 ]] && pass "hover re-arms $g ms after the OSD ends (<= 350)" || fail "re-arm gap $g ms (state $(state))"
  move "$AX" "$AY"; sleep 0.6
}
t_clicks() {
  if ! [[ -w /dev/uinput ]] || ! command -v ydotoold >/dev/null; then pass "no writable uinput/ydotoold: click checks skipped"; return; fi
  rm -f "$SOCK"; ydotoold -p "$SOCK" >/dev/null 2>&1 & YPID=$!; sleep 1.5
  # Where the DND button sits once the control center is open (window-local -> global).
  shell_ipc toggleControlCenter >/dev/null; sleep 1
  local pos bx by; pos=$(shell_ipc islandControl dndToggle); shell_ipc closeSurface >/dev/null; sleep 0.8
  [[ -n "$pos" ]] || { fail "no dndToggle in the control center"; return; }
  bx=$((MX + ${pos% *})); by=$((MY + ${pos#* }))
  local d0; d0=$(dnd)
  move "$bx" "$by"; sleep 0.3
  shell_ipc toggleControlCenter >/dev/null; sleep 0.1; yd click 0xC0; sleep 0.3
  assert_eq "$d0" "$(dnd)" "click 100 ms after the control center opened does nothing (arming)"
  assert_eq "expanded" "$(state)" "the early click did not close the control center"
  sleep 0.5; yd click 0xC0; sleep 0.3
  [[ "$(dnd)" != "$d0" ]] && pass "the same button works once armed" || fail "armed click did not toggle DND"
  yd click 0xC0; sleep 0.3
  assert_eq "$d0" "$(dnd)" "DND restored"
  # Outside-click arming (same 500 ms as buttons): a click off the pill 100 ms after the control
  # center opened does not close it; one after the window does.
  shell_ipc closeSurface >/dev/null; sleep 0.6; move "$AX" "$AY"; sleep 0.3
  shell_ipc toggleControlCenter >/dev/null; sleep 0.1; yd click 0xC0; sleep 0.3
  assert_eq "expanded" "$(state)" "click outside 100 ms after opening does not close (arming)"
  sleep 0.4; yd click 0xC0; wait_state rest
  assert_eq "rest" "$(state)" "click outside once armed closes the control center"
  shell_ipc toggleControlCenter >/dev/null; sleep 0.8
  # Esc closes; a click outside closes.
  yd key 1:1 1:0; wait_state rest
  [[ "$(state)" == rest ]] && pass "Esc closes the control center" || fail "Esc left state $(state)"
  move "$PX" "$PY"; sleep 0.05; yd click 0xC1; wait_state notifCenter
  assert_eq "notifCenter" "$(state)" "right click opens the notification center"
  move "$AX" "$AY"; sleep 0.6; yd click 0xC0; sleep 0.6
  [[ "$(state)" == rest ]] && pass "click outside closes the notification center" || fail "click outside left $(state)"
  move "$PX" "$PY"; sleep 0.05; yd click 0xC2; wait_state mediaSurface
  assert_eq "mediaSurface" "$(state)" "middle click opens the media surface"
  shell_ipc closeSurface >/dev/null; move "$AX" "$AY"; sleep 0.8
  move "$PX" "$PY"; sleep 0.05; yd click 0xC0; wait_state expanded
  assert_eq "expanded" "$(state)" "left click opens the control center"
  shell_ipc closeSurface >/dev/null; move "$AX" "$AY"; sleep 0.8
  # Wheel on the pill: volume with the OSD in the pill.
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30; sleep 1.5
  local v0 v1; v0=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}')
  move "$PX" "$PY"; sleep 0.05; yd mousemove -w -x 0 -y 1; sleep 0.2
  v1=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}')
  [[ "$v1" != "$v0" ]] && pass "wheel on the pill changes the volume ($v0 -> $v1)" || fail "wheel left volume at $v0"
  assert_eq "osd" "$(state)" "wheel shows the OSD in the pill"
  move "$AX" "$AY"; sleep 1.6
  # Media at rest is the activity circle (no capsule state); clicking it opens the media surface.
  if python3 -c 'import dbus, gi' 2>/dev/null; then
    python3 tests/fakempris.py & local fp=$!; sleep 3
    assert_eq "rest" "$(state)" "a playing player keeps the island at rest (now-playing card has ended)"
    assert_eq "true" "$(shell_ipc islandControlVisible activityCircle)" "the activity circle shows at rest"
    pos=$(shell_ipc islandControl activityCircle)
    move $((MX + ${pos% *})) $((MY + ${pos#* })); sleep 0.05; yd click 0xC0; wait_state mediaSurface
    assert_eq "mediaSurface" "$(state)" "clicking the activity circle opens the media surface"
    shell_ipc closeSurface >/dev/null; move "$AX" "$AY"; kill "$fp" 2>/dev/null; wait "$fp" 2>/dev/null; sleep 0.8
  else pass "no dbus-python/PyGObject: activity circle click skipped"; fi
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "files" t_files; run_test "hover" t_hover; run_test "rearm" t_rearm; run_test "clicks" t_clicks; run_test "log" t_log
finish

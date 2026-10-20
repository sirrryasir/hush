#!/usr/bin/env bash
# Island hover and input. The pointer is moved with hl.dsp.cursor.move and clicks,
# keys and the wheel go through tests/lib/input.sh (ydotoold live, virtual devices in the sandbox). Timings come
# from the island's own history (state changes and pointer crossings stamped in the shell), so IPC
# latency never counts:
#   pointer onto the pill -> hover face (320x44) within 200 ms, not before the 120 ms dwell;
#   pointer away -> rest no sooner than the 300 ms grace;
#   pointer parked on the pill during an OSD -> hover within 350 ms of the OSD ending (re-arm);
#   a click 100 ms after the control center opened, on its DND button, does nothing (arming);
#   right click -> notification center, middle -> media, Esc and a click outside close, the
#   wheel changes the volume with the OSD inside the pill.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
shell_settings_save
O_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); O_MUTE=0; [[ "$O_VOL" == *MUTED* ]] && O_MUTE=1; O_VOL=$(awk '{print $2}' <<<"$O_VOL")
O_DND=$(qs -c hush ipc call notifs dndOn 2>/dev/null)
read -r MX MY MW MH < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']))")
TOP=$(shell_ipc settingsGet island.topGap 2>/dev/null || echo 6)
PX=$((MX + MW / 2)); PY=$((MY + TOP + 18)); AX=$PX; AY=$((MY + MH / 2))
cleanup() {
  input_move "$AX" "$AY"
  input_stop
  shell_ipc closeSurface >/dev/null 2>&1
  [[ -n "$O_VOL" ]] && { wpctl set-volume @DEFAULT_AUDIO_SINK@ "$O_VOL"; wpctl set-mute @DEFAULT_AUDIO_SINK@ "$O_MUTE"; }
  [[ -n "$O_DND" && "$(dnd)" != "$O_DND" ]] && qs -c hush ipc call notifs toggleDnd >/dev/null
  shell_settings_restore
}
trap cleanup EXIT
dnd() { qs -c hush ipc call notifs dndOn; }
# ms from the end of the last OSD (its first following state change) to the next hover.
osd_gap() { shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin)
i=max((i for i,(n,t) in enumerate(h) if n=='osd'), default=None)
end=next(((j,t) for j,(n,t) in enumerate(h) if i is not None and j>i and not n.startswith('@')), None)
hv=next((t for n,t in h[end[0]:] if n=='hover'), None) if end else None
print(-1 if hv is None else hv-end[1])"; }

shell_alive || { fail "shell not running"; exit 1; }
if session_pgrep -x hyprlock >/dev/null; then echo "  SKIP session locked (hyprlock takes the pointer)"; exit 0; fi

t_files() {
  assert_file quickshell/hush/modules/island/states/HoverFace.qml "hover face exists"
  assert_contains quickshell/hush/modules/island/Island.qml "HoverHandler" "island hover uses a HoverHandler"
  assert_eq "120" "$(shell_ipc settingsGet motion.hoverDwellMs)" "dwell from settings"
  assert_eq "300" "$(shell_ipc settingsGet motion.leaveGraceMs)" "grace from settings"
  assert_eq "500" "$(shell_ipc settingsGet motion.armMs)" "arming window from settings"
}
t_hover() {
  shell_ipc closeSurface >/dev/null; input_move "$AX" "$AY"; sleep 0.6
  for _ in $(seq 20); do [[ "$(shell_state)" == rest ]] && break; sleep 0.5; done
  input_move "$PX" "$PY"
  shell_wait_state hover && pass "pointer on the pill opens the hover face" || fail "no hover face (state $(shell_state))"
  local g; g=$(history_gap @in hover)
  [[ $g -ge 110 && $g -le 200 ]] && pass "hover after $g ms (dwell 120, <= 200)" || fail "hover after $g ms"
  local i; for i in $(seq 30); do [[ "$(shell_ipc islandSize)" == "320x44" ]] && break; sleep 0.1; done # the spring settles within ~3 s under load
  assert_eq "320x44" "$(shell_ipc islandSize)" "hover face is 320x44"
  assert_eq "true" "$(shell_ipc islandControlVisible hoverWifi)" "hover face shows the Wi-Fi state"
  if [[ "$(shell_ipc batteryPresent)" == "true" ]]; then
    assert_eq "true" "$(shell_ipc islandControlVisible hoverBattery)" "hover face shows the battery glyph"
  fi
  # The grace is read from the shell's own stamps (an IPC poll at 150 ms raced the 300 ms grace).
  input_move "$AX" "$AY"
  shell_wait_state rest
  g=$(history_gap @out "$(shell_state)")
  [[ $g -ge 300 && $g -le 450 ]] && pass "back to $(shell_state) $g ms after leaving (grace 300)" || fail "left hover after $g ms"
}
t_rearm() {
  input_move "$AX" "$AY"; sleep 0.6
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30; sleep 1.5
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-; sleep 0.15
  assert_eq "osd" "$(shell_state)" "volume change shows the OSD"
  input_move "$PX" "$PY"; sleep 0.2
  assert_eq "osd" "$(shell_state)" "OSD stays while the pointer rests on it"
  shell_wait_state hover; sleep 0.3; shell_wait_state hover
  local g; g=$(osd_gap)
  [[ $g -ge 0 && $g -le 350 ]] && pass "hover re-arms $g ms after the OSD ends (<= 350)" || fail "re-arm gap $g ms (state $(shell_state))"
  input_move "$AX" "$AY"; sleep 0.6
}
t_clicks() {
  input_start || { pass "$(input_why): click checks skipped"; return; }
  # Where the DND button sits once the control center is open (window-local -> global).
  shell_ipc toggleControlCenter >/dev/null; sleep 1
  local pos bx by; pos=$(shell_ipc islandControl dndToggle); shell_ipc closeSurface >/dev/null; sleep 0.8
  [[ -n "$pos" ]] || { fail "no dndToggle in the control center"; return; }
  bx=$((MX + ${pos% *})); by=$((MY + ${pos#* }))
  local d0; d0=$(dnd)
  input_move "$bx" "$by"; sleep 0.3
  shell_ipc toggleControlCenter >/dev/null; sleep 0.1; input_click; sleep 0.3
  assert_eq "$d0" "$(dnd)" "click 100 ms after the control center opened does nothing (arming)"
  assert_eq "expanded" "$(shell_state)" "the early click did not close the control center"
  sleep 0.5; input_click; sleep 0.3
  [[ "$(dnd)" != "$d0" ]] && pass "the same button works once armed" || fail "armed click did not toggle DND"
  input_click; sleep 0.3
  assert_eq "$d0" "$(dnd)" "DND restored"
  # Outside-click arming (same 500 ms as buttons): a click off the pill 100 ms after the control
  # center opened does not close it; one after the window does.
  shell_ipc closeSurface >/dev/null; sleep 0.6; input_move "$AX" "$AY"; sleep 0.3
  shell_ipc toggleControlCenter >/dev/null; sleep 0.1; input_click; sleep 0.3
  assert_eq "expanded" "$(shell_state)" "click outside 100 ms after opening does not close (arming)"
  sleep 0.4; input_click; shell_wait_state rest
  assert_eq "rest" "$(shell_state)" "click outside once armed closes the control center"
  shell_ipc toggleControlCenter >/dev/null; sleep 0.8
  # Esc closes; a click outside closes.
  input_key Escape; shell_wait_state rest
  [[ "$(shell_state)" == rest ]] && pass "Esc closes the control center" || fail "Esc left state $(shell_state)"
  input_move "$PX" "$PY"; sleep 0.05; input_click right; shell_wait_state notifCenter
  assert_eq "notifCenter" "$(shell_state)" "right click opens the notification center"
  input_move "$AX" "$AY"; sleep 0.6; input_click; sleep 0.6
  [[ "$(shell_state)" == rest ]] && pass "click outside closes the notification center" || fail "click outside left $(shell_state)"
  input_move "$PX" "$PY"; sleep 0.05; input_click middle; shell_wait_state mediaSurface
  assert_eq "mediaSurface" "$(shell_state)" "middle click opens the media surface"
  shell_ipc closeSurface >/dev/null; input_move "$AX" "$AY"; sleep 0.8
  input_move "$PX" "$PY"; sleep 0.05; input_click; shell_wait_state expanded
  assert_eq "expanded" "$(shell_state)" "left click opens the control center"
  shell_ipc closeSurface >/dev/null; input_move "$AX" "$AY"; sleep 0.8
  # Wheel on the pill: volume with the OSD in the pill.
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30; sleep 1.5
  local v0 v1; v0=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}')
  input_move "$PX" "$PY"; sleep 0.05; input_wheel 1; sleep 0.2
  v1=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}')
  [[ "$v1" != "$v0" ]] && pass "wheel on the pill changes the volume ($v0 -> $v1)" || fail "wheel left volume at $v0"
  assert_eq "osd" "$(shell_state)" "wheel shows the OSD in the pill"
  input_move "$AX" "$AY"; sleep 1.6
  # island.scroll = brightness: the wheel moves the backlight (restored after) with the OSD.
  if command -v brightnessctl >/dev/null && ls "${HUSH_BACKLIGHT_DIR:-/sys/class/backlight}"/*/brightness >/dev/null 2>&1; then
    local sj="$CFG/hush/settings.json" sbak="" b0 b1 braw; [[ -f "$sj" ]] && sbak=$(cat "$sj")
    braw=$(brightnessctl -q g); brightnessctl -q s 50%; sleep 0.3; b0=$(brightnessctl -q g)
    shell_ipc settingsSet island.scroll '"brightness"' >/dev/null; sleep 0.5
    input_move "$PX" "$PY"; sleep 0.05; input_wheel 1; sleep 0.4
    b1=$(brightnessctl -q g)
    [[ "$b1" != "$b0" ]] && pass "scroll=brightness: wheel changes the backlight ($b0 -> $b1)" || fail "scroll=brightness: backlight stayed $b0"
    assert_eq "osd" "$(shell_state)" "brightness wheel shows the OSD"
    input_move "$AX" "$AY"; sleep 1.6
    shell_ipc settingsSet island.scroll '"volume"' >/dev/null; sleep 0.3
    if [[ -n "$sbak" ]]; then printf '%s\n' "$sbak" >"$sj"; else rm -f "$sj"; fi
    brightnessctl -q s "$braw"
  else pass "no backlight: scroll=brightness skipped"; fi
  # Media at rest is the activity circle; clicking it opens the media surface.
  if python3 -c 'import dbus, gi' 2>/dev/null; then
    python3 tests/fakempris.py & local fp=$!; sleep 3
    assert_eq "rest" "$(shell_state)" "a playing player keeps the island at rest (now-playing card has ended)"
    assert_eq "true" "$(shell_ipc islandControlVisible activityCircle)" "the activity circle shows at rest"
    pos=$(shell_ipc islandControl activityCircle)
    input_move $((MX + ${pos% *})) $((MY + ${pos#* })); sleep 0.05; input_click; shell_wait_state mediaSurface
    assert_eq "mediaSurface" "$(shell_state)" "clicking the activity circle opens the media surface"
    shell_ipc closeSurface >/dev/null; input_move "$AX" "$AY"; kill "$fp" 2>/dev/null; wait "$fp" 2>/dev/null; sleep 0.8
  else pass "no dbus-python/PyGObject: activity circle click skipped"; fi
}
t_overview() {
  # GloView overview over IPC (toggled twice so the screen is left as it was); no errors either way.
  shell_ipc overview >/dev/null; sleep 0.8; shell_ipc overview >/dev/null; sleep 0.6
  local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "overview IPC runs without errors" || fail "overview: $e"
}
# Keyboard layout chip, in its own harness with a fake hyprctl: one layout shows nothing; two show
# the active layout's short name, and a tap runs `hyprctl switchxkblayout <device> next`.
t_kbd() {
  local D; D=$(mktemp -d); local HC=(qs -p "$PWD/tests/harness/hover.qml") i
  cat >"$D/hyprctl" <<EOF2
#!/bin/sh
echo "\$*" >>"$D/log"
case "\$*" in
  *devices*) cat "$D/devices" ;;
esac
exit 0
EOF2
  chmod +x "$D/hyprctl"
  kbd_json() { printf '{"keyboards":[{"name":"at-kbd","main":true,"layout":"%s","active_keymap":"%s"}]}\n' "$1" "$2" >"$D/devices"; }
  kbd_json us "English (US)"
  HUSH_ROOT="$PWD" QS_DISABLE_CRASH_HANDLER=1 PATH="$D:$PATH" "${HC[@]}" -n >"$D/qs.log" 2>&1 & local pid=$!
  hv() { local o; for i in 1 2 3 4 5 6 7 8; do o=$("${HC[@]}" ipc call hover "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
  hv kbdShown >/dev/null; sleep 1
  assert_eq "false" "$(hv kbdShown)" "one layout: no keyboard chip"
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  kbd_json us,de "German"
  HUSH_ROOT="$PWD" QS_DISABLE_CRASH_HANDLER=1 PATH="$D:$PATH" "${HC[@]}" -n >"$D/qs.log" 2>&1 & pid=$!
  hv kbdShown >/dev/null
  for i in $(seq 20); do [[ "$(hv kbdShown)" == true ]] && break; sleep 0.3; done
  assert_eq "true" "$(hv kbdShown)" "two layouts: the keyboard chip shows"
  assert_eq "de" "$(hv kbdText)" "chip text is the active layout's two letters"
  hv kbdTap >/dev/null; sleep 0.5
  assert_contains "$D/log" "switchxkblayout at-kbd next" "tap runs hyprctl switchxkblayout <device> next"
  kill $pid 2>/dev/null; wait $pid 2>/dev/null; rm -rf "$D"
}
run_test "files" t_files; run_test "hover" t_hover; run_test "rearm" t_rearm; run_test "clicks" t_clicks; run_test "overview" t_overview; run_test "kbd" t_kbd; run_test "log" shell_log_check
finish

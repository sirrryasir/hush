#!/usr/bin/env bash
# Control-center surface in its own harness (tests/harness/cc.qml); never touches the live shell.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
# Bluetooth: a stub rfkill on PATH (logs its arguments, reports bluetooth soft-blocked until
# "unblock") and HUSH_BT_NO_ADAPTER=1, so the tile exercises the missing-adapter path.
STUB=$(mktemp -d); echo blocked >"$STUB/state"
cat >"$STUB/rfkill" <<EOF
#!/bin/sh
echo "\$*" >>"$STUB/log"
case "\$1" in
  unblock) echo unblocked >"$STUB/state" ;;
  -J) printf '{"rfkilldevices":[{"id":0,"type":"bluetooth","device":"hci0","soft":"%s","hard":"unblocked"}]}\n' "\$(cat "$STUB/state")" ;;
esac
EOF
chmod +x "$STUB/rfkill"
LOG=$(mktemp); PATH="$STUB:$PATH" HUSH_BT_NO_ADAPTER=1 "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
t_up() {
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  assert_eq "main" "$(cc page)" "harness starts on the main page"
  hyprctl layers -j | grep -q '"namespace": "hush-harness-cc"' && pass "harness layer mapped" || fail "harness layer missing"
}
t_pages() {
  cc openWifi >/dev/null; assert_eq "wifi" "$(cc page)" "openWifi opens the Wi-Fi page"
  assert_eq "true" "$(cc back)" "back() leaves a sub-page"; assert_eq "main" "$(cc page)" "back lands on main"
  assert_eq "false" "$(cc back)" "back() on main reports nothing to do"
  cc openBluetooth >/dev/null; assert_eq "bluetooth" "$(cc page)" "openBluetooth opens the device page"
  cc back >/dev/null; assert_eq "main" "$(cc page)" "back from Bluetooth"
  cc pressWallpapers >/dev/null; assert_eq "1" "$(cc wallRequests)" "Wallpapers emits openWallpapers"
}
t_networks() {
  local n; n=$(nmcli -t -f SSID dev wifi list 2>/dev/null | grep -c .)
  if (( n == 0 )); then pass "no networks visible: list check skipped"; return; fi
  cc openWifi >/dev/null; local i c=0; for i in $(seq 20); do c=$(cc networkCount); (( c > 0 )) && break; sleep 0.5; done
  (( c > 0 )) && pass "network list non-empty ($c)" || fail "network list empty though nmcli shows $n"
  cc back >/dev/null
}
# Keyboard sliders: Left/Right = one step, Shift = ten, committed. The harness stands in for the island's
# navigator (live wiring: Island.navAdjust); keys go through a private ydotoold (skipped without uinput).
# The sink volume is real, so it is saved and restored.
t_keys() {
  if ! [[ -w /dev/uinput ]] || ! command -v ydotoold >/dev/null || ! command -v wpctl >/dev/null; then pass "no writable uinput/ydotoold/wpctl: keyboard slider check skipped"; return; fi
  local sock="${XDG_RUNTIME_DIR:-/tmp}/hush-test-ydotool-cc.sock" ypid ov om
  ov=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || { pass "no default sink: keyboard slider check skipped"; return; }
  om=0; [[ "$ov" == *MUTED* ]] && om=1; ov=$(awk '{print $2}' <<<"$ov")
  rm -f "$sock"; ydotoold -p "$sock" >/dev/null 2>&1 & ypid=$!; sleep 1.5
  yd() { YDOTOOL_SOCKET="$sock" ydotool "$@" >/dev/null 2>&1; }
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.5; sleep 0.6
  assert_eq "true" "$(cc armSlider)" "the volume slider exposes stepAdjust"
  local g x y w h; g=$(hyprctl layers -j | python3 -c "
import json,sys
for o in json.load(sys.stdin).values():
  for lv in o['levels'].values():
    for l in lv:
      if l['namespace']=='hush-harness-cc': print(l['x'],l['y'],l['w'],l['h'])")
  read -r x y w h <<<"$g"
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((x + w / 2)), y = $((y + h - 4)) })" >/dev/null; sleep 0.2
  YDOTOOL_SOCKET="$sock" ydotool click 0xC0 >/dev/null 2>&1; sleep 0.3
  local v0 v1; v0=$(cc sliderValue)
  yd key 106:1 106:0; sleep 0.5
  assert_eq "1" "$(cc adjusts)" "Right reaches the slider"; assert_eq "1" "$(cc lastStep)" "Right is one step"
  v1=$(cc sliderValue)
  python3 -c "import sys; sys.exit(0 if abs(($v1)-($v0)-0.05)<0.011 else 1)" && pass "Right raised the volume by one step (0.05: $v0 -> $v1)" || fail "volume $v0 -> $v1 after Right"
  yd key 105:1 105:0; sleep 0.5
  assert_eq "-1" "$(cc lastStep)" "Left is minus one step"
  yd key 42:1 105:1 105:0 42:0; sleep 0.5
  assert_eq "-10" "$(cc lastStep)" "Shift+Left is ten steps"
  assert_eq "0.00" "$(cc sliderValue)" "the value clamps at 0"
  assert_eq "3" "$(cc adjusts)" "every key committed once"
  kill "$ypid" 2>/dev/null; rm -f "$sock"
  wpctl set-volume @DEFAULT_AUDIO_SINK@ "$ov"; wpctl set-mute @DEFAULT_AUDIO_SINK@ "$om"
}
t_bt() {
  local i s=""; for i in $(seq 10); do s=$(cc btSubtitle | tr -d '"'); [[ "$s" == "Blocked by rfkill" ]] && break; sleep 0.5; done
  assert_eq "Blocked by rfkill" "$s" "Bluetooth tile says Blocked by rfkill"
  assert_eq "true" "$(cc btBlocked)" "Bt.blocked with no adapter"
  cc pressBtTile >/dev/null
  for i in $(seq 10); do grep -qx 'unblock bluetooth' "$STUB/log" 2>/dev/null && break; sleep 0.3; done
  grep -qx 'unblock bluetooth' "$STUB/log" && pass "tile toggle ran rfkill unblock bluetooth" || fail "stub rfkill not called to unblock: $(cat "$STUB/log" 2>/dev/null)"
  for i in $(seq 16); do s=$(cc btSubtitle | tr -d '"'); [[ "$s" == "No adapter" ]] && break; sleep 0.5; done
  assert_eq "No adapter" "$s" "after the unblock the tile no longer claims rfkill"
  grep -qx 'block bluetooth' "$STUB/log" && fail "Hush ran rfkill block" || pass "never runs rfkill block"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test up t_up; run_test pages t_pages; run_test networks t_networks; run_test keys t_keys; run_test bt t_bt; run_test log t_log
finish

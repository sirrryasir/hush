#!/usr/bin/env bash
# Control-center surface in its own harness (tests/harness/cc.qml); never touches the live shell.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/lib/input.sh"
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
# Wi-Fi: a stub nmcli (logs every call to nmlog). HomeNet is active and saved, "Saved Net" saved,
# Neighbour secured without a profile (password "right" joins, anything else is refused), CafeOpen open.
cat >"$STUB/nmcli" <<EOF
#!/bin/sh
echo "\$*" >>"$STUB/nmlog"
case "\$*" in
  *"dev wifi list"*) printf '*:HomeNet:80:WPA2:5180 MHz\n:Saved Net:45:WPA2:2437 MHz\n:Neighbour:30:WPA2:2412 MHz\n:CafeOpen:60::2462 MHz\n:Neighbour:20:WPA2:5200 MHz\n' ;;
  *"connection show --active"*) echo "uuid-home:802-11-wireless" ;;
  *"connection show"*) printf 'HomeNet:802-11-wireless:uuid-home:wlan0\nSaved Net:802-11-wireless:uuid-saved:\nlo:loopback:uuid-lo:lo\n' ;;
  *"wifi connect Neighbour password right"*) echo "Device 'wlan0' successfully activated." ;;
  *"wifi connect Neighbour"*) echo "Error: Connection activation failed: Secrets were required, but not provided." >&2; exit 4 ;;
  *"wifi connect"*) echo "Device 'wlan0' successfully activated." ;;
esac
exit 0
EOF
chmod +x "$STUB/nmcli"
LOG=$(mktemp); PATH="$STUB:$PATH" HUSH_BT_NO_ADAPTER=1 "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
SHOTS="${HUSH_SHOTS:-$HOME/.cache/hush/evidence}"; mkdir -p "$SHOTS"
shot() { # name: grim the harness layer
  local g; g=$(hyprctl layers -j | jq -r '[.. | objects | select((.namespace? // "") == "hush-harness-cc")][0] | "\(.x),\(.y) \(.w)x\(.h)"')
  sleep 0.6; grim -g "$g" "$SHOTS/$1.png" 2>/dev/null && assert_file "$SHOTS/$1.png" "screenshot $1"
}
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
  cc openWifi >/dev/null; local i c=0; for i in $(seq 20); do c=$(cc networkCount); (( c == 4 )) && break; sleep 0.3; done
  assert_eq "4" "$c" "stub networks listed once each (duplicate SSID merged)"
  sleep 0.3
  assert_eq "6" "$(cc rowCount wifiPage)" "four network rows plus the hidden and hotspot entries"
  assert_eq "true" "$(cc visibleIn wifiPage HomeNet wifiDisconnect)" "active network offers Disconnect"
  assert_eq "false" "$(cc visibleIn wifiPage Neighbour wifiDisconnect)" "inactive network has no Disconnect"
  assert_eq "true" "$(cc visibleIn wifiPage HomeNet wifiBars)" "rows carry signal bars"
  cc back >/dev/null
}
# In-place password entry: a secured network without a profile opens a field under its row, a refused
# key shows inline (no notify-send anywhere), the right key joins via nmcli dev wifi connect ... password.
t_wifi_password() {
  : >"$STUB/nmlog"; cc openWifi >/dev/null; sleep 0.8
  local h0; h0=$(cc rowHeight wifiPage Neighbour)
  cc press wifiPage Neighbour "" >/dev/null; sleep 0.4
  assert_eq "Neighbour" "$(cc askSsid | tr -d '"')" "click on a secured unsaved network asks for its password"
  assert_eq "true" "$(cc visibleIn wifiPage Neighbour wifiPassword)" "password field shown in place"
  assert_eq "true" "$(cc passwordFocused Neighbour)" "password field takes the keyboard"
  local h1; h1=$(cc rowHeight wifiPage Neighbour)
  (( h1 > h0 )) && pass "row grows for the field ($h0 -> $h1 px)" || fail "row height $h0 -> $h1"
  grep -q "wifi connect Neighbour" "$STUB/nmlog" && fail "connected before a password was typed" || pass "no connect before a password"
  cc typePassword Neighbour wrong >/dev/null; cc press wifiPage Neighbour wifiJoin >/dev/null
  local i; for i in $(seq 20); do [[ "$(cc netError)" == *Neighbour* ]] && break; sleep 0.2; done
  assert_contains <(grep "wifi connect" "$STUB/nmlog") "dev wifi connect Neighbour password wrong" "join runs nmcli dev wifi connect SSID password X"
  assert_contains <(cc netError) "Wrong password" "refusal reported as an inline error"
  sleep 0.4
  assert_eq "true" "$(cc visibleIn wifiPage Neighbour wifiError)" "error text visible under the row"
  assert_eq "Neighbour" "$(cc askSsid | tr -d '"')" "field stays open after a refusal"
  grep -q "connection delete id Neighbour" "$STUB/nmlog" && pass "half-made profile removed after the refusal" || fail "no profile cleanup: $(cat "$STUB/nmlog")"
  cc typePassword Neighbour right >/dev/null; cc press wifiPage Neighbour wifiJoin >/dev/null
  for i in $(seq 20); do [[ -z "$(cc askSsid | tr -d '"')" ]] && break; sleep 0.2; done
  assert_eq "" "$(cc askSsid | tr -d '"')" "field closes after a successful join"
  assert_eq "|" "$(cc netError | tr -d '"')" "no error after the right key"
  : >"$STUB/nmlog"; cc press wifiPage "Saved Net" "" >/dev/null
  for i in $(seq 20); do grep -q "wifi connect" "$STUB/nmlog" && break; sleep 0.2; done
  assert_contains <(grep "wifi connect" "$STUB/nmlog") "dev wifi connect Saved Net" "saved network joins without asking"
  grep -q "password" "$STUB/nmlog" && fail "asked nmcli for a password on a saved network" || pass "no password for a saved profile"
  sleep 0.5; : >"$STUB/nmlog"; cc press wifiPage HomeNet wifiDisconnect >/dev/null
  for i in $(seq 20); do grep -q "connection down" "$STUB/nmlog" && break; sleep 0.2; done
  assert_contains <(cat "$STUB/nmlog") "connection down uuid uuid-home" "Disconnect downs the active Wi-Fi connection"
  grep -q notify-send "$HUSH_ROOT/quickshell/hush/services/Net.qml" "$HUSH_ROOT/quickshell/hush/modules/island/cc/WifiRow.qml" \
    && fail "Wi-Fi code raises notifications" || pass "Wi-Fi errors never raise a notification"
  cc back >/dev/null; cc back >/dev/null
}
# No dead band: the main page's lowest control sits on the 12 px bottom margin of the surface.
t_layout() {
  local h b; h=$(cc surfaceHeight); b=$(cc mainContentBottom)
  assert_eq "304" "$h" "control center is 304 px tall"
  assert_eq "$((h - 12))" "$b" "content reaches the 12 px bottom margin (no empty band)"
  if [[ "$(cc mediaShown)" == true ]]; then pass "a player exists: media row holds the top slot"
  else assert_eq "true" "$(cc notifSummaryVisible)" "notifications summary fills the top row without a player"; fi
  cc pressOpenNotifs >/dev/null; assert_eq "1" "$(cc notifRequests)" "Open asks for the notification center"
}
# Keyboard sliders: Left/Right = one step, Shift = ten, committed. The harness stands in for the island's
# navigator (live wiring: Island.navAdjust); keys go through tests/lib/input.sh (skipped without uinput on the live desktop).
# The sink volume is real, so it is saved and restored.
t_keys() {
  command -v wpctl >/dev/null || { pass "no wpctl: keyboard slider check skipped"; return; }
  local ov om
  ov=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || { pass "no default sink: keyboard slider check skipped"; return; }
  om=0; [[ "$ov" == *MUTED* ]] && om=1; ov=$(awk '{print $2}' <<<"$ov")
  input_start || { pass "$(input_why): keyboard slider check skipped"; return; }
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
  input_click; sleep 0.3
  local v0 v1; v0=$(cc sliderValue)
  input_key Right; sleep 0.5
  assert_eq "1" "$(cc adjusts)" "Right reaches the slider"; assert_eq "1" "$(cc lastStep)" "Right is one step"
  v1=$(cc sliderValue)
  python3 -c "import sys; sys.exit(0 if abs(($v1)-($v0)-0.05)<0.011 else 1)" && pass "Right raised the volume by one step (0.05: $v0 -> $v1)" || fail "volume $v0 -> $v1 after Right"
  input_key Left; sleep 0.5
  assert_eq "-1" "$(cc lastStep)" "Left is minus one step"
  input_key shift+Left; sleep 0.5
  assert_eq "-10" "$(cc lastStep)" "Shift+Left is ten steps"
  assert_eq "0.00" "$(cc sliderValue)" "the value clamps at 0"
  assert_eq "3" "$(cc adjusts)" "every key committed once"
  input_stop
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
# Focus page from the timer tile: Start runs the first 25 min block, a duration chip jumps to that
# phase, Stop ends the session; the tile reads the phase.
t_focus() {
  cc enableTile timer >/dev/null; sleep 0.3
  cc openFocus >/dev/null; assert_eq "focus" "$(cc page)" "openFocus opens the focus page"
  assert_eq "25:00" "$(cc focusText focusTime | tr -d '"')" "idle page shows the focus length"
  assert_eq "Start" "$(cc focusText focusButton | tr -d '"')" "idle page offers Start"
  cc pressFocus focusButton >/dev/null; sleep 0.6
  assert_eq "focus/1" "$(cc focusPhase | tr -d '"')" "Start begins the first focus block"
  assert_eq "Stop" "$(cc focusText focusButton | tr -d '"')" "running page offers Stop"
  assert_eq "Focus · 25 min" "$(cc focusText focusPhase | tr -d '"')" "phase and length under the ring"
  assert_contains <(cc focusText focusSubtitle) "First of four" "subtitle counts the block"
  assert_contains <(cc tileSub timer) "Focus" "timer tile reads the phase"
  cc pressFocus focusChip_break >/dev/null; sleep 0.3
  assert_eq "break/1" "$(cc focusPhase | tr -d '"')" "a duration chip jumps to that phase"
  cc pressFocus focusChip_focus >/dev/null; shot focus-page
  cc pressFocus focusButton >/dev/null; sleep 0.3
  assert_eq "/0" "$(cc focusPhase | tr -d '"')" "Stop ends the session"
  cc back >/dev/null; assert_eq "main" "$(cc page)" "back from the focus page"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
# Bluetooth device page on a fake radio (HUSH_BT_FAKE=1): rows, actions, discovery spinner, battery.
t_btpage() {
  kill $HPID 2>/dev/null; wait $HPID 2>/dev/null
  PATH="$STUB:$PATH" HUSH_BT_FAKE=1 "${H[@]}" -n >>"$LOG" 2>&1 & HPID=$!
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  cc openBluetooth >/dev/null; sleep 0.6
  assert_eq "3" "$(cc rowCount btPage)" "paired and discovered devices listed"
  assert_eq "true" "$(cc btDiscovering)" "opening the page starts discovery"
  assert_contains <(cc btSubtitleLine) "Searching" "header says Searching while discovering"
  assert_eq "Connected · 80 %" "$(cc textIn btPage 'Fake Buds' btState)" "connected device shows its battery"
  assert_eq "true" "$(cc visibleIn btPage 'Fake Buds' btDisconnect)" "connected: Disconnect"
  assert_eq "true" "$(cc visibleIn btPage 'Fake Keyboard' btConnect)" "paired: Connect"
  assert_eq "true" "$(cc visibleIn btPage 'Fake Keyboard' btForget)" "paired: Forget"
  assert_eq "true" "$(cc visibleIn btPage 'Fake Speaker' btPair)" "discovered: Pair"
  assert_eq "false" "$(cc visibleIn btPage 'Fake Speaker' btForget)" "unpaired: nothing to forget"
  cc press btPage 'Fake Speaker' btPair >/dev/null; sleep 0.3
  cc press btPage 'Fake Keyboard' btConnect >/dev/null; sleep 0.3
  cc press btPage 'Fake Buds' btDisconnect >/dev/null; sleep 0.3
  assert_contains <(cc btLog) "pair Fake Speaker" "Pair calls pair()"
  assert_contains <(cc btLog) "connect Fake Keyboard" "Connect calls connect()"
  assert_contains <(cc btLog) "disconnect Fake Buds" "Disconnect calls disconnect()"
  for i in $(seq 10); do [[ "$(cc btLog)" == *",connect Fake Speaker"* ]] && break; sleep 0.3; done
  assert_contains <(cc btLog) ",connect Fake Speaker" "a freshly paired device is connected"
  cc press btPage 'Fake Keyboard' btForget >/dev/null; sleep 0.5
  assert_contains <(cc btLog) "forget Fake Keyboard" "Forget calls forget()"
  assert_eq "2" "$(cc rowCount btPage)" "forgotten device leaves the list"
  for i in $(seq 12); do [[ "$(cc btDiscovering)" == false ]] && break; sleep 0.5; done
  assert_eq "false" "$(cc btDiscovering)" "discovery ends"
  cc back >/dev/null
}
run_test up t_up; run_test pages t_pages; run_test networks t_networks; run_test wifi_password t_wifi_password
run_test layout t_layout; run_test focus t_focus; run_test keys t_keys; run_test bt t_bt; run_test btpage t_btpage; run_test log t_log
finish

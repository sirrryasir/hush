#!/usr/bin/env bash
# Network group of the control center in the cc harness (tests/harness/cc.qml) on stub nmcli and
# rfkill scripts: Wi-Fi details, forget, hidden network, hotspot, VPN tile. Saves PNGs of each surface to
# $HUSH_SHOTS (default ../cc-shots next to the checkout).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
STUB=$(mktemp -d)
# nmcli: logs every call to nmlog. HomeNet joined (uuid-home, 5 GHz, WPA2, 10.0.0.5), Saved Net saved;
# the Hotspot profile is up once "dev wifi hotspot" ran and down again after "connection down Hotspot".
# VPN profiles follow the vpn file: none, down (Office VPN), up, or two (Office VPN down, Home WG up).
echo down >"$STUB/hotspot"; echo down >"$STUB/vpn"
cat >"$STUB/nmcli" <<EOF
#!/bin/sh
echo "\$*" >>"$STUB/nmlog"
case "\$*" in
  *"dev wifi list"*) printf '*:HomeNet:80:WPA2:5180 MHz\n:Saved Net:45:WPA2:2437 MHz\n:CafeOpen:60::2462 MHz\n' ;;
  *"connection show --active"*) echo "uuid-home:802-11-wireless" ;;
  *"connection show"*)
    printf 'HomeNet:802-11-wireless:uuid-home:wlan0\nSaved Net:802-11-wireless:uuid-saved:\nlo:loopback:uuid-lo:lo\n'
    [ "\$(cat "$STUB/hotspot")" = up ] && echo "Hotspot:802-11-wireless:uuid-hs:wlan0"
    case "\$(cat "$STUB/vpn")" in
      down) echo "Office VPN:vpn:uuid-vpn:" ;;
      up) echo "Office VPN:vpn:uuid-vpn:tun0" ;;
      two) printf 'Office VPN:vpn:uuid-vpn:\nHome WG:wireguard:uuid-wg:wg0\n' ;;
    esac ;;
  *"dev show"*) printf 'GENERAL.TYPE:loopback\nIP4.ADDRESS[1]:127.0.0.1/8\nGENERAL.TYPE:wifi\nIP4.ADDRESS[1]:10.0.0.5/24\n' ;;
  *"dev wifi hotspot"*) echo up >"$STUB/hotspot" ;;
  *"connection down Hotspot"*) echo down >"$STUB/hotspot" ;;
  *"connection up uuid uuid-vpn"*) echo up >"$STUB/vpn" ;;
  *"connection down uuid uuid-vpn"*) echo down >"$STUB/vpn" ;;
  *"wifi connect"*) echo "Device 'wlan0' successfully activated." ;;
esac
exit 0
EOF
chmod +x "$STUB/nmcli"
LOG=$(mktemp); PATH="$STUB:$PATH" HUSH_BT_NO_ADAPTER=1 "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
# Crops the harness layer out of the output into $SHOTS/$1.png.
shot() {
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
for o in json.load(sys.stdin).values():
  for lv in o['levels'].values():
    for l in lv:
      if l['namespace']=='hush-harness-cc': print('%d,%d %dx%d' % (l['x'],l['y'],l['w'],l['h']))")
  [[ -n "$g" ]] && grim -g "$g" "$SHOTS/$1.png" 2>/dev/null
  assert_file "$SHOTS/$1.png" "saved $SHOTS/$1.png"
}
wait_rows() { local i; for i in $(seq 30); do (( $(cc rowCount wifiPage) >= $1 )) && return 0; sleep 0.3; done; return 1; }
t_up() {
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  assert_eq "main" "$(cc page)" "harness starts on the main page"
}
# The joined network's row carries signal, band, security and IPv4 from nmcli; the others do not.
t_details() {
  cc openWifi >/dev/null; wait_rows 3 || fail "networks never listed"
  sleep 0.5
  assert_eq "80 % · 5 GHz · WPA2 · 10.0.0.5" "$(cc textIn wifiPage HomeNet wifiDetail)" "joined network shows signal, band, security and IPv4"
  assert_eq "true" "$(cc visibleIn wifiPage HomeNet wifiDetail)" "detail line visible on the joined network"
  assert_eq "false" "$(cc visibleIn wifiPage 'Saved Net' wifiDetail)" "no detail line on an unjoined network"
  assert_eq "44" "$(cc rowHeight wifiPage HomeNet)" "the detailed row keeps the 44 px row height"
  shot wifi-details
}
# Forget asks twice (PowerRow's confirm) and then deletes the profile by uuid.
t_forget() {
  : >"$STUB/nmlog"
  assert_eq "true" "$(cc visibleIn wifiPage 'Saved Net' wifiForget)" "saved network offers Forget"
  assert_eq "false" "$(cc visibleIn wifiPage CafeOpen wifiForget)" "unsaved network has no Forget"
  cc press wifiPage 'Saved Net' wifiForget >/dev/null; sleep 0.3
  grep -q "connection delete" "$STUB/nmlog" && fail "one click already deleted the profile" || pass "first click only arms"
  assert_eq "Forget" "$(cc textIn wifiPage 'Saved Net' wifiForget)" "armed button says Forget"
  cc press wifiPage 'Saved Net' wifiForget >/dev/null
  local i; for i in $(seq 20); do grep -q "connection delete" "$STUB/nmlog" && break; sleep 0.2; done
  assert_contains <(cat "$STUB/nmlog") "connection delete uuid uuid-saved" "second click runs nmcli connection delete uuid"
}
# The hidden entry: the field asks the name in clear, then the password, then joins with hidden yes.
t_hidden() {
  : >"$STUB/nmlog"; wait_rows 5 || fail "extra rows missing"
  assert_eq "5" "$(cc rowCount wifiPage)" "three networks plus the hidden and hotspot entries"
  cc press wifiPage hidden "" >/dev/null; sleep 0.4
  assert_eq "true" "$(cc visibleIn wifiPage hidden wifiPassword)" "hidden entry opens the field"
  assert_eq "0" "$(cc passwordEcho hidden)" "the name step shows what is typed"
  assert_eq "Next" "$(cc textIn wifiPage hidden wifiJoin)" "the button says Next on the name step"
  cc typePassword hidden "Secret Net" >/dev/null; cc press wifiPage hidden wifiJoin >/dev/null; sleep 0.3
  assert_eq "Secret Net" "$(cc hiddenSsid)" "the name is kept"
  assert_eq "2" "$(cc passwordEcho hidden)" "the password step hides what is typed"
  grep -q "wifi connect" "$STUB/nmlog" && fail "joined before the password" || pass "no join before the password"
  cc typePassword hidden "key" >/dev/null; cc press wifiPage hidden wifiJoin >/dev/null
  local i; for i in $(seq 20); do grep -q "wifi connect" "$STUB/nmlog" && break; sleep 0.2; done
  assert_contains <(grep "wifi connect" "$STUB/nmlog") "dev wifi connect Secret Net password key hidden yes" "join runs nmcli ... hidden yes"
  for i in $(seq 20); do [[ -z "$(cc askSsid | tr -d '"')" ]] && break; sleep 0.2; done
  assert_eq "" "$(cc askSsid | tr -d '"')" "field closes after the join"
}
t_hotspot() {
  : >"$STUB/nmlog"; sleep 0.5
  assert_eq "Start" "$(cc textIn wifiPage hotspot hotspotToggle)" "hotspot row offers Start"
  cc press wifiPage hotspot hotspotToggle >/dev/null
  local i; for i in $(seq 20); do [[ "$(cc textIn wifiPage hotspot hotspotToggle)" == Stop ]] && break; sleep 0.3; done
  assert_contains <(cat "$STUB/nmlog") "dev wifi hotspot" "Start runs nmcli dev wifi hotspot"
  assert_eq "Stop" "$(cc textIn wifiPage hotspot hotspotToggle)" "row reads Stop once the Hotspot profile is up"
  cc press wifiPage hotspot hotspotToggle >/dev/null
  for i in $(seq 20); do [[ "$(cc textIn wifiPage hotspot hotspotToggle)" == Start ]] && break; sleep 0.3; done
  assert_contains <(cat "$STUB/nmlog") "connection down Hotspot" "Stop downs the Hotspot profile"
  assert_eq "Start" "$(cc textIn wifiPage hotspot hotspotToggle)" "row back to Start"
  cc back >/dev/null
}
# VPN tile: hidden without a profile, toggles the only one on tap, lists several on a sub-page.
t_vpn() {
  : >"$STUB/nmlog"
  assert_eq "true" "$(cc tileShown vpn)" "VPN tile in the grid with a profile"
  assert_eq "Off" "$(cc tileSub vpn)" "tile says Off"
  cc pressTile vpn >/dev/null
  local i; for i in $(seq 20); do [[ "$(cc tileChecked vpn)" == true ]] && break; sleep 0.3; done
  assert_contains <(cat "$STUB/nmlog") "connection up uuid uuid-vpn" "tap runs nmcli connection up uuid"
  assert_eq "true" "$(cc tileChecked vpn)" "tile on once the profile has a device"
  assert_eq "Office VPN" "$(cc tileSub vpn)" "tile names the connected VPN"
  cc pressTile vpn >/dev/null
  for i in $(seq 20); do [[ "$(cc tileChecked vpn)" == false ]] && break; sleep 0.3; done
  assert_contains <(cat "$STUB/nmlog") "connection down uuid uuid-vpn" "second tap downs it"
  echo two >"$STUB/vpn"; cc netPoll >/dev/null
  for i in $(seq 20); do [[ "$(cc vpnCount)" == 2 ]] && break; sleep 0.3; done
  assert_eq "2" "$(cc vpnCount)" "two profiles listed"
  assert_eq "Home WG" "$(cc tileSub vpn)" "tile names the active one of two"
  cc pressTile vpn >/dev/null; sleep 0.4
  assert_eq "vpn" "$(cc page)" "tap with several profiles opens the VPN page"
  assert_eq "2" "$(cc rowCount vpnPage)" "both profiles on the page"
  shot vpn-row
  : >"$STUB/nmlog"; cc press vpnPage 'Office VPN' "" >/dev/null
  for i in $(seq 20); do grep -q "connection up" "$STUB/nmlog" && break; sleep 0.3; done
  assert_contains <(cat "$STUB/nmlog") "connection up uuid uuid-vpn" "a row brings its profile up"
  cc back >/dev/null; assert_eq "main" "$(cc page)" "back from the VPN page"
  echo none >"$STUB/vpn"; cc netPoll >/dev/null
  for i in $(seq 20); do [[ "$(cc tileShown vpn)" == false ]] && break; sleep 0.3; done
  assert_eq "false" "$(cc tileShown vpn)" "tile hidden without a VPN profile"
  echo down >"$STUB/vpn"; cc netPoll >/dev/null
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test up t_up; run_test details t_details; run_test forget t_forget; run_test hidden t_hidden; run_test hotspot t_hotspot
run_test vpn t_vpn; run_test log t_log
finish

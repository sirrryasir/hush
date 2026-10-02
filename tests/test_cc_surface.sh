#!/usr/bin/env bash
# Control-center surface in its own harness (tests/harness/cc.qml); never touches the live shell.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
LOG=$(mktemp); "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -f "$LOG"' EXIT
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
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test up t_up; run_test pages t_pages; run_test networks t_networks; run_test log t_log
finish

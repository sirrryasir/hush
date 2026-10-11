#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
# Restore volume, mute, and brightness however the test exits.
O_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@); O_MUTE=0; [[ "$O_VOL" == *MUTED* ]] && O_MUTE=1; O_VOL=$(awk '{print $2}' <<<"$O_VOL")
O_BRI=$(brightnessctl -m get 2>/dev/null)
restore_state() {
  wpctl set-volume @DEFAULT_AUDIO_SINK@ "$O_VOL"; wpctl set-mute @DEFAULT_AUDIO_SINK@ "$O_MUTE"
  [[ -n "$O_BRI" ]] && brightnessctl -q set "$O_BRI"
}
trap restore_state EXIT
t_startup() {
  shell_restart; sleep 0.5
  assert_eq "rest" "$(shell_ipc islandState)" "no OSD right after startup"
  sleep 2.5
}
t_volume() {
  # Start from a mid volume so -5% is a real change; restore volume and mute afterwards.
  local orig muted=0; orig=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
  [[ "$orig" == *MUTED* ]] && muted=1; orig=$(awk '{print $2}' <<<"$orig")
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.30; sleep 2
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-; sleep 0.3
  assert_eq "osd" "$(shell_ipc islandState)" "volume change shows osd"
  sleep 2; assert_eq "rest" "$(shell_ipc islandState)" "osd returns to rest"
  wpctl set-volume @DEFAULT_AUDIO_SINK@ "$orig"; wpctl set-mute @DEFAULT_AUDIO_SINK@ "$muted"; sleep 2
}
t_brightness() {
  brightnessctl -q set 5%-; sleep 0.3
  assert_eq "osd" "$(shell_ipc islandState)" "brightness change shows osd"
  brightnessctl -q set 5%+; sleep 2
}
t_coalesce() {
  # One OSD whose 1100 ms hold re-times from the last change: raised at 0 and ~800 ms, it is still up
  # at ~1500 ms and gone ~1100 ms after the second raise (a burst never stacks or flickers).
  shell_wait_state rest 60
  shell_ipc osd volume; sleep 0.8; shell_ipc osd brightness; sleep 0.6
  assert_eq "osd" "$(shell_ipc islandState)" "still the OSD 1.4 s after the first change (re-timed)"
  shell_wait_state rest 40
  local g; g=$(shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin); i=max(i for i,(n,t) in enumerate(h) if n=='osd')
print(next((t for n,t in h[i+1:] if not n.startswith('@')), 0)-h[i][1])")
  [[ $g -ge 1700 && $g -le 2400 ]] && pass "coalesced OSD lasted $g ms (two raises 0.8 s apart + 1100 ms)" || fail "OSD lasted $g ms"
}
run_test "startup" t_startup; run_test "volume" t_volume; run_test "brightness" t_brightness; run_test "coalesce" t_coalesce; run_test "log" shell_log_check
finish

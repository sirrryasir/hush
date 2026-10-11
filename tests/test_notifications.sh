#!/usr/bin/env bash
# Live test of the hush notification daemon, toasts on the island (through the Arbiter: 5 s hold,
# paused on hover, critical sticky, one at a time, queued under a surface and resumed after it) and
# the notification center surface inside the island. Bus-name ownership: with another daemon on
# org.freedesktop.Notifications the shell stays passive and the settings surface warns.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
EVI="$HOME/.cache/hush/evidence"; mkdir -p "$EVI"
notif_ipc() { qs -c hush ipc call notifs "$@"; }
# Integer reply or the fallback, so a missing IPC target fails the assertion instead of bash.
int_or() { [[ $1 =~ ^[0-9]+$ ]] && echo "$1" || echo "$2"; }
read -r MX MY MW MH < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']))")
TOP=$(shell_ipc settingsGet island.topGap 2>/dev/null || echo 6)
PX=$((MX + MW / 2)); PY=$((MY + TOP + 18)); AX=$PX; AY=$((MY + MH / 2))
owner() { busctl --user status org.freedesktop.Notifications 2>/dev/null | awk -F= '/^Comm=/{print $2}'; }
# ms from the last "$1" mark to the first "$2" mark after it in the island history (-1 if absent).
gap() { shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin); a=None
for i,(n,t) in enumerate(h):
  if n=='$1': a=(i,t)
b=next((t for n,t in h[a[0]+1:] if n=='$2'), None) if a else None
print(-1 if b is None else b-a[1])"; }
# The state names recorded after the last "$1" mark.
after() { shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin); i=max((i for i,(n,t) in enumerate(h) if n=='$1'), default=len(h))
print(' '.join(n for n,t in h[i+1:] if not n.startswith('@')))"; }
cleanup() { input_move "$AX" "$AY"; shell_ipc closeSurface >/dev/null 2>&1; shell_ipc clearNotifications >/dev/null 2>&1; }
trap cleanup EXIT

t_daemon() {
  session_pkill -x swaync 2>/dev/null; sleep 0.3
  input_move "$AX" "$AY"; shell_restart; sleep 3
  assert_eq "qs" "$(owner)" "hush owns org.freedesktop.Notifications"
  assert_eq "false" "$(notif_ipc passive)" "not passive while it owns the name"
  shell_ipc clearNotifications >/dev/null
}
t_single() {
  notify-send -a hushtest "Hello" "one line"; sleep 0.5
  assert_eq "notification" "$(shell_state)" "a notification shows on the island"
  assert_eq "36" "$(notif_ipc islandHeight)" "one-line body keeps the island at 36"
  assert_eq "false" "$(shell_ipc islandControlVisible criticalMarker)" "a normal card has no critical marker"
  grim "$EVI/notification.png" 2>/dev/null
  shell_wait_state rest 140 && pass "island returns to rest after the hold" || fail "still $(shell_state) after the hold"
  local g; g=$(gap notification rest)
  [[ $g -ge 4900 && $g -le 5300 ]] && pass "hold was $g ms (5000)" || fail "hold was $g ms"
}
t_hover_pause() {
  notify-send -a hushtest "Hovered" "stays while the pointer is on it"; sleep 0.4
  input_move "$PX" "$PY"; sleep 6
  assert_eq "notification" "$(shell_state)" "hold paused while the pointer is on the card (6 s)"
  input_move "$AX" "$AY"; sleep 4.5
  assert_eq "notification" "$(shell_state)" "hold restarts in full after the pointer leaves"
  shell_wait_state rest 30 && pass "then it times out" || fail "still $(shell_state)"
}
t_critical() {
  notify-send -u critical -a hushtest "Critical" "sticky"; sleep 0.4
  assert_eq "notification" "$(shell_state)" "a critical notification shows"
  sleep 6
  assert_eq "notification" "$(shell_state)" "critical is sticky (6 s, no timeout)"
  assert_eq "Critical" "$(notif_ipc current)" "the sticky card is the critical one"
  assert_eq "true" "$(shell_ipc islandControlVisible criticalMarker)" "the critical card wears the red marker"
  grim "$EVI/notification-critical.png" 2>/dev/null
  shell_ipc clearNotifications >/dev/null; sleep 0.4
  assert_eq "rest" "$(shell_state)" "clear all removes the sticky card"
}
t_resume() {
  shell_ipc clearNotifications >/dev/null
  shell_ipc openSurface expanded; shell_wait_state expanded
  notify-send -a hushtest "Queued" "while the control center is open"; sleep 0.5
  assert_eq "expanded" "$(shell_state)" "a notification does not cover an open surface"
  assert_eq "1" "$(int_or "$(notif_ipc queued)" 0)" "it waits in the queue"
  shell_ipc closeSurface; shell_wait_state notification
  local g; g=$(gap @close notification)
  [[ $g -ge 0 && $g -le 300 ]] && pass "shows $g ms after the surface closed (<= 300)" || fail "resume gap $g ms (state $(shell_state))"
  assert_eq "notification" "$(after @close)" "no rest flash between the surface and the card"
  assert_eq "Queued" "$(notif_ipc current)" "the queued card is the one shown"
  shell_ipc clearNotifications >/dev/null; sleep 0.3
}
t_storm() {
  shell_ipc clearNotifications >/dev/null
  for i in $(seq 1 30); do notify-send -a storm "n$i" "body $i"; done
  assert_eq "notification" "$(shell_state)" "storm shows a notification"
  local max=0 h w maxw=0
  for _ in 1 2 3 4 5; do
    h=$(int_or "$(notif_ipc islandHeight)" 999); w=$(int_or "$(notif_ipc islandWidth)" 999)
    (( h > max )) && max=$h; (( w > maxw )) && maxw=$w
    sleep 0.6
  done
  (( max <= 56 )) && pass "island height stays within 56 (max $max)" || fail "island grew to $max"
  (( maxw <= 520 )) && pass "island width stays within 520 (max $maxw)" || fail "island width grew to $maxw"
  local q; q=$(int_or "$(notif_ipc queued)" 0)
  (( q >= 20 )) && pass "storm is queued, one at a time ($q waiting)" || fail "queue holds only $q"
  local u; u=$(int_or "$(shell_ipc unread)" 0)
  (( u >= 30 )) && pass "unread counts the storm ($u)" || fail "unread is $u"
  local c; c=$(int_or "$(notif_ipc count)" 0)
  (( c >= 30 )) && pass "all storm notifications land in the list ($c)" || fail "list has $c"
}
t_center() {
  shell_ipc toggleDrawer; shell_wait_state notifCenter
  assert_eq "notifCenter" "$(shell_state)" "toggleDrawer opens the notification center in the island"
  # The state flips at once; the pill springs to the surface size over the morph.
  local i; for i in $(seq 30); do [[ "$(shell_ipc islandSize)" == "480x260" ]] && break; sleep 0.05; done
  assert_eq "480x260" "$(shell_ipc islandSize)" "center is 480x260"
  local other; other=$(hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(sorted({l["namespace"] for m in d.values() for lv in m["levels"].values() for l in lv if l["namespace"].startswith("hush") and not l["namespace"].startswith("hush-island")})))')
  assert_eq "" "$other" "no hush layer besides hush-island*"
  assert_eq "0" "$(shell_ipc unread)" "opening the center marks all seen"
  assert_eq "0" "$(int_or "$(notif_ipc queued)" 9)" "opening the center drops the pending toasts"
  grim "$EVI/notif-center.png" 2>/dev/null
  shell_ipc clearNotifications; sleep 0.5
  assert_eq "0" "$(notif_ipc count)" "clear all empties the list"
  assert_eq "0" "$(shell_ipc unread)" "unread is 0 after clear"
  shell_ipc toggleDrawer; shell_wait_state rest
  assert_eq "rest" "$(shell_state)" "toggleDrawer again closes it"
}
t_passive() {
  # A stand-in daemon (`hush shell start` kills swaync, so a tiny GLib owner holds the name).
  python3 -c 'import gi' 2>/dev/null || { pass "python gi missing: passive check skipped"; return; }
  "$HUSH_ROOT/bin/hush" shell stop >/dev/null
  python3 -c "
from gi.repository import Gio, GLib
Gio.bus_own_name(Gio.BusType.SESSION, 'org.freedesktop.Notifications', Gio.BusNameOwnerFlags.NONE, None, None, None)
GLib.MainLoop().run()" & local sp=$!
  local i; for i in $(seq 40); do [[ "$(owner)" == python3 ]] && break; sleep 0.1; done
  shell_restart; sleep 3
  assert_eq "python3" "$(owner)" "another daemon keeps the name"
  assert_eq "true" "$(notif_ipc passive)" "hush is passive"
  shell_ipc settings; shell_wait_state settings
  for i in $(seq 20); do [[ -n "$(shell_ipc settingsWarning)" ]] && break; sleep 0.1; done
  shell_ipc settingsWarning | grep -q "org.freedesktop.Notifications" && pass "settings surface shows the warning line" || fail "no warning: '$(shell_ipc settingsWarning)'"
  grim "$EVI/settings-passive.png" 2>/dev/null
  shell_ipc settings; shell_wait_state rest
  kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
  for i in $(seq 40); do [[ "$(owner)" == qs ]] && break; sleep 0.5; done
  assert_eq "qs" "$(owner)" "hush takes the name once it is free (re-probe every 15 s)"
  assert_eq "false" "$(notif_ipc passive)" "and leaves passive mode"
  local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log after the take-over" || fail "shell log errors: $e"
}
run_test "daemon" t_daemon; run_test "single" t_single; run_test "hover pause" t_hover_pause
run_test "critical" t_critical; run_test "resume" t_resume; run_test "storm" t_storm
run_test "center" t_center; run_test "log" shell_log_check; run_test "passive" t_passive
finish

#!/usr/bin/env bash
# Live test of the launcher, a modal surface inside the island (priority 90), driven over IPC (the
# keybinds call toggleLauncher / showLauncher), wtype for the keyboard, and a private ydotoold for a
# click off the pill (skipped without a writable uinput).
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
EVI="$HOME/.cache/hush/evidence"; mkdir -p "$EVI"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hush-test-ydotool-launcher.sock"; YPID=""
state() { shell_ipc islandState; }
wait_state() { local i; for i in $(seq "${2:-40}"); do [[ "$(state)" == "$1" ]] && return 0; sleep 0.05; done; return 1; }
# Poll an IPC getter until it answers non-empty/non-zero (the surface item loads asynchronously).
wait_ipc() { local i v; for i in $(seq 40); do v=$(shell_ipc "$@"); [[ -n "$v" && "$v" != 0 ]] && return 0; sleep 0.05; done; return 1; }
focused_monitor() { hyprctl monitors -j | python3 -c 'import json,sys;print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))'; }
hush_layers() { hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(sorted({l["namespace"] for m in d.values() for lv in m["levels"].values() for l in lv if l["namespace"].startswith("hush")})))'; }
active() { hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))'; }
cleanup() { [[ -n "$YPID" ]] && kill "$YPID" 2>/dev/null; rm -f "$SOCK"; shell_ipc closeSurface >/dev/null 2>&1; }
trap cleanup EXIT

t_open() {
  shell_restart && pass "shell restarts" || fail "shell restart failed"
  sleep 1
  assert_eq "false" "$(shell_ipc launcherVisible)" "launcher starts hidden"
  shell_ipc toggleLauncher; wait_state launcher
  assert_eq "true" "$(shell_ipc launcherVisible)" "toggleLauncher opens the launcher in the island"
  local i; for i in $(seq 20); do [[ "$(shell_ipc islandSize)" == "520x300" ]] && break; sleep 0.05; done
  assert_eq "520x300" "$(shell_ipc islandSize)" "the pill grows to 520x300"
  assert_eq "$(focused_monitor)" "$(shell_ipc islandScreen)" "launcher opens on the focused monitor"
  [[ -z "$(hush_layers | tr ' ' '\n' | grep -v '^hush-island')" ]] && pass "no hush layer besides hush-island* ($(hush_layers))" || fail "extra layers: $(hush_layers)"
  grim "$EVI/launcher.png" 2>/dev/null
}
t_search() {
  wait_ipc launcherCount
  shell_ipc launcherQuery "kitty"; sleep 0.3
  local n; n=$(shell_ipc launcherCount)
  [[ "$n" -ge 1 ]] && pass "query kitty has $n result(s)" || fail "query kitty has no results ($n)"
  shell_ipc launcherFirst | grep -qi kitty && pass "first result is kitty" || fail "first result: $(shell_ipc launcherFirst)"
  shell_ipc launcherQuery "=2+2"; sleep 1
  shell_ipc launcherFirst | grep -q 4 && pass "=2+2 evaluates to 4" || fail "=2+2 gave: $(shell_ipc launcherFirst)"
  shell_ipc launcherQuery "=(1+2)*3"; sleep 1
  shell_ipc launcherFirst | grep -q 9 && pass "=(1+2)*3 evaluates to 9" || fail "=(1+2)*3 gave: $(shell_ipc launcherFirst)"
  shell_ipc launcherQuery "zzzzqqqxx"; sleep 0.3
  assert_eq "0" "$(shell_ipc launcherCount)" "nonsense query has no results"
}
t_close() {
  shell_ipc toggleLauncher; wait_state rest || wait_state media
  assert_eq "false" "$(shell_ipc launcherVisible)" "toggleLauncher again closes it"
  shell_ipc showLauncher windows; wait_state launcher
  assert_eq "true" "$(shell_ipc launcherVisible)" "showLauncher windows opens it"
  wait_ipc launcherCount
  local n; n=$(shell_ipc launcherCount)
  [[ "$n" -ge 1 ]] && pass "windows mode lists $n window(s)" || fail "windows mode lists nothing"
  shell_ipc toggleLauncher; sleep 0.4
}
t_island() {
  # The launcher replaces an open control center (modal over panel; the panel does not come back).
  shell_ipc toggleControlCenter; wait_state expanded
  shell_ipc toggleLauncher; wait_state launcher
  assert_eq "launcher" "$(state)" "the launcher replaces the control center"
  shell_ipc toggleLauncher; sleep 0.5
  [[ "$(state)" == rest || "$(state)" == media ]] && pass "closing it returns to rest, not the control center" || fail "state $(state)"
}
t_keyboard() {
  if ! command -v wtype >/dev/null; then echo "  SKIP wtype not installed"; return; fi
  local before; before=$(active)
  shell_ipc toggleLauncher; wait_state launcher; sleep 0.3
  wtype "kit"; sleep 0.4
  shell_ipc launcherFirst | grep -qi kit && pass "typed text reaches the launcher (focus grab)" || fail "typing did not reach the launcher (first: $(shell_ipc launcherFirst))"
  wtype -k Escape; sleep 0.4
  assert_eq "false" "$(shell_ipc launcherVisible)" "Escape closes the launcher"
  assert_eq "$before" "$(active)" "focus returns to the previous window"
}
t_switch() {
  if ! command -v wtype >/dev/null; then echo "  SKIP wtype not installed"; return; fi
  local orig target title
  orig=$(active)
  read -r target title < <(hyprctl clients -j | python3 -c '
import json,sys
cs=[c for c in json.load(sys.stdin) if c["address"]!=sys.argv[1] and c["mapped"] and c["title"]]
print(cs[0]["address"], cs[0]["title"]) if cs else print("")' "$orig")
  if [[ -z "$target" ]]; then echo "  SKIP need a second window"; return; fi
  shell_ipc showLauncher windows; wait_state launcher; wait_ipc launcherCount
  shell_ipc launcherQuery "$title"; sleep 0.3
  if [[ "$(shell_ipc launcherFirst)" != "$title" ]]; then echo "  SKIP target title not ranked first"; shell_ipc toggleLauncher; return; fi
  wtype -k Return; sleep 0.6
  assert_eq "$target" "$(active)" "Enter focuses the chosen window"
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$orig\" })" >/dev/null; sleep 0.3
}
t_click_off() {
  if ! [[ -w /dev/uinput ]] || ! command -v ydotoold >/dev/null; then pass "no writable uinput/ydotoold: click-off skipped"; return; fi
  read -r MX MY MW < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']))")
  rm -f "$SOCK"; ydotoold -p "$SOCK" >/dev/null 2>&1 & YPID=$!; sleep 1.5
  shell_ipc toggleLauncher; wait_state launcher; sleep 0.7
  # Inside the island surface (top 360 px) but off the 520 px pill: the modal catcher takes it.
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((MX + 40)), y = $((MY + 100)) })" >/dev/null; sleep 0.1
  YDOTOOL_SOCKET="$SOCK" ydotool click 0xC0 >/dev/null 2>&1; sleep 0.5
  [[ "$(state)" == rest || "$(state)" == media ]] && pass "a click off the pill closes the launcher" || fail "click off left $(state)"
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((MX + MW / 2)), y = $((MY + 500)) })" >/dev/null
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "open" t_open
run_test "search" t_search
run_test "close" t_close
run_test "island" t_island
run_test "keyboard" t_keyboard
run_test "switch" t_switch
run_test "click off" t_click_off
run_test "log" t_log
finish

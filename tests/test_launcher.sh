#!/usr/bin/env bash
# Live test of the launcher, a modal surface inside the island (priority 90), driven over IPC (the
# keybinds call toggleLauncher / showLauncher), wtype for the keyboard, and tests/lib/input.sh for a
# click off the pill (skipped without a writable uinput on the live desktop).
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
EVI="$HOME/.cache/hush/evidence"; mkdir -p "$EVI"
# Poll an IPC getter until it answers non-empty/non-zero (the surface item loads asynchronously).
focused_monitor() { hyprctl monitors -j | python3 -c 'import json,sys;print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))'; }
hush_layers() { hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(sorted({l["namespace"] for m in d.values() for lv in m["levels"].values() for l in lv if l["namespace"].startswith("hush")})))'; }
active() { hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))'; }
cleanup() { input_stop; shell_ipc closeSurface >/dev/null 2>&1; }
trap cleanup EXIT

t_open() {
  shell_restart && pass "shell restarts" || fail "shell restart failed"
  sleep 1
  assert_eq "false" "$(shell_ipc launcherVisible)" "launcher starts hidden"
  shell_ipc toggleLauncher; shell_wait_state launcher
  assert_eq "true" "$(shell_ipc launcherVisible)" "toggleLauncher opens the launcher in the island"
  local i; for i in $(seq 20); do [[ "$(shell_ipc islandSize)" == "520x300" ]] && break; sleep 0.05; done
  assert_eq "520x300" "$(shell_ipc islandSize)" "the pill grows to 520x300"
  assert_eq "$(focused_monitor)" "$(shell_ipc islandScreen)" "launcher opens on the focused monitor"
  [[ -z "$(hush_layers | tr ' ' '\n' | grep -v '^hush-island')" ]] && pass "no hush layer besides hush-island* ($(hush_layers))" || fail "extra layers: $(hush_layers)"
  grim "$EVI/launcher.png" 2>/dev/null
}
t_search() {
  shell_wait_ipc launcherCount
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
  shell_ipc toggleLauncher; shell_wait_state rest || shell_wait_state media
  assert_eq "false" "$(shell_ipc launcherVisible)" "toggleLauncher again closes it"
  shell_ipc showLauncher windows; shell_wait_state launcher
  assert_eq "true" "$(shell_ipc launcherVisible)" "showLauncher windows opens it"
  shell_wait_ipc launcherCount
  local n; n=$(shell_ipc launcherCount)
  [[ "$n" -ge 1 ]] && pass "windows mode lists $n window(s)" || fail "windows mode lists nothing"
  shell_ipc toggleLauncher; sleep 0.4
}
t_island() {
  # The launcher replaces an open control center (modal over panel; the panel does not come back).
  shell_ipc toggleControlCenter; shell_wait_state expanded
  shell_ipc toggleLauncher; shell_wait_state launcher
  assert_eq "launcher" "$(shell_state)" "the launcher replaces the control center"
  shell_ipc toggleLauncher; sleep 0.5
  [[ "$(shell_state)" == rest || "$(shell_state)" == media ]] && pass "closing it returns to rest, not the control center" || fail "state $(shell_state)"
}
t_keyboard() {
  if ! command -v wtype >/dev/null; then echo "  SKIP wtype not installed"; return; fi
  local before; before=$(active)
  shell_ipc toggleLauncher; shell_wait_state launcher; sleep 0.3
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
  shell_ipc showLauncher windows; shell_wait_state launcher; shell_wait_ipc launcherCount
  shell_ipc launcherQuery "$title"; sleep 0.3
  if [[ "$(shell_ipc launcherFirst)" != "$title" ]]; then echo "  SKIP target title not ranked first"; shell_ipc toggleLauncher; return; fi
  wtype -k Return; sleep 0.6
  assert_eq "$target" "$(active)" "Enter focuses the chosen window"
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$orig\" })" >/dev/null; sleep 0.3
}
t_click_off() {
  read -r MX MY MW < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']))")
  input_start || { pass "$(input_why): click-off skipped"; return; }
  shell_ipc toggleLauncher; shell_wait_state launcher; sleep 0.7
  # Inside the island surface (top 360 px) but off the 520 px pill: the modal catcher takes it.
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((MX + 40)), y = $((MY + 100)) })" >/dev/null; sleep 0.1
  input_click; sleep 0.5
  [[ "$(shell_state)" == rest || "$(shell_state)" == media ]] && pass "a click off the pill closes the launcher" || fail "click off left $(shell_state)"
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((MX + MW / 2)), y = $((MY + 500)) })" >/dev/null
}
# Clipboard through the real bind path (Super+V runs this exec_cmd), right after a restart and on each
# monitor: the list is read on every open (it used to load once, never when opened straight in clip mode).
t_clip_live() {
  if ! command -v cliphist >/dev/null || [[ "$(cliphist list 2>/dev/null | grep -c .)" == 0 ]]; then pass "cliphist absent or empty: skipped"; return; fi
  local orig m i n; orig=$(focused_monitor)
  shell_restart; sleep 1
  for m in $(hyprctl monitors -j | python3 -c 'import json,sys;print(" ".join(m["name"] for m in json.load(sys.stdin)))'); do
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$m\" })" >/dev/null; sleep 0.5
    hyprctl dispatch 'hl.dsp.exec_cmd("qs -c hush ipc call hush showLauncher clip")' >/dev/null
    shell_wait_state launcher 60
    for i in $(seq 40); do n=$(shell_ipc launcherCount); [[ "$n" -gt 0 ]] && break; sleep 0.05; done
    [[ "$n" -gt 0 ]] && pass "$m: Super+V path lists $n clipboard entries" || fail "$m: clipboard list empty ($n)"
    assert_eq "$m" "$(shell_ipc islandScreen)" "$m: opens on the focused monitor"
    shell_ipc closeSurface >/dev/null; shell_wait_state rest 40 || shell_wait_state media 40
  done
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$orig\" })" >/dev/null
  shell_ipc showLauncher apps >/dev/null; shell_wait_state launcher; shell_wait_ipc launcherCount
  shell_ipc launcherQuery ";" >/dev/null; sleep 0.5
  n=$(shell_ipc launcherCount); [[ "$n" -gt 0 ]] && pass "; prefix lists $n entries" || fail "; prefix lists nothing"
  shell_ipc closeSurface >/dev/null; sleep 0.4
}
# One shell per session: a second `qs -c hush` (a restart that never stopped the first) ends the older
# instance, so no second island maps under the first one's exclusive zone (the launcher then drew as a
# box under a stray rest pill).
t_single() {
  local before after layers i
  before=$(session_pgrep -f "$HUSH_PROC" | head -1)
  (setsid qs -c hush >>"$HUSH_LOG" 2>&1 </dev/null &)
  for i in $(seq 40); do after=$(session_pgrep -f "$HUSH_PROC" | tr '\n' ' '); [[ "$after" != *"$before"* && -n "$after" ]] && break; sleep 0.25; done
  assert_eq "1" "$(session_pgrep -f "$HUSH_PROC" | wc -l)" "a second qs -c hush leaves one shell running"
  [[ "$after" != *"$before"* ]] && pass "the older instance ($before) ended, the newer ($after) stays" || fail "older instance still alive: $after"
  layers=$(hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin); print(sum(1 for m in d.values() for lv in m["levels"].values() for l in lv if l["namespace"]=="hush-island"))')
  assert_eq "$(hyprctl monitors -j | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')" "$layers" "one hush-island layer per monitor"
  for i in $(seq 40); do [[ "$(shell_ipc ping 2>/dev/null)" == pong ]] && break; sleep 0.25; done
  shell_restart
}
run_test "open" t_open
run_test "search" t_search
run_test "close" t_close
run_test "island" t_island
run_test "keyboard" t_keyboard
run_test "switch" t_switch
run_test "click off" t_click_off
run_test "clip live" t_clip_live
run_test "single instance" t_single
run_test "log" shell_log_check
finish

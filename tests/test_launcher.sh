#!/usr/bin/env bash
# Live test of the Hush launcher, driven entirely over IPC.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
launcher_mapped() { hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(sum(1 for m in d.values() for lv in m["levels"].values() for l in lv if l["namespace"]=="hush-launcher"))'; }
focused_monitor() { hyprctl monitors -j | python3 -c 'import json,sys;print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))'; }
launcher_monitor() { hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(n for n,m in d.items() for lv in m["levels"].values() for l in lv if l["namespace"]=="hush-launcher"))'; }

t_open() {
  shell_restart && pass "shell restarts" || fail "shell restart failed"
  sleep 1  # let the other shell surfaces map before grabbing focus
  assert_eq "false" "$(shell_ipc launcherVisible)" "launcher starts hidden"
  assert_eq "0" "$(launcher_mapped)" "no launcher layer while hidden"
  shell_ipc toggleLauncher; sleep 0.5
  assert_eq "true" "$(shell_ipc launcherVisible)" "toggleLauncher shows the launcher"
  shell_has_layer hush-launcher && pass "hush-launcher layer present" || fail "hush-launcher layer missing"
  assert_eq "1" "$(launcher_mapped)" "exactly one launcher surface (one monitor)"
  assert_eq "$(focused_monitor)" "$(launcher_monitor)" "launcher opens on the focused monitor"
}
t_search() {
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
  shell_ipc toggleLauncher; sleep 0.5
  assert_eq "false" "$(shell_ipc launcherVisible)" "toggleLauncher again hides it"
  assert_eq "0" "$(launcher_mapped)" "launcher layer unmapped after hide"
  shell_ipc showLauncher windows; sleep 0.5
  assert_eq "true" "$(shell_ipc launcherVisible)" "showLauncher windows opens it"
  local n; n=$(shell_ipc launcherCount)
  [[ "$n" -ge 1 ]] && pass "windows mode lists $n window(s)" || fail "windows mode lists nothing"
  shell_ipc toggleLauncher; sleep 0.3
}
t_island() {
  # Review Focus 3: launcher opened over the expanded island collapses the island.
  if ! shell_ipc islandState >/dev/null 2>&1; then echo "  SKIP island not built yet (islandState missing)"; return; fi
  shell_ipc toggleControlCenter; sleep 0.6
  shell_ipc toggleLauncher; sleep 0.6
  assert_eq "rest" "$(shell_ipc islandState)" "opening the launcher collapses the island"
  assert_eq "true" "$(shell_ipc launcherVisible)" "launcher visible over the island"
  shell_ipc toggleLauncher; sleep 0.3
}
t_keyboard() {
  # Review Focus 3: the launcher takes keyboard focus; Escape closes it and focus returns.
  if ! command -v wtype >/dev/null; then echo "  SKIP wtype not installed"; return; fi
  local before; before=$(hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))')
  shell_ipc toggleLauncher; sleep 0.5
  wtype "kit"; sleep 0.4
  shell_ipc launcherFirst | grep -qi kit && pass "typed text reaches the launcher" || fail "typing did not reach the launcher (first: $(shell_ipc launcherFirst))"
  wtype -k Escape; sleep 0.4
  assert_eq "false" "$(shell_ipc launcherVisible)" "Escape closes the launcher"
  assert_eq "$before" "$(hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))')" "focus returns to the previous window"
}
t_switch() {
  # Enter on a window result focuses it (and is not undone by the launcher's unmap).
  if ! command -v wtype >/dev/null; then echo "  SKIP wtype not installed"; return; fi
  local orig target title
  orig=$(hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))')
  read -r target title < <(hyprctl clients -j | python3 -c '
import json,sys
cs=[c for c in json.load(sys.stdin) if c["address"]!=sys.argv[1] and c["mapped"] and c["title"]]
print(cs[0]["address"], cs[0]["title"]) if cs else print("")' "$orig")
  if [[ -z "$target" ]]; then echo "  SKIP need a second window"; return; fi
  shell_ipc showLauncher windows; sleep 0.4
  shell_ipc launcherQuery "$title"; sleep 0.3
  if [[ "$(shell_ipc launcherFirst)" != "$title" ]]; then echo "  SKIP target title not ranked first"; shell_ipc toggleLauncher; return; fi
  wtype -k Return; sleep 0.6
  assert_eq "$target" "$(hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))')" "Enter focuses the chosen window"
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$orig\" })" >/dev/null; sleep 0.3
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "open" t_open
run_test "search" t_search
run_test "close" t_close
run_test "island" t_island
run_test "keyboard" t_keyboard
run_test "switch" t_switch
run_test "log" t_log
finish

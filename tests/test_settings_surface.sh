#!/usr/bin/env bash
# Settings surface in its own scratch Quickshell window (never touches the live shell).
# Writes ~/.config/hush/settings.json (island.width) and restores it.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H="tests/harness/settings.qml"
hq() { qs -p "$H" ipc call harness-settings "$@" 2>/dev/null; }
t_settings() {
  local f="$CFG/hush/settings.json" had=0; [[ -f $f ]] && { had=1; cp "$f" "$f.bak-test"; }
  qs -p "$H" >/dev/null 2>&1 & local pid=$!
  local up=0; for _ in $(seq 20); do sleep 0.3; [[ -n "$(hq size)" ]] && { up=1; break; }; done
  [[ $up == 1 ]] && pass "harness starts" || { fail "harness did not start"; kill "$pid" 2>/dev/null; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-settings"' && pass "layer hush-harness-settings present" || fail "layer missing"
  assert_eq "560x288" "$(hq size)" "declared size 560x288"
  assert_eq "$(tr -d '[:space:]' < VERSION)" "$(hq version)" "About reads VERSION"
  hq previewWidth 200 >/dev/null; sleep 0.2
  assert_eq "200" "$(hq shownWidth)" "drag previews without writing"
  hq setWidth 160 >/dev/null; sleep 0.6
  assert_eq "160" "$(python3 -c "import json;print(json.load(open('$f'))['island']['width'])")" "settings.json island.width == 160"
  assert_eq "160" "$(hq dataWidth)" "Settings.data.island.width == 160"
  hq setWidth 140 >/dev/null; sleep 0.6
  assert_eq "140" "$(hq dataWidth)" "restored to 140"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  if [[ $had == 1 ]]; then mv "$f.bak-test" "$f"; else rm -f "$f"; fi
}
run_test "settings surface" t_settings
finish

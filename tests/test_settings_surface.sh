#!/usr/bin/env bash
# Settings surface in its own scratch Quickshell window (never touches the live shell).
# Writes ~/.config/hush/settings.json (island.width) and restores it.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export QS_DISABLE_CRASH_HANDLER=1
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
  # New keys (v2): switches + the reveal slider on the Behaviour page, round trip through settings.json.
  hq setPage behaviour >/dev/null; sleep 0.3
  local t k
  for t in "Now playing OSD:nowPlayingOsd" "Fullscreen reveal:fullscreenReveal" "Fullscreen OSD:fullscreenOsd"; do
    k=${t#*:}; t=${t%%:*}
    assert_eq "true" "$(hq hasSwitch "$t")" "Behaviour has the \"$t\" switch"
    hq flip "$t" >/dev/null; sleep 0.6
    assert_eq "False" "$(python3 -c "import json;print(json.load(open('$f'))['island']['$k'])")" "$k false in settings.json after the switch"
    assert_eq "false" "$(hq dataOf island.$k)" "Settings.data.island.$k false"
    hq flip "$t" >/dev/null; sleep 0.6
    assert_eq "true" "$(hq dataOf island.$k)" "$k back to true"
  done
  assert_eq "true" "$(hq hasSlider "Reveal time")" "Behaviour has the reveal-time slider"
  assert_eq "ms" "$(hq unitOf "Reveal time")" "reveal slider is labelled in ms"
  assert_eq "1500" "$(hq shown motion.revealMs)" "reveal slider starts at the default 1500"
  hq previewKey motion.revealMs 2500 >/dev/null; sleep 0.2
  assert_eq "2500" "$(hq shown motion.revealMs)" "reveal drag previews"
  assert_eq "1500" "$(hq dataOf motion.revealMs)" "preview does not write motion.revealMs"
  hq slideTo "Reveal time" 3000 >/dev/null; sleep 0.6
  assert_eq "3000" "$(python3 -c "import json;print(json.load(open('$f'))['motion']['revealMs'])")" "settings.json motion.revealMs == 3000"
  hq stepSlider "Reveal time" 1 >/dev/null; sleep 0.6
  assert_eq "3100" "$(hq dataOf motion.revealMs)" "keyboard step moves the reveal slider by 100 ms"
  hq stepSlider "Reveal time" -10 >/dev/null; sleep 0.6
  assert_eq "2100" "$(hq dataOf motion.revealMs)" "Shift step is ten steps"
  assert_eq "1" "$(hq setPage island >/dev/null; sleep 0.2; hq hasSlider Width >/dev/null && echo 1)" "pages still list their sliders"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  if [[ $had == 1 ]]; then mv "$f.bak-test" "$f"; else rm -f "$f"; fi
}
run_test "settings surface" t_settings
finish

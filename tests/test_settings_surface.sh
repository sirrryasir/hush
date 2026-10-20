#!/usr/bin/env bash
# Settings surface in its own scratch Quickshell window (never touches the live shell).
# Writes ~/.config/hush/settings.json (island.width, lock.date, ...) and restores it.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export QS_DISABLE_CRASH_HANDLER=1
H="tests/harness/settings.qml"
hq() { qs -p "$H" ipc call harness-settings "$@" 2>/dev/null; }
t_settings() {
  local f="$CFG/hush/settings.json" had=0; [[ -f $f ]] && { had=1; cp "$f" "$f.bak-test"; }
  local stub; stub=$(mktemp -d); printf '#!/bin/sh\ncat >"%s/copied"\n' "$stub" >"$stub/wl-copy"; chmod +x "$stub/wl-copy"
  PATH="$stub:$PATH" qs -p "$H" >/dev/null 2>&1 & local pid=$!
  local up=0; for _ in $(seq 20); do sleep 0.3; [[ -n "$(hq size)" ]] && { up=1; break; }; done
  [[ $up == 1 ]] && pass "harness starts" || { fail "harness did not start"; kill "$pid" 2>/dev/null; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-settings"' && pass "layer hush-harness-settings present" || fail "layer missing"
  assert_eq "560x336" "$(hq size)" "declared size 560x336"
  assert_eq "$(tr -d '[:space:]' < VERSION)" "$(hq version)" "About reads VERSION"
  hq previewWidth 200 >/dev/null; sleep 0.2
  assert_eq "200" "$(hq shownWidth)" "drag previews without writing"
  hq setWidth 160 >/dev/null; sleep 0.6
  assert_eq "160" "$(python3 -c "import json;print(json.load(open('$f'))['island']['width'])")" "settings.json island.width == 160"
  assert_eq "160" "$(hq dataWidth)" "Settings.data.island.width == 160"
  hq setWidth 140 >/dev/null; sleep 0.6
  assert_eq "140" "$(hq dataWidth)" "restored to 140"
  # Switches + the reveal slider on the Behaviour page, round trip through settings.json.
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
  # Dropdown lists stay inside the 336 px surface (open upward near the bottom); the page starts below the header.
  assert_eq "true" "$([[ $(hq rowTop "Hover face") -ge 14 ]] && echo true)" "first row starts below the header padding"
  local b
  for t in Clock "Right click" Scroll; do
    hq dropOpen "$t" true >/dev/null; sleep 0.2; b=$(hq dropBox "$t")
    assert_eq "true" "$([[ ${b%,*} -ge 0 && ${b#*,} -le 336 ]] && echo true)" "$t list ($b) is inside the surface"
  done
  assert_eq "closed" "$(hq dropBox "Right click")" "opening one list closes the other"
  assert_eq "true" "$(hq pressEsc)" "Escape closes the open list first"
  assert_eq "closed" "$(hq dropBox Scroll)" "the list is closed"
  assert_eq "false" "$(hq pressEsc)" "Escape with no list open falls through to the page"
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
  # Modules page: the composer (layout.*). Rows render the normalised lists; buttons and the keyboard
  # hook reorder, switches and size toggles write settings.json, Reset layout drops the override.
  local J="python3 -c"
  hq setPage modules >/dev/null; hq setSection surfaces >/dev/null; sleep 0.2
  for t in Media Notifications Calendar Launcher Wallpapers Settings; do
    assert_eq "true" "$(hq hasSwitch "$t")" "Modules/Surfaces keeps the \"$t\" switch"
  done
  # the sandbox copies the live settings.json, which may carry a layout override: start from the defaults
  hq pressNamed resetLayout >/dev/null; sleep 0.6
  hq setSection hover >/dev/null; sleep 0.2
  assert_eq "workspaces,date,media,bluetooth,network,battery,keyboard,volume,brightness,timer,shelf,recording" "$(hq rows hover)" "hover rows in the default order"
  assert_eq "false" "$(hq enabledOf "hover|workspaces|up")" "first row: up is disabled"
  assert_eq "false" "$(hq enabledOf "hover|recording|down")" "last row: down is disabled"
  hq press "hover|date|down" >/dev/null; sleep 0.6
  assert_eq "workspaces,media,date" "$(hq rows hover | cut -d, -f1-3)" "down moves Date below Now playing"
  assert_eq "media" "$($J "import json;print(json.load(open('$f'))['layout']['hover'][1]['id'])")" "the order is in settings.json"
  assert_eq "hover|date|switch" "$(hq reorder "hover|date|switch" -1)" "Alt/Shift+Up hook on the row's switch returns the row key"
  sleep 0.6
  assert_eq "workspaces,date,media" "$(hq rows hover | cut -d, -f1-3)" "the key hook moved Date back up"
  assert_eq "" "$(hq reorder "hover|workspaces|switch" -1 >/dev/null; hq rows hover | cut -d, -f1 | grep -v workspaces)" "moving the first row up keeps it first"
  hq press "hover|workspaces|switch" >/dev/null; sleep 0.6
  assert_eq "date,media,bluetooth,network,battery,keyboard,shelf" "$(hq layoutHover)" "switch off: Workspaces leaves the hover face"
  hq press "hover|volume|switch" >/dev/null; sleep 0.6
  assert_eq "date,media,bluetooth,network,battery,keyboard,volume,shelf" "$(hq layoutHover)" "switch on: Volume joins it"
  assert_eq "date,media,bluetooth,network,battery,keyboard,volume,shelf" "$(hq previewChips)" "Hover face preview shows the enabled chips in order"
  hq press "hover|volume|switch" >/dev/null; sleep 0.6
  assert_eq "date,media,bluetooth,network,battery,keyboard,shelf" "$(hq previewChips)" "switching Volume off removes it from the preview"
  hq press "hover|volume|switch" >/dev/null; sleep 0.6
  assert_eq "" "$(hq unnamed)" "every control on the hover section has an accessible name"
  hq setSection cc >/dev/null; sleep 0.2
  assert_eq "wifi,bluetooth,vpn,airplane,dnd,nightlight,caffeine,timer,focus,recording,screenshot,lock,theme,wallpapers,settings" "$(hq rows cc)" "control center rows in the default order"
  hq press "cc|wifi|size" >/dev/null; sleep 0.6
  assert_eq "wifi:1x1" "$(hq layoutTiles | cut -d, -f1)" "size toggle: Wi-Fi tile 1x1"
  hq press "cc|lock|switch" >/dev/null; sleep 0.6
  assert_eq "true" "$(hq layoutTiles | grep -q 'lock:1x1' && echo true)" "switch on: Lock tile shown"
  hq press "cc|lock|up" >/dev/null; sleep 0.6
  assert_eq "lock,screenshot" "$(hq rows cc | cut -d, -f11-12)" "up moves Lock above Screenshot"
  hq pressNamed ccSection_sliders >/dev/null; sleep 0.6
  assert_eq "false" "$(hq ccSection sliders)" "Sliders chip hides the sliders row"
  assert_eq "False" "$($J "import json;print(json.load(open('$f'))['layout']['cc']['sliders'])")" "layout.cc.sliders false in settings.json"
  assert_eq "" "$(hq unnamed)" "every control on the control center section has an accessible name"
  hq setSection rest >/dev/null; sleep 0.2
  assert_eq "true" "$(hq hasSwitch "Left: activity")" "Rest has the activity switch"
  assert_eq "true" "$(hq hasSwitch "Right: status")" "Rest has the status switch"
  hq flip "Left: activity" >/dev/null; sleep 0.6
  assert_eq "none" "$(hq dataOf layout.rest.left)" "activity switch off: layout.rest.left none"
  assert_eq "" "$(hq unnamed)" "every control on the rest section has an accessible name"
  hq pressNamed resetLayout >/dev/null; sleep 0.6
  assert_eq "no" "$($J "import json;print('yes' if 'layout' in json.load(open('$f')) else 'no')")" "Reset layout drops the layout override"
  hq setSection hover >/dev/null; sleep 0.2
  assert_eq "workspaces,date,media,bluetooth,network,battery,keyboard,shelf" "$(hq layoutHover)" "after reset: default hover chips"
  assert_eq "true" "$(hq ccSection sliders)" "after reset: sliders back"
  # Lock page: settings.json lock.* (the lock and login screens); a switch writes its key.
  hq setPage lock >/dev/null; sleep 0.2
  assert_eq "lock" "$(hq page)" "Lock page opens"
  for t in Date Name "Reveal on key" "Status line"; do assert_eq "true" "$(hq hasSwitch "$t")" "Lock has the \"$t\" switch"; done
  hq flip Date >/dev/null; sleep 0.6
  assert_eq "False" "$($J "import json;print(json.load(open('$f'))['lock']['date'])")" "lock.date false in settings.json"
  hq flip Date >/dev/null; sleep 0.6
  assert_eq "true" "$(hq dataOf lock.date)" "lock.date back to true"
  # Shortcuts page: every IPC action as a row; the copy buttons put a bind block on the clipboard (fake wl-copy).
  hq setPage shortcuts >/dev/null; sleep 0.2
  local rows; rows=",$(hq shortcutRows),"
  for t in cc media notifs calendar launcher wallpapers settings shelf focus lock; do
    assert_eq "true" "$([[ $rows == *",$t,"* ]] && echo true)" "Shortcuts lists $t"
  done
  hq pressNamed copyHypr >/dev/null; sleep 0.5
  assert_contains "$stub/copied" "bind = SUPER, C" "Copy Hyprland binds puts the bind block on the clipboard"
  hq pressNamed copyLua >/dev/null; sleep 0.5
  assert_contains "$stub/copied" 'hl.bind("SUPER + C"' "Copy Lua binds puts the Lua block on the clipboard"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rm -rf "$stub"
  if [[ $had == 1 ]]; then mv "$f.bak-test" "$f"; else rm -f "$f"; fi
}
run_test "settings surface" t_settings
finish

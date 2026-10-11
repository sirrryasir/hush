#!/usr/bin/env bash
# Live test of the wallpaper grid, a modal surface inside the island, over IPC (the keybind calls
# toggleWallpapers). Picking a tile runs `hush wall <path> --from X,Y` with X,Y the tile's centre in
# global pixels, so it must land inside the focused monitor, below the pill's top.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
EVI="$HOME/.cache/hush/evidence"; mkdir -p "$EVI"
MOSS="$HUSH_ROOT/themes/moss/wallpaper.png"
O_THEME=$(bin/hush status | awk '/^theme /{print $2}'); O_WALL=$(bin/hush status | awk '/^wallpaper /{print $2}')
state() { shell_ipc islandState; }
wait_state() { local i; for i in $(seq "${2:-40}"); do [[ "$(state)" == "$1" ]] && return 0; sleep 0.05; done; return 1; }
wait_ipc() { local i v; for i in $(seq 40); do v=$(shell_ipc "$@"); [[ -n "$v" && "$v" != 0 ]] && return 0; sleep 0.05; done; return 1; }
restore() {
  [[ "$(bin/hush status | awk '/^wallpaper /{print $2}')" == "$O_WALL" ]] && return
  if [[ "$O_WALL" == "$HUSH_ROOT/themes/$O_THEME/wallpaper.png" ]]; then bin/hush theme "$O_THEME" >/dev/null 2>&1
  else bin/hush wall "$O_WALL" >/dev/null 2>&1; fi
}
trap 'shell_ipc closeSurface >/dev/null 2>&1; restore' EXIT
t_open() {
  shell_restart; sleep 2
  shell_ipc toggleWallpapers; wait_state wallpapers
  assert_eq "true" "$(shell_ipc wallpapersVisible)" "toggleWallpapers opens the grid in the island"
  local i; for i in $(seq 20); do [[ "$(shell_ipc islandSize)" == "656x320" ]] && break; sleep 0.05; done
  assert_eq "656x320" "$(shell_ipc islandSize)" "the pill grows to the grid (656x320 on the 8 px grid)"
  wait_ipc wallpapersCount
  local n; n=$(shell_ipc wallpapersCount)
  [[ "$n" -ge 6 ]] && pass "wallpapersCount $n >= 6" || fail "wallpapersCount $n"
  local other; other=$(hyprctl layers -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(sorted({l["namespace"] for m in d.values() for lv in m["levels"].values() for l in lv if l["namespace"].startswith("hush") and not l["namespace"].startswith("hush-island")})))')
  assert_eq "" "$other" "no hush layer besides hush-island*"
  grim "$EVI/wallpapers.png" 2>/dev/null
}
t_select() {
  local from x y; from=$(shell_ipc wallpapersSelect "$MOSS")
  wait_state rest || wait_state media
  assert_eq "false" "$(shell_ipc wallpapersVisible)" "picking a tile closes the grid"
  [[ "$from" =~ ^[0-9]+,[0-9]+$ ]] && pass "--from is integer X,Y ($from)" || fail "--from '$from'"
  x=${from%,*}; y=${from#*,}
  hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
w,h=round(m['width']/m['scale']),round(m['height']/m['scale'])
sys.exit(0 if m['x']<=$x<m['x']+w and m['y']+16<=$y<m['y']+360 else 1)" \
    && pass "the reveal origin is a tile centre on the focused monitor" || fail "origin $from is off the island area"
  local i; for i in $(seq 15); do bin/hush status | grep -q "^wallpaper $MOSS" && break; sleep 1; done
  bin/hush status | grep -q "^wallpaper $MOSS" && pass "status shows the moss wallpaper" || fail "wallpaper not applied"
  restore; sleep 1
  assert_eq "$O_WALL" "$(bin/hush status | awk '/^wallpaper /{print $2}')" "original wallpaper restored"
}
t_close() {
  shell_ipc toggleWallpapers; wait_state wallpapers
  assert_eq "true" "$(shell_ipc wallpapersVisible)" "reopens"
  shell_ipc toggleWallpapers; wait_state rest || wait_state media
  assert_eq "false" "$(shell_ipc wallpapersVisible)" "toggle closes"
  shell_ipc toggleControlCenter; wait_state expanded
  shell_ipc toggleWallpapers; wait_state wallpapers
  assert_eq "wallpapers" "$(state)" "the grid opens over the control center (CC Wallpapers button path)"
  shell_ipc toggleWallpapers; sleep 0.4
}
t_settings() {
  bin/hush settings; wait_state settings
  assert_eq "true" "$(shell_ipc settingsVisible)" "hush settings opens the settings surface"
  local i; for i in $(seq 20); do [[ "$(shell_ipc islandSize)" == "560x336" ]] && break; sleep 0.05; done
  assert_eq "560x336" "$(shell_ipc islandSize)" "settings is 560x336"
  grim "$EVI/settings.png" 2>/dev/null
  bin/hush settings; wait_state rest || wait_state media
  assert_eq "false" "$(shell_ipc settingsVisible)" "hush settings again closes it"
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "open" t_open
run_test "select" t_select
run_test "close" t_close
run_test "settings" t_settings
run_test "log" t_log
finish

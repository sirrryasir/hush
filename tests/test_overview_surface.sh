#!/usr/bin/env bash
# Overview surface in its own scratch Quickshell window over the real Hyprland windows (never touches
# the live shell, never sends input). Counts are compared with what hyprctl reports, so any open
# windows work.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export QS_DISABLE_CRASH_HANDLER=1
H="tests/harness/overview.qml"
hq() { qs -p "$H" ipc call harness-overview "$@" 2>/dev/null; }
HLOG=$(mktemp); PID=""
cleanup() { [[ -n "$PID" ]] && kill "$PID" 2>/dev/null; rm -f "$HLOG"; }
trap cleanup EXIT
start() { # [screen]
  [[ -n "$PID" ]] && { kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; }
  HUSH_OVERVIEW_SCREEN="${1:-}" qs -p "$H" >>"$HLOG" 2>&1 & PID=$!
  local i; for i in $(seq 30); do sleep 0.2; [[ -n "$(hq size)" ]] && break; done
  sleep 0.5; [[ -n "$(hq size)" ]]
}
live() { hyprctl -j clients | jq "[.[] | select(.mapped and .workspace.id == $1)] | length"; }
WS=$(hyprctl -j activeworkspace | jq .id)

t_surface() {
  start && pass "harness starts" || { fail "harness did not start"; return; }
  assert_eq "672x474" "$(hq size)" "declared size 672x474"
  local n; n=$(hq cellCount); (( n >= 5 )) && pass "strip has $n cells" || fail "strip has $n cells"
  assert_eq "$WS" "$(hq shownWorkspace)" "shows the focused workspace on open"
  assert_eq "$(live "$WS")" "$(hq thumbCount)" "one thumbnail per mapped window of workspace $WS"
  # Stage: 640x360 (card 672x474, 16 px margins, 68 px strip, 14 px gap).
  local r x y w h ok=1 rects; rects=$(hq thumbRects | tr -d '"')
  IFS=';' read -ra rs <<<"$rects"
  for r in "${rs[@]}"; do
    IFS=, read -r x y w h <<<"$r"
    (( w > 0 && h > 0 && x >= 0 && y >= 0 && x + w <= 640 && y + h <= 360 )) || { ok=0; fail "rect out of the stage: $r"; }
  done
  (( ok )) && pass "every thumbnail sits inside the stage (${rects:-none})"
  if (( $(live "$WS") > 0 )); then
    assert_eq "false" "$(hq moveSame)" "dropping a window on its own workspace does nothing"
    hq keepThumb >/dev/null; sleep 0.6
    assert_eq "true" "$(hq sameThumb)" "a toplevel refresh keeps the live thumbnail (no rebuild)"
  else pass "no window on workspace $WS: same-workspace drop and refresh checks skipped"; fi
}
t_steps() {
  local ids; ids=$(hq cellIds | tr -d '"'); IFS=, read -ra id <<<"$ids"
  hq hoverCell 0 >/dev/null; assert_eq "${id[0]}" "$(hq shownWorkspace)" "hoverCell 0 shows the first cell"
  hq stepShown 1 >/dev/null; assert_eq "${id[1]}" "$(hq shownWorkspace)" "stepShown 1 shows the next cell"
  hq stepShown -1 >/dev/null; hq stepShown -1 >/dev/null
  assert_eq "${id[-1]}" "$(hq shownWorkspace)" "stepShown wraps to the last cell"
  local i empty=-1; for i in "${!id[@]}"; do [[ $(live "${id[$i]}") == 0 ]] && { empty=$i; break; }; done
  if (( empty >= 0 )); then
    hq hoverCell "$empty" >/dev/null; assert_eq "0" "$(hq thumbCount)" "an empty workspace shows no thumbnails"
  else pass "no empty workspace in the strip (skipped)"; fi
  hq requestClose >/dev/null; assert_eq "true" "$(hq closed)" "close() reaches the host"
}
t_unknown_screen() {
  start nope && pass "harness starts on an unknown screen" || { fail "harness did not start"; return; }
  local n; n=$(hq cellCount); (( n > 0 )) && pass "falls back to the focused monitor ($n cells)" || fail "no cells"
  assert_eq "$(live "$WS")" "$(hq thumbCount)" "fallback still counts the focused workspace's windows"
  local e; e=$(grep -E "TypeError|ReferenceError" "$HLOG" | head -3)
  [[ -z "$e" ]] && pass "no errors in harness log" || fail "harness log errors: $e"
}
run_test "overview surface" t_surface
run_test "shown workspace steps" t_steps
run_test "unknown screen" t_unknown_screen
finish

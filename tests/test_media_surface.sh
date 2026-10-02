#!/usr/bin/env bash
# Media surface (Task 9): the harness (tests/harness/media.qml) shows it at its declared size, the cava
# process exists only while it is shown and is gone 1 s after the harness exits. A stub cava in
# tests/harness/bin stands in for the real one; a fake MPRIS player supplies the track.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
HP=""; FP=""
cleanup() { [[ -n "$HP" ]] && kill "$HP" 2>/dev/null; [[ -n "$FP" ]] && kill "$FP" 2>/dev/null; true; }
trap cleanup EXIT
cava_pids() { pgrep -f 'hush-cava\.conf'; }
layer() { hyprctl layers -j | python3 -c "
import json,sys
for m in json.load(sys.stdin).values():
  for lvl in m['levels'].values():
    for l in lvl:
      if l['namespace']=='hush-harness-media': print(l['w'], l['h'])"; }
t_media_surface() {
  if ! command -v qs >/dev/null || ! command -v hyprctl >/dev/null || [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then echo "SKIPPED: needs qs and a running Hyprland"; return 0; fi
  HUSH_FAKE_NAME=hushfake_surface python3 tests/fakempris.py & FP=$!
  PATH="$PWD/tests/harness/bin:$PATH" qs -p tests/harness/media.qml >/tmp/hush-harness-media.log 2>&1 & HP=$!
  local i; for i in $(seq 20); do [[ -n "$(layer)" ]] && break; sleep 0.5; done
  assert_eq "420 180" "$(layer | head -1)" "harness layer appears at the declared 420x180"
  sleep 1
  [[ -n "$(cava_pids)" ]] && pass "cava runs while the surface is shown" || fail "no cava process while shown"
  kill "$HP"; wait "$HP" 2>/dev/null; HP=""; sleep 1
  [[ -z "$(cava_pids)" ]] && pass "cava is gone 1 s after the harness exits" || fail "cava still running after harness exit"
  grep -q 'ERROR\|TypeError\|ReferenceError' /tmp/hush-harness-media.log && fail "errors in harness log" || pass "no errors in harness log"
}
run_test "media surface" t_media_surface
finish

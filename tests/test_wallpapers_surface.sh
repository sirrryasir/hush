#!/usr/bin/env bash
# Wallpapers surface in its own scratch Quickshell window (never touches the live shell); `hush` is stubbed on PATH.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H="tests/harness/wallpapers.qml"
hq() { qs -p "$H" ipc call harness-wallpapers "$@" 2>/dev/null; }
t_wallpapers() {
  local stub; stub=$(mktemp -d)
  printf '#!/bin/sh\necho "$@" > "%s/args"\n' "$stub" > "$stub/hush"; chmod +x "$stub/hush"
  PATH="$stub:$PATH" qs -p "$H" >/dev/null 2>&1 & local pid=$!
  local up=0; for _ in $(seq 25); do sleep 0.3; [[ -n "$(hq size)" ]] && { up=1; break; }; done
  [[ $up == 1 ]] && pass "harness starts" || { fail "harness did not start"; kill "$pid" 2>/dev/null; rm -rf "$stub"; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-wallpapers"' && pass "layer present" || fail "layer missing"
  assert_eq "620x340" "$(hq size)" "declared size 620x340"
  sleep 0.5
  local n; n=$(hq count)
  [[ "${n:-0}" -ge 6 ]] && pass "count >= 6 ($n)" || fail "count >= 6 (got '$n')"
  local p; p=$(hq select 0)
  [[ "$p" == */wallpaper.png || "$p" == /* ]] && [[ -f "$p" ]] && pass "select(0) returns an existing path" || fail "select(0) path ('$p')"
  sleep 0.5
  local args; args=$(cat "$stub/args" 2>/dev/null)
  [[ "$args" == "wall $p --from "* ]] && pass "hush wall <path> --from run" || fail "hush args: '$args'"
  [[ "$args" =~ --from\ [0-9]+,[0-9]+$ ]] && pass "--from is integer X,Y" || fail "--from format: '$args'"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rm -rf "$stub"
}
run_test "wallpapers surface" t_wallpapers
finish

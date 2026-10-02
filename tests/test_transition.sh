#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H=bin/hush
# Stub awww records its args; PATH-shadowed so the real daemon is untouched.
stub() { local d; d=$(mktemp -d); printf '#!/bin/sh\n[ "$1" = query ] && exit 0\necho "$@" >> %s/args\n' "$d" > "$d/awww"; chmod +x "$d/awww"; echo "$d"; }
t_live() {
  local w="$PWD/themes/moss/wallpaper.png" t0=$SECONDS ok=""
  $H wall "$w" --from 100,100 >/dev/null 2>&1 || fail "wall --from runs"
  for _ in $(seq 1 20); do awww query 2>/dev/null | grep -q "moss/wallpaper.png" && { ok=1; break; }; sleep 0.1; done
  [[ -n "$ok" ]] && pass "awww query shows the new image" || fail "awww query lacks new image"
  $H theme harbor >/dev/null 2>&1; pass "restored harbor"
}
t_args() {
  local d; d=$(stub)
  PATH="$d:$PATH" HUSH_REDUCED_MOTION= $H wall themes/moss/wallpaper.png --from 100,100 >/dev/null 2>&1
  assert_contains "$d/args" "--transition-type grow --transition-pos 100,100 --transition-duration 0.9 --transition-fps 60 --transition-bezier .16,1,.3,1" "grow args with --from"
  : > "$d/args"
  PATH="$d:$PATH" HUSH_REDUCED_MOTION=1 $H wall themes/moss/wallpaper.png --from 100,100 >/dev/null 2>&1
  assert_contains "$d/args" "--transition-type simple --transition-step 255" "reduced motion uses simple"
  : > "$d/args"
  PATH="$d:$PATH" HUSH_REDUCED_MOTION= $H wall themes/moss/wallpaper.png >/dev/null 2>&1
  assert_contains "$d/args" "--transition-pos " "default pos is the island centre"
  rm -rf "$d"
  $H theme harbor >/dev/null 2>&1
}
t_bad() {
  assert_exit 1 "invalid --from rejected (wall)" $H wall themes/moss/wallpaper.png --from 1.5,x
  assert_exit 1 "invalid --from rejected (theme)" $H theme harbor --from nope
  assert_exit 1 "missing --from value rejected" $H wall themes/moss/wallpaper.png --from
}
run_test "live transition" t_live
run_test "transition args" t_args
run_test "bad --from" t_bad
finish

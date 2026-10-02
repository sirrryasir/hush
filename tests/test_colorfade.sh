#!/usr/bin/env bash
# Colour cross-fade: a scratch harness (never the live shell) with HOME pointed at a temp dir. Colors.json is
# swapped between two themes' generated outputs and a swatch is sampled with grim.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H="tests/harness/colorfade.qml"
TMP=$(mktemp -d); trap 'kill $PID 2>/dev/null; rm -rf "$TMP"' EXIT
hq() { HOME="$TMP/home" qs -p "$H" ipc call harness-colorfade "$@" 2>/dev/null; }
gen() { # theme outfile: matugen output for the theme's wallpaper
  local t=$1 mode scheme out="$TMP/gen-$1"
  mode=$(sed -n 's/^mode = "\(.*\)"/\1/p' themes/$t/theme.toml); scheme=$(sed -n 's/^scheme = "\(.*\)"/\1/p' themes/$t/theme.toml)
  test_matugen_cfg "$out" colors-json > "$TMP/$t.toml"
  matugen image "themes/$t/wallpaper.png" -c "$TMP/$t.toml" -m "$mode" -t "$scheme" --source-color-index 0 -q >/dev/null 2>&1
  cp "$out/hush/Colors.json" "$TMP/$t.json"
}
swatch() { # prints "r g b" at the centre of the harness layer
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
for m in json.load(sys.stdin).values():
  for l in m['levels'].values():
    for x in l:
      if x['namespace']=='hush-harness-colorfade': print('%d,%d 1x1'%(x['x']+60,x['y']+60))")
  grim -g "$g" -t ppm - | tail -c 3 | od -An -tu1
}
start() { # reduced(0/1): fresh scratch HOME with harbor's palette, harness up
  rm -rf "$TMP/home"; mkdir -p "$TMP/home/.config/hush"; cp "$TMP/harbor.json" "$TMP/home/.config/hush/Colors.json"
  [[ $1 == 1 ]] && echo '{"island":{"reducedMotion":true}}' > "$TMP/home/.config/hush/settings.json"
  HOME="$TMP/home" qs -p "$H" >/dev/null 2>&1 & PID=$!
  for _ in $(seq 30); do sleep 0.3; [[ "$(hq loaded)" == true ]] && break; done
  sleep 0.5
}
swap() { cp "$TMP/paper.json" "$TMP/home/.config/hush/Colors.json.new"; mv "$TMP/home/.config/hush/Colors.json.new" "$TMP/home/.config/hush/Colors.json"; }
wait_start() { for _ in $(seq 100); do [[ "$(hq started)" != 0 ]] && return 0; sleep 0.01; done; return 1; }
# Milliseconds since the fade began, sampled after sleeping $1 s; prints "ms r g b".
sample_at() {
  local t0 now; t0=$(hq started); sleep "$1"; read -r r g b <<<"$(swatch)"; now=$(date +%s%3N)
  echo "$((now - t0)) $r $g $b"
}
hexrgb() { python3 -c "h='$1'.lstrip('#');print(*[int(h[i:i+2],16) for i in (0,2,4)])"; }
dist() { python3 -c "import sys;a=list(map(int,'$1'.split()));b=list(map(int,'$2'.split()));print(max(abs(x-y) for x,y in zip(a,b)))"; }
t_full() {
  start 0
  local from to; from=$(hexrgb "$(python3 -c "import json;print(json.load(open('$TMP/harbor.json'))['primary'])")")
  to=$(hexrgb "$(python3 -c "import json;print(json.load(open('$TMP/paper.json'))['primary'])")")
  assert_eq "$from" "$(swatch | xargs)" "t=0 swatch is the old palette"
  assert_eq "400" "$(hq fadeMs)" "fade is 400 ms"
  swap; wait_start
  local m r; m=$(sample_at 0.07); read -r _ r <<<"$m"; r=$(cut -d' ' -f2- <<<"$m")
  local d_from d_to; d_from=$(dist "$r" "$from"); d_to=$(dist "$r" "$to")
  echo "  sample at $(cut -d' ' -f1 <<<"$m") ms: $r (from $from, to $to)"
  [[ $d_from -gt 3 && $d_to -gt 3 ]] && pass "~200 ms swatch is intermediate" || fail "~200 ms swatch not intermediate ($r)"
  sleep 0.4; assert_eq "$to" "$(swatch | xargs)" "after 400 ms swatch is the new palette"
  kill $PID; wait $PID 2>/dev/null
}
t_reduced() {
  start 1
  local to; to=$(hexrgb "$(python3 -c "import json;print(json.load(open('$TMP/paper.json'))['primary'])")")
  assert_eq "160" "$(hq fadeMs)" "reduced motion fade is 160 ms"
  swap; wait_start
  # Poll until the swatch is final; allow ~80 ms for grim's capture latency on top of the 200 ms budget.
  local t0 now ms=-1; t0=$(hq started)
  for _ in $(seq 20); do
    if [[ "$(swatch | xargs)" == "$to" ]]; then now=$(date +%s%3N); ms=$((now - t0)); break; fi
  done
  echo "  final after ${ms} ms"
  [[ $ms -ge 0 && $ms -le 280 ]] && pass "reduced-motion swatch final within 200 ms (+grim latency)" || fail "reduced-motion fade too slow (${ms} ms)"
  kill $PID; wait $PID 2>/dev/null
}
t_gen() { gen harbor; gen paper; assert_file "$TMP/harbor.json" "harbor generated"; assert_file "$TMP/paper.json" "paper generated"; }
run_test "generate palettes" t_gen
run_test "full-motion cross-fade" t_full
run_test "reduced-motion cross-fade" t_reduced
finish

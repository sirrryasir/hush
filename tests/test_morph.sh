#!/usr/bin/env bash
# Island v2 morph (design 2.5): the pill springs between declared sizes, interruptibly, with staged
# content. A frame sequence (grim every 40 ms) across an expand that is reversed 300 ms in must show
# no width jump over 40 px between consecutive frames (frames delayed past 60 ms by the capture get a
# proportional allowance), never exceed the expanded width, and return to the starting width.
# With reduced motion the same expand settles in under 150 ms. Runs on the focused monitor.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
F="$HOME/.config/hush/settings.json"; BAK=$(mktemp)
if [[ -f "$F" ]]; then cp "$F" "$BAK"; HAD=1; else HAD=0; fi
collapse() { [[ "$(shell_ipc islandState 2>/dev/null)" == expanded ]] && shell_ipc toggleControlCenter >/dev/null 2>&1; }
cleanup() { collapse; if [[ $HAD == 1 ]]; then cp "$BAK" "$F"; else rm -f "$F"; fi; rm -f "$BAK"; sleep 0.5; }
trap cleanup EXIT

shell_alive || { fail "shell not running"; exit 1; }
# A lock screen covers every layer, so frames would only show it; nothing to measure.
if pgrep -x hyprlock >/dev/null; then echo "  SKIP session locked (hyprlock covers the island)"; exit 0; fi
for f in quickshell/hush/modules/island/Pill.qml quickshell/hush/modules/island/SurfaceLoader.qml quickshell/hush/config/Sizes.qml; do
  assert_file "$f" "$(basename "$f") exists"
done
assert_contains quickshell/hush/modules/island/Pill.qml "SpringAnimation" "pill dimensions spring"
assert_eq true "$(shell_ipc settingsGet motion.springCalm | python3 -c 'import json,sys;d=json.load(sys.stdin);print(str(d["spring"]>0 and 0<d["damping"]<=1).lower())')" "calm spring settings present"

# Wait out transients (OSD, a notification) so the run starts from a resting capsule.
for _ in $(seq 20); do case "$(shell_ipc islandState)" in rest|media) break;; esac; sleep 0.5; done
START=$(shell_ipc islandState)
read -r X Y W TOP < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), $(shell_ipc settingsGet island.topGap || echo 6))")
GX=$((X + W / 2 - 320)); ROW=$((TOP + 18))
EXP=560

frames() { python3 tests/morph_frames.py "$GX" "$Y" 640 50 "$ROW" "$1" "$2"; }

# 1. Expand, reverse 300 ms in.
shell_ipc morphProbe 250 300 >/dev/null
OUT=$(frames 40 1500)
REPORT=$(python3 -c "
import json,sys
f=json.loads(sys.argv[1])['frames']; base=f[0][1]
jumps=[(abs(b[1]-a[1]), b[0]-a[0]) for a,b in zip(f,f[1:])]
bad=[j for j in jumps if j[0] > 40*max(1, j[1]/60)]
print(base, max(w for _,w in f), max(j for j,_ in jumps), len(bad), f[-1][1])
print(' '.join(f'{t}:{w}' for t,w in f), file=sys.stderr)" "$OUT")
read -r BASE PEAK MAXJ BAD LAST <<<"$REPORT"
[[ -n "$LAST" ]] || { fail "frame capture failed (no pill on the baseline row)"; exit 1; }
echo "  widths: base $BASE peak $PEAK max jump $MAXJ last $LAST"
[[ $PEAK -gt $((BASE + 40)) ]] && pass "pill grew toward the panel (peak $PEAK)" || fail "pill did not grow (peak $PEAK, base $BASE)"
[[ $PEAK -le $EXP ]] && pass "no frame wider than the target $EXP" || fail "frame width $PEAK exceeds $EXP"
[[ $BAD -eq 0 ]] && pass "no consecutive-frame jump over 40 px (max $MAXJ)" || fail "$BAD frame jumps over 40 px (max $MAXJ)"
[[ $((LAST - BASE)) -le 2 && $((BASE - LAST)) -le 2 ]] && pass "reversal returns to the start width" || fail "ended at $LAST, started at $BASE"
assert_eq "$START" "$(shell_ipc islandState)" "state back to $START after the reversal"
assert_eq "$START/$START/1.00" "$(shell_ipc islandStage)" "content staged back in (shape/shown/opacity)"

# 2. Reduced motion: the same expand settles within 150 ms.
shell_ipc settingsSet island.reducedMotion true >/dev/null; sleep 0.5
shell_ipc morphProbe 250 0 >/dev/null
OUT=$(frames 10 800)
MS=$(python3 -c "
import json,sys
f=json.loads(sys.argv[1])['frames']; base=f[0][1]
last_rest=max((t for t,w in f if w<=base+1), default=None)
done=next((t for t,w in f if w>=$EXP-2), None)
print(-1 if last_rest is None or done is None else done-last_rest)" "$OUT")
[[ -n "$MS" && $MS -ge 0 && $MS -lt 150 ]] && pass "reduced motion expand settles in $MS ms (< 150)" || fail "reduced motion expand took $MS ms"
collapse; sleep 0.6
assert_eq "$START" "$(shell_ipc islandState)" "collapsed after the reduced run"

errs=$(shell_log_errors) && pass "no QML errors in the log" || fail "log errors: $errs"
[[ $_HUSH_TEST_FAILS -eq 0 ]]

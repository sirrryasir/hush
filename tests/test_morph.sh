#!/usr/bin/env bash
# Island v2 morph: the pill springs between declared sizes, interruptibly, with staged
# content. A frame sequence (grim every 40 ms) across an expand that is reversed 130 ms in must keep
# its velocity continuous: each frame's width jump is at most twice the previous jump plus 8 px
# (both scaled to the frame interval; repeated frames from the capture are merged). A leg's start
# lands somewhere inside a frame, so its first two frames (three after the reversal, which waits
# up to 50 ms for the content to fade out) are only bounded at half the travel per 40 ms. No frame
# overshoots the target by more than 4 px, and the run returns to the starting width. The calm
# spring opens the control center within 350 ms; with reduced motion the expand settles in under
# 150 ms. Runs on the focused monitor.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
shell_settings_save
collapse() { [[ "$(shell_ipc islandState 2>/dev/null)" == expanded ]] && shell_ipc toggleControlCenter >/dev/null 2>&1; }
cleanup() { collapse; shell_settings_restore; sleep 0.5; }
trap cleanup EXIT

shell_alive || { fail "shell not running"; exit 1; }
# A lock screen covers every layer, so frames would only show it; nothing to measure.
if session_pgrep -x hyprlock >/dev/null; then echo "  SKIP session locked (hyprlock covers the island)"; exit 0; fi
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

# 1. Expand, reverse 130 ms in (about half way with the calm spring).
shell_ipc morphProbe 500 130 >/dev/null
OUT=$(frames 40 1500)
REPORT=$(python3 -c "
import json,sys
f=json.loads(sys.argv[1])['frames']; base=f[0][1]; exp=$EXP
# Mid-motion repeats (the capture returned the same picture twice) merge into the next change.
g=[f[0]]
for b in f[1:]:
  if b[1]==g[-1][1] and len(g)>1 and g[-1][1]!=g[-2][1]: continue
  g.append(b)
travel=max(1,exp-base); bad=[]; prev=None; leg=0; legs=0
for a,b in zip(g,g[1:]):
  d=b[1]-a[1]; dt=max(1,b[0]-a[0])
  if d==0: leg=0; prev=None; continue
  if prev is None or (d>0)!=(prev[0]>0): leg=1; legs+=1
  else: leg+=1
  if leg<=(2 if legs==1 else 3):
    if abs(d)>0.5*travel*max(1,dt/40): bad.append((b[0],d,'leg start'))
  else:
    lim=2*abs(prev[0])*dt/prev[1]+8*dt/40
    if abs(d)>lim: bad.append((b[0],d,round(lim)))
  prev=(d,dt)
jumps=[abs(b[1]-a[1]) for a,b in zip(g,g[1:])] or [0]
print(base, max(w for _,w in f), max(jumps), len(bad), f[-1][1], min(w for _,w in f))
print(' '.join(f'{t}:{w}' for t,w in f), bad, file=sys.stderr)" "$OUT")
read -r BASE PEAK MAXJ BAD LAST LOW <<<"$REPORT"
[[ -n "$LAST" ]] || { fail "frame capture failed (no pill on the baseline row)"; exit 1; }
echo "  widths: base $BASE peak $PEAK max jump $MAXJ last $LAST"
[[ $PEAK -gt $((BASE + 40)) ]] && pass "pill grew toward the panel (peak $PEAK)" || fail "pill did not grow (peak $PEAK, base $BASE)"
[[ $PEAK -le $((EXP + 4)) ]] && pass "no frame overshoots $EXP by more than 4 px" || fail "frame width $PEAK overshoots $EXP"
[[ $LOW -ge $((BASE - 4)) ]] && pass "no undershoot below the start width on return" || fail "frame width $LOW under the start $BASE"
[[ $BAD -eq 0 ]] && pass "velocity continuous: no jump over 2x the previous + 8 px (max jump $MAXJ)" || fail "$BAD discontinuous frame jumps (max $MAXJ)"
[[ $((LAST - BASE)) -le 2 && $((BASE - LAST)) -le 2 ]] && pass "reversal returns to the start width" || fail "ended at $LAST, started at $BASE"
assert_eq "$START" "$(shell_ipc islandState)" "state back to $START after the reversal"
assert_eq "$START/$START/1.00" "$(shell_ipc islandStage)" "content staged back in (shape/shown/opacity)"

# 2. Calm spring: the control center opens (within 4 px of its width) in at most 350 ms.
settle_ms() { python3 -c "
import json,sys
f=json.loads(sys.argv[1])['frames']; base=f[0][1]
last_rest=max((t for t,w in f if w<=base+1), default=None)
done=next((t for t,w in f if w>=$EXP-4 and last_rest is not None and t>last_rest), None)
print(-1 if last_rest is None or done is None else done-last_rest)" "$1"; }
shell_ipc morphProbe 500 0 >/dev/null
OUT=$(frames 10 1100)
MS=$(settle_ms "$OUT"); [[ "$MS" == -1 ]] && python3 -c "import json,sys;print(json.loads(sys.argv[1])['frames'])" "$OUT"
[[ -n "$MS" && $MS -ge 0 && $MS -le 350 ]] && pass "control center opens in $MS ms (<= 350)" || fail "control center open took $MS ms"
collapse; sleep 0.8

# 3. Reduced motion: the same expand settles within 150 ms.
shell_ipc settingsSet island.reducedMotion true >/dev/null; sleep 0.5
shell_ipc morphProbe 500 0 >/dev/null
OUT=$(frames 10 1000)
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

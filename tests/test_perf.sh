#!/usr/bin/env bash
# Island performance gate (plan Task 17b), live shell. Prints a table and asserts:
#  1 idle at rest, no media: CPU < 1 % and < 50 voluntary ctx switches/s over 20 s
#  2 same with a playing MPRIS player (activity ring animating): CPU < 1.5 %, no cava while the media surface is closed
#  3 every surface opened and closed 3x over IPC: idle CPU < 1 % within 10 s, RSS growth < 20 MB (leak smoke)
#  4 reduced motion: the control center opens in <= 150 ms (morphProbe + frame capture), setting restored
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
F="$HOME/.config/hush/settings.json"; BAK=$(mktemp); if [[ -f "$F" ]]; then cp "$F" "$BAK"; HAD=1; else HAD=0; fi
FP=""; ROWS=()
collapse() { shell_ipc closeSurface >/dev/null 2>&1; }
cleanup() { collapse; [[ -n "$FP" ]] && kill "$FP" 2>/dev/null
  if [[ $HAD == 1 ]]; then cp "$BAK" "$F"; else rm -f "$F"; fi; rm -f "$BAK"; }
trap cleanup EXIT
shell_alive || { fail "shell not running"; exit 1; }
pgrep -x hyprlock >/dev/null && { echo "  SKIP session locked"; exit 0; }
PID=$(pgrep -f "$HUSH_PROC" | head -1)
rss_kb() { awk '/VmRSS/{print $2}' /proc/$PID/status; }
# sample SECONDS -> "cpu% ctxt/s"
sample() { python3 - "$PID" "$1" <<'PY'
import os,sys,time
pid,secs=sys.argv[1],float(sys.argv[2]); hz=os.sysconf('SC_CLK_TCK')
def cpu(): f=open(f'/proc/{pid}/stat').read().rsplit(')',1)[1].split(); return int(f[11])+int(f[12])
def cs():
    for l in open(f'/proc/{pid}/status'):
        if l.startswith('voluntary_ctxt_switches'): return int(l.split()[1])
a,c,t=cpu(),cs(),time.time(); time.sleep(secs); dt=time.time()-t
print('%.2f %.1f' % ((cpu()-a)/hz/dt*100, (cs()-c)/dt))
PY
}
lt() { python3 -c "import sys;sys.exit(0 if float('$1')<float('$2') else 1)"; }
cava_n() { pgrep -fc 'hush-cava\.conf' || true; }
settle() { for _ in $(seq 30); do case "$(shell_ipc islandState)" in rest) return;; esac; sleep 0.5; done; }

collapse; settle; sleep 2
# 1. idle, no media
read -r C1 S1 <<<"$(sample 20)"
lt "$C1" 1 && pass "idle CPU $C1 % (< 1)" || fail "idle CPU $C1 % (>= 1)"
lt "$S1" 50 && pass "idle ctx switches $S1/s (< 50)" || fail "idle ctx switches $S1/s (>= 50)"

# 2. media playing, surfaces closed
HUSH_FAKE_NAME=hushfake_perf python3 tests/fakempris.py & FP=$!
sleep 4; settle; sleep 1
read -r C2 S2 <<<"$(sample 20)"
N2=$(cava_n)
lt "$C2" 1.5 && pass "media playing CPU $C2 % (< 1.5)" || fail "media playing CPU $C2 % (>= 1.5)"
lt "$S2" 50 && pass "media playing ctx switches $S2/s (< 50)" || fail "media playing ctx switches $S2/s (>= 50)"
assert_eq 0 "$N2" "no cava process while the media surface is closed"

# 3. open/close every surface 3x, then idle again
cycle() { local s; for s in expanded mediaSurface calendar wallpapers settings notifCenter launcher; do
  shell_ipc openSurface "$s" >/dev/null; sleep 0.9; shell_ipc closeSurface >/dev/null; sleep 0.7; done; }
# One warm-up pass first: lazy Loaders and image caches (a cold shell grew 54 MB on the first
# wallpapers/launcher open) are not leaks; the baseline is taken after it.
cycle; settle; sleep 1
R0=$(rss_kb)
for _ in 1 2 3; do cycle; done
settle; sleep 1
T0=$SECONDS; C3=""; 
while :; do read -r C3 _ <<<"$(sample 3)"; lt "$C3" 1 && break; [[ $((SECONDS-T0)) -ge 10 ]] && break; done
R1=$(rss_kb); D=$(( (R1 - R0) / 1024 )); N3=$(cava_n)
lt "$C3" 1 && pass "CPU back to $C3 % within $((SECONDS-T0)) s of settling" || fail "CPU still $C3 % 10 s after the surface cycle"
[[ $D -lt 20 ]] && pass "RSS grew $D MB (< 20)" || fail "RSS grew $D MB (>= 20)"
assert_eq 0 "$N3" "no cava after all surfaces closed"
kill "$FP" 2>/dev/null; FP=""

# 4. reduced motion open time
read -r X Y W TOP < <(hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['focused'])
print(m['x'], m['y'], round(m['width']/m['scale']), $(shell_ipc settingsGet island.topGap || echo 6))")
settle; sleep 1.5
shell_ipc settingsSet island.reducedMotion true >/dev/null; sleep 0.5
shell_ipc morphProbe 500 0 >/dev/null
OUT=$(python3 tests/morph_frames.py "$((X + W / 2 - 320))" "$Y" 640 50 "$((TOP + 18))" 10 1000)
MS=$(python3 -c "
import json,sys
f=json.loads(sys.argv[1])['frames']; base=f[0][1]
lr=max((t for t,w in f if w<=base+1), default=None)
d=next((t for t,w in f if w>=560-2), None)
print(-1 if lr is None or d is None else d-lr)" "$OUT")
collapse
shell_ipc settingsSet island.reducedMotion false >/dev/null
[[ -n "$MS" && $MS -ge 0 && $MS -le 150 ]] && pass "reduced motion control center open $MS ms (<= 150)" || fail "reduced motion open $MS ms"

printf '\n  %-44s %-12s %s\n' gate measured limit
printf '  %-44s %-12s %s\n' "1 idle CPU" "$C1 %" "< 1 %" "1 idle ctx switches" "$S1 /s" "< 50 /s" \
  "2 media CPU" "$C2 %" "< 1.5 %" "2 media ctx switches" "$S2 /s" "< 50 /s" "2 cava procs (closed)" "$N2" "0" \
  "3 CPU after surface cycle" "$C3 %" "< 1 %" "3 RSS growth" "$D MB" "< 20 MB" "4 reduced-motion open" "$MS ms" "<= 150 ms"
finish

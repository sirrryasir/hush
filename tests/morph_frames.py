#!/usr/bin/env python3
"""Frame-sequence capture of the island pill.

Usage: morph_frames.py X Y W H ROW PERIOD_MS TOTAL_MS
Captures the global logical region X,Y WxH with grim every PERIOD_MS for TOTAL_MS. The caller arms
the shell first (`hush morphProbe`), so nothing but grim runs while frames are taken.
Prints one JSON object: frames [[t_ms, width_px]]. Width is measured on ROW against a baseline frame
taken at rest before any event: the span of the baseline's pure-black run (the pill fill is #000000)
widened to every pixel that differs from the baseline. Content inside the pill (light text, rows that
reach the clip edge) then never shortens the reading, and the wallpaper never lengthens it.
"""
import io, json, subprocess, sys, time
from PIL import Image

x, y, w, h, row, period, total = (int(a) for a in sys.argv[1:8])
geom = f"{x},{y} {w}x{h}"

def grab():
    return Image.open(io.BytesIO(subprocess.run(["grim", "-t", "ppm", "-g", geom, "-"],
                                                capture_output=True).stdout)).convert("RGB")

base = grab()
scale = base.width / w
r = int(row * scale)
bpx = base.load()
black = [i for i in range(base.width) if max(bpx[i, r]) <= 3]
if not black: sys.exit("no pill on the baseline row")

def width(img):
    px = img.load()
    xs = [i for i in range(img.width) if sum(abs(a - b) for a, b in zip(px[i, r], bpx[i, r])) > 24]
    lo, hi = min([black[0]] + xs[:1]), max([black[-1]] + xs[-1:])
    return round((hi - lo + 1) / scale)

raw, t0 = [], time.monotonic()
while True:
    now = (time.monotonic() - t0) * 1000
    if now > total: break
    data = subprocess.run(["grim", "-t", "ppm", "-g", geom, "-"], capture_output=True).stdout
    raw.append((round(now), data))
    nxt = (len(raw)) * period
    left = nxt - (time.monotonic() - t0) * 1000
    if left > 0: time.sleep(left / 1000)
frames = [[t, width(Image.open(io.BytesIO(d)).convert("RGB"))] for t, d in raw]
print(json.dumps({"frames": frames}))

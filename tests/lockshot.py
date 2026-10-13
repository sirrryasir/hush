#!/usr/bin/env python3
"""Measure lock/login screenshots against lockscreen/layout.toml.

  lockshot.py clock PNG HEX        centre y of the clock glyphs (pixels near colour HEX)
  lockshot.py pill PNG             pill: black-run width on its centre row, and the centre pixel
  lockshot.py edge PNG             colour of the pill's top hairline (brightest pixel on the top edge)
  lockshot.py inside PNG           brightest luminance inside the pill's text area (0-255)
  lockshot.py dots PNG             margins (px) between the outermost dots and the pill's rounded ends (<0: spill)
  lockshot.py status PNG HEX       pixels near colour HEX on the status line under the pill
"""
import sys, tomllib, os
from PIL import Image

SPEC = tomllib.load(open(os.path.join(os.path.dirname(__file__), "..", "lockscreen", "layout.toml"), "rb"))


def lum(p):
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]


def main():
    cmd, path = sys.argv[1], sys.argv[2]
    im = Image.open(path).convert("RGB")
    W, H = im.size
    s = H / SPEC["base"]
    px = im.load()
    cx = W // 2
    pcy = round(SPEC["pill"]["cy"] * H)
    if cmd == "clock":
        h = sys.argv[3].lstrip("#")
        want = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        cy = SPEC["clock"]["cy"] * H
        y0, y1 = int(cy - 0.12 * H), int(cy + 0.12 * H)
        x0, x1 = int(cx - 0.35 * H), int(cx + 0.35 * H)
        ys = [y for y in range(y0, y1) for x in range(x0, x1, 2)
              if sum(abs(a - b) for a, b in zip(px[x, y], want)) < 60]
        if not ys:
            print("none"); return
        print(f"{(min(ys) + max(ys)) / 2:.1f} {cy:.1f}")
    elif cmd == "pill":
        # width: the black run on the row 3 px inside the top hairline (above the avatar, text and
        # submit button), corrected for the rounded ends; plus the colour right of the centre
        r = SPEC["pill"]["h"] * s / 2
        y = round(pcy - r + 3)
        l = rr = cx
        while l > 0 and lum(px[l - 1, y]) < 6: l -= 1
        while rr < W - 1 and lum(px[rr + 1, y]) < 6: rr += 1
        run = rr - l + 1
        dy = pcy - y - 0.5
        cut = r - (max(r * r - dy * dy, 0)) ** 0.5
        print(round(run + 2 * cut), *px[cx + int(110 * s), pcy])
    elif cmd == "edge":
        best = (0, (0, 0, 0))
        top = pcy - round(SPEC["pill"]["h"] * s / 2)
        for y in range(top - 2, top + 3):
            for x in range(cx - 60, cx + 60):
                p = px[x, y]
                if lum(p) > best[0]: best = (lum(p), p)
        print("%02x%02x%02x" % best[1])
    elif cmd == "inside":
        half = round(SPEC["pill"]["w"] * s / 2)
        x0, x1 = cx - half + round(SPEC["pill"]["h"] * s), cx + half - round(SPEC["pill"]["h"] * s)
        hh = round(SPEC["pill"]["h"] * s / 2) - 6
        print(int(max(lum(px[x, y]) for x in range(x0, x1) for y in range(pcy - hh, pcy + hh))))
    elif cmd == "status":
        h = sys.argv[3].lstrip("#")
        want = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        cy, hh = round(SPEC["status"]["cy"] * H), round(SPEC["status"]["size"] * s)
        print(sum(1 for y in range(cy - hh, cy + hh) for x in range(cx - round(0.15 * H), cx + round(0.15 * H))
                  if sum(abs(a - b) for a, b in zip(px[x, y], want)) < 60))
    elif cmd == "dots":
        # bright pixels on the centre row, inside the hairline; limits a quarter pill height in from the ends
        half = round(SPEC["pill"]["w"] * s / 2)
        lim = half - round(SPEC["pill"]["h"] * s / 4)
        xs = [x for x in range(cx - half + 2, cx + half - 2) if lum(px[x, pcy]) > 150]
        if not xs:
            print(-1, -1); return
        print(int(xs[0] - (cx - lim)), int((cx + lim) - xs[-1]))


main()

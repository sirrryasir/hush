#!/usr/bin/env python3
"""Measure SDDM greeter screenshots (layout B) against lockscreen/layout.toml.

  sddmshot.py width PNG           black-run width of the pill on its centre row, past the avatar
  sddmshot.py px PNG DX DY        colour at (centre + DX, pill centre + DY), layout px scaled to H
  sddmshot.py edge PNG            colour of the pill's top hairline (most saturated/bright pixel)
  sddmshot.py near PNG HEX R      count of pixels within 60 of HEX on a ring of radius R (layout px)
                                  around the pill centre (the checking arc)
  sddmshot.py menu PNG            black pixels in the column above the session button (list open)
"""
import sys, tomllib, os, math
from PIL import Image

SPEC = tomllib.load(open(os.path.join(os.path.dirname(__file__), "..", "lockscreen", "layout.toml"), "rb"))


def lum(p):
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]


def hexc(h):
    h = h.lstrip("#")[-6:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def main():
    cmd, path = sys.argv[1], sys.argv[2]
    im = Image.open(path).convert("RGB")
    W, H = im.size
    s = H / SPEC["base"]
    px = im.load()
    cx = W // 2
    pcy = round(SPEC["pill"]["cy"] * H)
    if cmd == "width":
        # a row 6 px under the top hairline, where only the pill's black is (no avatar, dots, button)
        r = SPEC["pill"]["h"] * s / 2
        y = round(pcy - r + 6)
        l = rr = cx
        while l > 0 and lum(px[l - 1, y]) < 4: l -= 1
        while rr < W - 1 and lum(px[rr + 1, y]) < 4: rr += 1
        dy = pcy - y
        cut = r - math.sqrt(max(r * r - dy * dy, 0))
        print(round(rr - l + 1 + 2 * cut))
    elif cmd == "px":
        x, y = cx + round(float(sys.argv[3]) * s), pcy + round(float(sys.argv[4]) * s)
        print("%02x%02x%02x" % px[x, y])
    elif cmd == "edge":
        top = pcy - round(SPEC["pill"]["h"] * s / 2)
        best = (-1, (0, 0, 0))
        for y in range(top - 2, top + 3):
            for x in range(cx - 60, cx + 60):
                p = px[x, y]
                score = lum(p) + (max(p) - min(p))
                if score > best[0]: best = (score, p)
        print("%02x%02x%02x" % best[1])
    elif cmd == "near":
        want, R = hexc(sys.argv[3]), float(sys.argv[4]) * s
        n = 0
        for a in range(0, 360, 2):
            for dr in (-1.5, -0.5, 0.5):
                x = round(cx + (R + dr) * math.cos(math.radians(a)))
                y = round(pcy + (R + dr) * math.sin(math.radians(a)))
                if sum(abs(u - v) for u, v in zip(px[x, y], want)) < 60: n += 1
        print(n)
    elif cmd == "menu":
        # pure black pixels in the column above the session button (the list is #000; the blurred
        # wallpaper never is): ~0 while closed, the list height when open
        by = round(SPEC["power"]["cy"] * H)
        bx = cx - round((SPEC["power"]["size"] + SPEC["power"]["gap"]) * s)
        y0 = by - round(SPEC["power"]["size"] * s / 2) - 2
        print(sum(1 for y in range(max(0, y0 - round(150 * s)), y0) if px[bx, y] == (0, 0, 0)))

main()

#!/usr/bin/env python3
"""Hush brand kit builder.

Draws the Breath mark (the island pill and its dot) and the "hush" wordmark from one round-ended
stroke, outlines them with Inkscape and writes the canonical files, one set per use:
  app/       app icon squircle, dark and light, SVG + 512 PNG
  social/    README header (dark, light), GitHub social preview
  sddm/hush/assets/avatar.png            default lock/login face
  matugen/templates/fastfetch-logo.svg   the fastfetch logo, tinted per theme at runtime
Run from anywhere:  python3 assets/brand/src/build.py   (needs inkscape and rsvg-convert)
"""
import os, re, subprocess, tempfile

BRAND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FASTFETCH = os.path.join(BRAND, "..", "..", "matugen", "templates", "fastfetch-logo.svg")
TMP = tempfile.mkdtemp(prefix="hush-brand-")
os.chdir(BRAND)
for d in ("app", "social"):
    os.makedirs(d, exist_ok=True)

BLACK, WHITE = "#000000", "#ffffff"

def f(n): return f"{n:.2f}".rstrip("0").rstrip(".")
def tmp(name): return os.path.join(TMP, name)

# ------------------------------------------------------------------ geometry
# Wordmark: x-height 96, stroke 26 (round ends), ascender 140, n-width 80, letter gap 18.
WX, WT, WW, WA, WG = 96, 26, 80, 140, 18
WS = WW * 0.86  # s width

def glyph(ch, x, by, X=WX, t=WT, W=WW, A=WA):
    """Centerline paths for one lowercase letter; returns (paths, advance width)."""
    h, R = t / 2, (W - t) / 2
    if ch == "h":
        cy = by - X + h + R
        return [f"M{f(x+h)} {f(by-h)} V{f(by-A+h)}",
                f"M{f(x+h)} {f(cy)} A{f(R)} {f(R)} 0 0 1 {f(x+W-h)} {f(cy)} V{f(by-h)}"], W
    if ch == "u":
        cy = by - h - R
        return [f"M{f(x+h)} {f(by-X+h)} V{f(cy)} A{f(R)} {f(R)} 0 0 0 {f(x+W-h)} {f(cy)}",
                f"M{f(x+W-h)} {f(by-X+h)} V{f(by-h)}"], W
    if ch == "s":
        rc = (X - t) / 4
        yt, ym, yb = by - X + h, by - X / 2, by - h
        xl, xr = x + h + rc, x + WS - h - rc
        return [f"M{f(x+WS-h)} {f(yt)} H{f(xl)} A{f(rc)} {f(rc)} 0 0 0 {f(xl)} {f(ym)} H{f(xr)} "
                f"A{f(rc)} {f(rc)} 0 0 1 {f(xr)} {f(yb)} H{f(x+h)}"], WS
    raise ValueError(ch)

def word(text, x, by, gap=WG):
    paths, x0 = [], x
    for ch in text:
        p, w = glyph(ch, x, by)
        paths += p
        x += w + gap
    return paths, x - gap - x0

def stadium(x, y, w, hgt):
    return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(hgt)}" rx="{f(min(w, hgt)/2)}"/>'

def breath(ph=76, gap=16, cx=128, cy=124):
    """The mark: island pill (2:1) + one dot of the same height, a quiet gap apart."""
    pw = ph * 2
    x = cx - (pw + gap + ph) / 2
    return stadium(x, cy - ph / 2, pw, ph) + stadium(x + pw + gap, cy - ph / 2, ph, ph)

# ------------------------------------------------------------------ outline helper
def outline(name, w, h, title, fills="", strokes=(), t=WT):
    """Write a raw SVG, let Inkscape outline strokes and unite, save a clean single-path file."""
    s = "".join(f'<path d="{d}"/>' for d in strokes)
    g = (f'<g fill="none" stroke="#000" stroke-width="{f(t)}" stroke-linecap="round" '
         f'stroke-linejoin="round">{s}</g>' if strokes else "")
    raw = os.path.join(TMP, os.path.basename(name))
    open(raw, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(w)} {f(h)}" '
                         f'width="{f(w)}" height="{f(h)}">{fills}{g}</svg>')
    out = os.path.join(TMP, "u-" + os.path.basename(name))
    subprocess.run(["inkscape", raw, "--actions=select-all:all;selection-ungroup;select-all:all;"
                    "selection-ungroup;select-all:all;object-to-path;object-stroke-to-path;select-all:all;"
                    "path-union;export-plain-svg;export-filename:" + out + ";export-do"],
                   check=True, capture_output=True)
    d = " ".join(re.findall(r'\sd="([^"]+)"', open(out).read()))
    d = re.sub(r"(\d+\.\d{2})\d+", r"\1", d)
    return d

def mark_svg(d, w, h, title, fill=BLACK, bg=None, rx=0):
    b = f'<rect width="{f(w)}" height="{f(h)}" rx="{f(rx)}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(w)} {f(h)}" width="{f(w)}" '
            f'height="{f(h)}" role="img" aria-labelledby="title"><title id="title">{title}</title>'
            f'{b}<path fill="{fill}" d="{d}"/></svg>\n')

def png(svg, out, w, h=None):
    cmd = ["rsvg-convert", "-w", str(w)] + (["-h", str(h)] if h else []) + [svg, "-o", out]
    subprocess.run(cmd, check=True)

# ------------------------------------------------------------------ masters
SYM = outline(tmp("symbol.svg"), 256, 256, "Hush", breath())
# Reversed: 2 units thinner all round so white-on-black does not look heavier.
SYM_R = outline(tmp("symbol-reversed.svg"), 256, 256, "Hush", breath(ph=72, gap=20))
_, ww = word("hush", 0, 200)
LX = 256 + 72  # horizontal lockup: symbol, 72 gap, wordmark; pill centred on the x-height
LOCK_W = LX + ww + 8
LOCK = outline(tmp("lockup.svg"), LOCK_W, 256, "Hush",
               f'<g transform="translate(0 28)">{breath()}</g>', word("hush", LX, 200)[0])

# ------------------------------------------------------------------ composites
def place(d, vw, vh, x, y, w, fill):
    s = w / vw
    return f'<path transform="translate({f(x)} {f(y)}) scale({f(s)})" fill="{fill}" d="{d}"/>'

def canvas(path, W, H, body, bg, title="Hush"):
    b = f'<rect width="{W}" height="{H}" fill="{bg}"/>' if bg else ""
    open(path, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" '
                          f'height="{H}" role="img" aria-labelledby="title"><title id="title">{title}</title>'
                          f'{b}{body}</svg>\n')

def squircle(s, k=0.909):
    """Superellipse tile (n~4) as four cubics, edge midpoint to edge midpoint."""
    a = s / 2
    c = lambda x, y: f"{f(a+x)} {f(a+y)}"
    return (f"M{c(a,0)} C{c(a,k*a)} {c(k*a,a)} {c(0,a)} C{c(-k*a,a)} {c(-a,k*a)} {c(-a,0)} "
            f"C{c(-a,-k*a)} {c(-k*a,-a)} {c(0,-a)} C{c(k*a,-a)} {c(a,-k*a)} {c(a,0)} Z")

def centred(d, vw, vh, W, H, w, fill, dy=0):
    s = w / vw
    return place(d, vw, vh, (W - w) / 2, (H - vh * s) / 2 + dy, w, fill)

# App icon: mark on a pure-black (or white) squircle, mark at 60 % of the tile.
for mode, bg, fg, d in (("dark", BLACK, WHITE, SYM_R), ("light", WHITE, BLACK, SYM)):
    p = f"app/hush-app-icon-{mode}.svg"
    canvas(p, 1024, 1024, f'<path fill="{bg}" d="{squircle(1024)}"/>' + centred(d, 256, 256, 1024, 1024, 1024 * 0.6, fg), None)
    png(p, f"app/hush-app-icon-{mode}-512.png", 512)

# README header 1200x300, transparent so it sits on the GitHub page colour.
for mode, fg in (("dark", WHITE), ("light", BLACK)):
    canvas(f"social/readme-header-{mode}.svg", 1200, 300, centred(LOCK, LOCK_W, 256, 1200, 300, 520, fg), None)

# GitHub social preview 1280x640 (upload the PNG in the repo settings).
canvas("social/social-preview-dark.svg", 1280, 640, centred(LOCK, LOCK_W, 256, 1280, 640, 640, WHITE), BLACK)
png("social/social-preview-dark.svg", "social/social-preview-dark.png", 1280)

# Default lock/login face 256 (bin/hush falls back to it when ~/.face is missing).
canvas(tmp("avatar.svg"), 512, 512, centred(SYM_R, 256, 256, 512, 512, 400, WHITE, dy=8), BLACK)
png(tmp("avatar.svg"), "../../sddm/hush/assets/avatar.png", 256)

# fastfetch: a tight-cropped mark; matugen fills in the theme primary, `hush` rasterises it.
FF = outline(tmp("ff.svg"), 256, 96, "Hush", breath(cy=48))
open(FASTFETCH, "w").write(mark_svg(FF, 256, 96, "Hush", "{{colors.primary.default.hex}}"))
print("brand kit built in", BRAND)

#!/usr/bin/env python3
"""Hush brand kit builder.

Draws the Breath mark (the island pill and its dot) and the "hush" wordmark from one round-ended
stroke, outlines them with Inkscape, and composes every delivery file from those masters.
Run from anywhere:  python3 assets/brand/src/build.py
Needs: inkscape (outline + union), rsvg-convert (PNG). Paths are relative to assets/brand/.
"""
import os, re, subprocess, tempfile

BRAND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP = tempfile.mkdtemp(prefix="hush-brand-")
os.chdir(BRAND)
for d in ("svg", "png", "app", "social", "shell", "cobrand", "fastfetch"):
    os.makedirs(d, exist_ok=True)

BLACK, WHITE, ACCENT = "#000000", "#ffffff", "#7fb3a3"
# Primary colour per theme (matugen output for each theme's source/wallpaper and mode).
THEMES = {"dusk": "#dcb9f8", "ember": "#ffb690", "fog": "#236488",
          "harbor": "#9cd1c1", "moss": "#96d5a6", "paper": "#35675a"}

def f(n): return f"{n:.2f}".rstrip("0").rstrip(".")

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
    if ch == "o":
        r = (X - t) / 2
        cx, cy = x + X / 2, by - X / 2
        return [f"M{f(cx-r)} {f(cy)} A{f(r)} {f(r)} 0 1 1 {f(cx+r)} {f(cy)} A{f(r)} {f(r)} 0 1 1 {f(cx-r)} {f(cy)}"], X
    if ch == "r":
        Rr = R * 0.9
        cy = by - X + h + Rr
        return [f"M{f(x+h)} {f(by-X+h)} V{f(by-h)}",
                f"M{f(x+h)} {f(cy)} A{f(Rr)} {f(Rr)} 0 0 1 {f(x+h+Rr*1.6)} {f(by-X+h)}"], W * 0.72
    if ch == "f":
        Rf = R * 0.9
        top = by - A + h
        return [f"M{f(x+h)} {f(by-h)} V{f(top+Rf)} A{f(Rf)} {f(Rf)} 0 0 1 {f(x+h+Rf)} {f(top)} H{f(x+h+Rf+10)}",
                f"M{f(x+h)} {f(by-X+h)} H{f(x+h+Rf+6)}"], W * 0.68
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
    open(name, "w").write(mark_svg(d, w, h, title))
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
SYM = outline("svg/hush-symbol.svg", 256, 256, "Hush", breath())
# Small cut for 16-24 px: snapped to a 16 px grid (pill 8x4, gap 2, dot 4).
SYM_S = outline("svg/hush-symbol-small.svg", 256, 256, "Hush", breath(ph=64, gap=32, cy=128))
# Reversed: 2 units thinner all round so white-on-black does not look heavier.
SYM_R = outline("svg/hush-symbol-reversed.svg", 256, 256, "Hush", breath(ph=72, gap=20))
_, ww = word("hush", 0, 200)
WORD = outline("svg/hush-wordmark.svg", ww, 256, "hush", strokes=word("hush", 0, 200)[0])
LX = 256 + 72  # horizontal lockup: symbol, 72 gap, wordmark; pill centred on the x-height
LOCK = outline("svg/hush-lockup.svg", LX + ww + 8, 256, "Hush",
               f'<g transform="translate(0 28)">{breath()}</g>', word("hush", LX, 200)[0])
LOCK_W = LX + ww + 8
STK_W = ww + 32  # stacked: symbol above wordmark
stk = f'<g transform="translate({f(STK_W/2-128)} 0)">{breath(cy=110)}</g>'
STACK = outline("svg/hush-lockup-stacked.svg", STK_W, 384, "Hush", stk,
                word("hush", 16, 336)[0])
_, fw = word("for", 0, 200)

# one-colour variants of every master
for name, d, w, h in (("hush-symbol", SYM, 256, 256), ("hush-symbol-small", SYM_S, 256, 256),
                      ("hush-wordmark", WORD, ww, 256), ("hush-lockup", LOCK, LOCK_W, 256),
                      ("hush-lockup-stacked", STACK, STK_W, 384)):
    src = SYM_R if name == "hush-symbol" else d
    for tag, col, dd in (("black", BLACK, d), ("white", WHITE, src), ("accent", ACCENT, d)):
        p = f"svg/{name}-{tag}.svg"
        open(p, "w").write(mark_svg(dd, w, h, "Hush", col))

# ------------------------------------------------------------------ composites
def place(d, vw, vh, x, y, w, fill):
    s = w / vw
    return f'<path transform="translate({f(x)} {f(y)}) scale({f(s)})" fill="{fill}" d="{d}"/>'

def canvas(path, W, H, body, bg, title="Hush", rx=0):
    b = f'<rect width="{W}" height="{H}" rx="{f(rx)}" fill="{bg}"/>' if bg else ""
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

# App icon: mark on a pure-black (or white) squircle, mark at 62 % of the tile.
for mode, bg, fg, d in (("dark", BLACK, WHITE, SYM_R), ("light", WHITE, BLACK, SYM)):
    p = f"app/hush-app-icon-{mode}.svg"
    canvas(p, 1024, 1024, f'<path fill="{bg}" d="{squircle(1024)}"/>' +
           centred(d, 256, 256, 1024, 1024, 1024 * 0.6, fg, dy=0), None)
    for s in (512, 1024):
        png(p, f"app/hush-app-icon-{mode}-{s}.png", s)

# README header 1200x300 and GitHub social preview 1280x640, dark and light.
for mode, bg, fg, d in (("dark", BLACK, WHITE, LOCK), ("light", WHITE, BLACK, LOCK)):
    p = f"social/readme-header-{mode}.svg"
    canvas(p, 1200, 300, centred(d, LOCK_W, 256, 1200, 300, 520, fg), None)  # transparent: sits on the GitHub page colour
    png(p, f"social/readme-header-{mode}.png", 1200)
    p = f"social/social-preview-{mode}.svg"
    canvas(p, 1280, 640, centred(d, LOCK_W, 256, 1280, 640, 640, fg), bg)
    png(p, f"social/social-preview-{mode}.png", 1280)

# Banner 1500x500 (Reddit/X): lockup a little right of centre so a profile picture never covers it.
canvas("social/banner.svg", 1500, 500, place(LOCK, LOCK_W, 256, 640, 170, 600, WHITE), BLACK)
png("social/banner.svg", "social/banner-1500x500.png", 1500)

# Avatar 512 (GitHub/org, crops to a circle) and hyprlock/SDDM face 256.
canvas("social/avatar.svg", 512, 512, centred(SYM_R, 256, 256, 512, 512, 400, WHITE, dy=8), BLACK)
png("social/avatar.svg", "social/avatar-512.png", 512)
png("social/avatar.svg", "shell/face-256.png", 256)
open("shell/face-256.svg", "w").write(open("social/avatar.svg").read())

# Quickshell tray icons 24/48 (small cut), black and white, plus the symbolic SVG.
for tag, col in (("black", BLACK), ("white", WHITE)):
    p = f"shell/tray-{tag}.svg"
    open(p, "w").write(mark_svg(SYM_S, 256, 256, "Hush", col))
    for s in (24, 48):
        png(p, f"shell/tray-{tag}-{s}.png", s)

# PNG ladder of the symbol and lockups.
for s in (16, 24, 32, 48, 64, 128, 256, 512, 1024):
    png("svg/hush-symbol-small-black.svg" if s <= 24 else "svg/hush-symbol-black.svg",
        f"png/hush-symbol-black-{s}.png", s)
    png("svg/hush-symbol-small-white.svg" if s <= 24 else "svg/hush-symbol-white.svg",
        f"png/hush-symbol-white-{s}.png", s)
for tag in ("black", "white", "accent"):
    png(f"svg/hush-lockup-{tag}.svg", f"png/hush-lockup-{tag}-1200.png", 1200)

# ------------------------------------------------------------------ Hush for Arch Linux
# Arch logo: the official file from archlinux.org/art, embedded unmodified (only placed and scaled).
# Wording follows the Arch trademark policy ("<software> for Arch Linux"); no endorsement implied.
FOR = outline(os.path.join(TMP, "for.svg"), fw, 256, "for", strokes=word("for", 0, 200)[0])

def arch(variant):
    s = open(f"cobrand/arch/archlinux-logo-{variant}-scalable.svg").read()
    s = re.sub(r"<\?xml[^>]*>|<!--.*?-->", "", s, flags=re.S)
    return s.strip()

for mode, bg, fg, av in (("dark", BLACK, WHITE, "white"), ("light", WHITE, BLACK, "black")):
    W, H = 1200, 300
    lock_w = 420; lock_h = 256 * lock_w / LOCK_W
    sl = lock_w / LOCK_W; sf = sl * 0.72; for_w = fw * sf
    arch_w = 380; arch_h = 199.41692 * arch_w / 600
    gap = 44
    total = lock_w + gap + for_w + gap + arch_w
    x0 = (W - total) / 2
    base = H / 2 + 200 * 0.5 * 0.5 - 6
    body = place(LOCK, LOCK_W, 256, x0, (H - lock_h) / 2, lock_w, fg)
    baseline = (H - lock_h) / 2 + 200 * sl
    body += place(FOR, fw, 256, x0 + lock_w + gap, baseline - 200 * sf, for_w, fg)
    ax, ay = x0 + lock_w + gap + for_w + gap, (H - arch_h) / 2
    nested = re.sub(r"<svg\b", f'<svg x="{f(ax)}" y="{f(ay)}" width="{f(arch_w)}" height="{f(arch_h)}" '
                    'viewBox="0 0 600 199.41692"', arch(av), count=1)
    nested = re.sub(r'(<svg[^>]*?)\s(width|height)="(600|199\.41692)"', r"\1", nested)
    nested = re.sub(r'(<svg[^>]*?)\s(width|height)="(600|199\.41692)"', r"\1", nested)
    p = f"cobrand/hush-for-arch-linux-{mode}.svg"
    canvas(p, W, H, body + nested, bg, "Hush for Arch Linux")
    png(p, f"cobrand/hush-for-arch-linux-{mode}.png", W)

# ------------------------------------------------------------------ fastfetch
# Runtime: matugen renders matugen/templates/fastfetch-logo.svg in the theme primary, `hush` turns it into
# a PNG for the kitty graphics protocol. Here: a tight-cropped master and one preview PNG per theme.
FF = outline(os.path.join(TMP, "ff.svg"), 256, 96, "Hush", breath(cy=48))
for theme, col in THEMES.items():
    p = os.path.join(TMP, f"ff-{theme}.svg")
    open(p, "w").write(mark_svg(FF, 256, 96, "Hush", col))
    png(p, f"fastfetch/hush-logo-{theme}.png", 512)
open("fastfetch/hush-logo-template.svg", "w").write(mark_svg(FF, 256, 96, "Hush", "{{colors.primary.default.hex}}"))
# Web icons (favicon.ico, PNG set, webmanifest) come from the logo-design skill's exporter:
#   export_variants.py svg/hush-symbol.svg --name hush --title Hush --web-icons --icon-bg "#000000" \
#     --icon-fg "#ffffff" --favicon-source svg/hush-symbol-small.svg --only favicon app-icon --out-dir web
print("brand kit built in", BRAND)

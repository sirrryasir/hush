#!/usr/bin/env python3
"""WCAG contrast audit for one Hush theme. Usage: contrast.py <theme> [--quiet] [--wall <image>] (--wall: audit against that wallpaper instead of the theme's). Exit 1 on failure.
contrast.py --island-gate [theme...]: offline gate over the island's role pairs for every theme (default all six);
palettes are generated with the same matugen flags as `hush theme` into a scratch dir, never ~/.config. Exit 1 on failure."""
import json, os, re, subprocess, sys, tempfile, tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser("~")

def rgb(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def lin(c): c /= 255; return c/12.92 if c <= 0.03928 else ((c+0.055)/1.055)**2.4
def lum(c): r, g, b = map(lin, c); return 0.2126*r + 0.7152*g + 0.0722*b
def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la+0.05)/(lb+0.05)
def blend(fg, bg, a): return tuple(a*f + (1-a)*b for f, b in zip(fg, bg))

def island_gate(themes):
    root = ROOT; blk = (0, 0, 0)
    names = themes or ["harbor", "ember", "moss", "dusk", "paper", "fog"]
    table = {}; order = []
    for t in names:
        d = tomllib.load(open(f"{root}/themes/{t}/theme.toml", "rb"))
        tmp = tempfile.mkdtemp(prefix=f"hush-contrast-{t}-")
        cfg = open(f"{root}/matugen/config.toml.head").read() + "\n" + open(f"{root}/matugen/config.d/colors-json.toml").read()
        open(f"{tmp}/m.toml", "w").write(cfg.replace("@HUSH_ROOT@", root).replace("@CONFIG@", tmp))
        if d["source"] == "wallpaper":
            cmd = ["matugen", "image", f"{root}/themes/{t}/wallpaper.png", "--source-color-index", "0"]
        else:
            cmd = ["matugen", "color", "hex", d["source"]]
        cmd += ["-c", f"{tmp}/m.toml", "-m", d["mode"], "-t", d["scheme"], "--contrast", str(d["contrast"]), "-q"]
        subprocess.run(cmd, check=True)
        c = json.load(open(f"{tmp}/hush/Colors.json")); k = c["dark"]
        C = lambda x: rgb(c[x]); K = lambda x: rgb(k[x])
        pairs = [  # (label, fg, bg, minimum)
            ("pill text (darkOnSurface/black)", K("on_surface"), blk, 7.0),
            ("hover text 0.7 (date/black)", blend(K("on_surface"), blk, .7), blk, 4.5),
            ("hover dot active (1.0)", K("on_surface"), blk, 3.0),
            ("hover dot occupied (0.55)", blend(K("on_surface"), blk, .55), blk, 3.0),
            ("ring darkPrimary/black", K("primary"), blk, 3.0),
            ("ring darkError/black", K("error"), blk, 3.0),
            ("ring privacy tertiary/black", K("tertiary"), blk, 3.0),
            ("surface text on_surface/pill", C("on_surface"), blk, 4.5),
            ("surface text on_surface_variant/pill", C("on_surface_variant"), blk, 4.5),
            ("surface text on_surface/container_high", C("on_surface"), C("surface_container_high"), 4.5),
            ("surface text on_surface_variant/container", C("on_surface_variant"), C("surface_container"), 4.5),
            ("chip off on_surface/container", C("on_surface"), C("surface_container"), 4.5),
            ("chip on on_primary/primary", C("on_primary"), C("primary"), 4.5),
            ("warning error/container_high", C("error"), C("surface_container_high"), 3.0),
            ("critical error/error_container", C("error"), C("error_container"), 3.0),
        ]
        table[t] = [(l, cr(f, b), mn) for l, f, b, mn in pairs]
        order = [l for l, *_ in pairs]
    bad = 0
    print("%-46s" % "pair (min)" + "".join("%-14s" % n for n in names))
    for i, l in enumerate(order):
        mn = table[names[0]][i][2]
        cells = []
        for n in names:
            r = table[n][i][1]; ok = r >= mn; bad += not ok
            cells.append("%-14s" % ("%5.2f %s" % (r, "PASS" if ok else "FAIL")))
        print("%-46s" % f"{l} ({mn:g})" + "".join(cells))
    print(f"island contrast gate: {bad} failing cells over {len(names)} themes", file=sys.stderr)
    return 1 if bad else 0

if sys.argv[1] == "--island-gate": sys.exit(island_gate(sys.argv[2:]))
from PIL import Image, ImageStat
theme = sys.argv[1]

col = json.load(open(f"{HOME}/.config/hush/Colors.json"))
kitty = {}
for line in open(os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "kitty/theme.conf")):
    m = re.match(r"^(\w+)\s+(#[0-9a-fA-F]{6})\s*$", line)
    if m: kitty[m.group(1)] = rgb(m.group(2))
kbg, kfg = kitty["background"], kitty["foreground"]
wallpath = sys.argv[sys.argv.index("--wall") + 1] if "--wall" in sys.argv else f"{ROOT}/themes/{theme}/wallpaper.png"
wall = Image.open(wallpath).convert("RGB")
wmean = tuple(ImageStat.Stat(wall).mean)
eff = {a: blend(kbg, wmean, a) for a in (0.86, 0.78)}

rows = []  # (label, ratio, minimum)
def add(label, fg, bg, mn): rows.append((label, cr(fg, bg), mn))
C = lambda k: rgb(col[k])
add("on_surface/surface", C("on_surface"), C("surface"), 4.5)
add("on_surface_variant/surface", C("on_surface_variant"), C("surface"), 4.5)
add("on_surface/surface_container", C("on_surface"), C("surface_container"), 4.5)
add("on_primary/primary", C("on_primary"), C("primary"), 4.5)
add("primary/surface", C("primary"), C("surface"), 4.5)
add("outline/surface (nvim Comment/LineNr)", C("outline"), C("surface"), 3.0)
add("kitty fg/bg", kfg, kbg, 4.5)
add("kitty inactive tab fg/bg", C("on_surface_variant"), C("surface_container"), 4.5)
add("kitty url_color(tertiary)/bg", C("tertiary"), kbg, 4.5)
add("kitty color8(autosuggest)/bg", kitty["color8"], kbg, 3.0)
for a, e in eff.items():
    add(f"kitty fg/eff-bg@{a}", kfg, e, 4.5)
    add(f"p10k dir(primary)/eff-bg@{a}", C("primary"), e, 4.5)
    add(f"p10k vcs(tertiary)/eff-bg@{a}", C("tertiary"), e, 4.5)
    add(f"p10k vcs(secondary)/eff-bg@{a}", C("secondary"), e, 4.5)
    add(f"p10k error/conflict(error)/eff-bg@{a}", C("error"), e, 4.5)
    add(f"p10k dir-short(on_surface_variant)/eff-bg@{a}", C("on_surface_variant"), e, 4.5)
    add(f"fastfetch title(on_surface)/eff-bg@{a}", C("on_surface"), e, 4.5)
    for i in range(16):
        c = kitty[f"color{i}"]
        if i in (0, 8): continue
        mn = 4.5 if i in (7, 15) else 3.0
        add(f"color{i}/eff-bg@{a}", c, e, mn)
for i in (7, 15): add(f"color{i}/bg", kitty[f"color{i}"], kbg, 4.5)
for i in list(range(1, 7)) + list(range(9, 15)): add(f"color{i}/bg", kitty[f"color{i}"], kbg, 3.0)

fails = [r for r in rows if r[1] < r[2]]
if "--quiet" not in sys.argv:
    print(f"== {theme} ({col['mode']})  kitty bg={'#%02x%02x%02x'%kbg}  wallpaper mean={tuple(round(x) for x in wmean)}  eff@.86={tuple(round(x) for x in eff[0.86])}")
    for l, r, mn in rows:
        print(f"  {'FAIL' if r < mn else 'ok  '} {r:5.2f} (>= {mn})  {l}")
worst = min(rows, key=lambda r: r[1])
print(f"{theme}: {len(fails)} failing, lowest {worst[0]} {worst[1]:.2f}", file=sys.stderr)
sys.exit(1 if fails else 0)

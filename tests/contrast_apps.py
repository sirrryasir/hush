#!/usr/bin/env python3
"""App contrast gate: WCAG contrast of every generated app theme, for all six themes.

Usage: contrast_apps.py [--outputs DIR] [--verbose] [theme...]

Every matugen template is rendered offline (same flags as `hush theme`: image + --source-color-index 0
for wallpaper themes, `color hex` otherwise; mode, scheme and contrast from theme.toml) into a scratch
dir, never ~/.config. --outputs DIR parses DIR/<theme>/... instead (a tree rendered earlier, laid out
like ~/.config). The generated files are parsed, not screenshots; nvim's colorscheme computes its
palette at load time, so it is loaded in a headless `nvim -u NONE` and the resolved groups are read.
Prints a table (one row per pair, one column per theme) and exits 1 on any failing cell.
"""
import json, os, re, subprocess, sys, tempfile, tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEMES = ["harbor", "ember", "moss", "dusk", "paper", "fog"]


def rgb(h):
    h = h.strip().lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def lum(c):
    r, g, b = map(lin, c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def blend(fg, bg, a):
    return tuple(a * f + (1 - a) * b for f, b in zip(fg, bg))


def render(theme):
    """Render every template for `theme` into a fresh scratch dir; return that dir."""
    d = tomllib.load(open(f"{ROOT}/themes/{theme}/theme.toml", "rb"))
    out = tempfile.mkdtemp(prefix=f"hush-apps-{theme}-")
    cfg = open(f"{ROOT}/matugen/config.toml.head").read()
    for f in sorted(os.listdir(f"{ROOT}/matugen/config.d")):
        if f.endswith(".toml"):
            cfg += "\n" + open(f"{ROOT}/matugen/config.d/{f}").read()
    cfg = cfg.replace("@HUSH_ROOT@", ROOT).replace("@CONFIG@", out)
    for p in re.findall(r"^output_path = '([^']+)'", cfg, re.M):
        os.makedirs(os.path.dirname(p), exist_ok=True)
    open(f"{out}/matugen.toml", "w").write(cfg)
    if d["source"] == "wallpaper":
        cmd = ["matugen", "image", f"{ROOT}/themes/{theme}/wallpaper.png"]
    else:
        cmd = ["matugen", "color", "hex", d["source"]]
    cmd += ["-c", f"{out}/matugen.toml", "-m", d["mode"], "-t", d["scheme"], "--contrast", str(d["contrast"]), "-q"]
    if d["source"] == "wallpaper":
        cmd += ["--source-color-index", "0"]
    subprocess.run(cmd, check=True)
    return out


def kitty(path):
    k = {}
    for line in open(path):
        m = re.match(r"^(\w+)\s+(#[0-9a-fA-F]{6})\s*$", line)
        if m:
            k[m.group(1)] = rgb(m.group(2))
    return k


NVIM_DUMP = r"""
local out = {}
for _, g in ipairs(vim.split(vim.env.HUSH_GROUPS, ",")) do
  local h = vim.api.nvim_get_hl(0, { name = g, link = false })
  out[g] = { fg = h.fg and string.format("#%06x", h.fg) or nil, bg = h.bg and string.format("#%06x", h.bg) or nil,
             reverse = h.reverse or nil }
end
out._background = vim.o.background
out._termguicolors = vim.o.termguicolors
io.stdout:write(vim.json.encode(out))
"""

NVIM_TEXT = [  # (group, min); Comment/LineNr are secondary text, 3.0
    ("Normal", 4.5), ("Comment", 3.0), ("String", 4.5), ("Keyword", 4.5), ("Function", 4.5),
    ("Identifier", 4.5), ("Type", 4.5), ("Constant", 4.5), ("Special", 4.5), ("Operator", 4.5),
    ("LineNr", 3.0), ("CursorLineNr", 4.5), ("@variable", 4.5), ("@keyword", 4.5), ("@function", 4.5),
    ("@string", 4.5), ("@type", 4.5), ("@property", 4.5), ("@comment", 3.0),
    ("DiagnosticError", 4.5), ("DiagnosticWarn", 4.5), ("DiagnosticInfo", 4.5), ("DiagnosticHint", 4.5),
]
NVIM_BOXED = [("Pmenu", 4.5), ("PmenuSel", 4.5), ("Visual", 4.5), ("StatusLine", 4.5), ("StatusLineNC", 4.5),
              ("NormalFloat", 4.5), ("Search", 4.5), ("TabLineSel", 4.5), ("Todo", 4.5)]


def nvim_groups(path):
    groups = [g for g, _ in NVIM_TEXT + NVIM_BOXED] + ["CursorLine"]
    env = dict(os.environ, HUSH_GROUPS=",".join(groups))
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write(NVIM_DUMP)
    try:
        r = subprocess.run(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "--cmd", "set termguicolors",
                            "-c", f"luafile {path}", "-c", f"luafile {f.name}", "-c", "qa!"],
                           capture_output=True, text=True, env=env, timeout=30)
    finally:
        os.unlink(f.name)
    txt = (r.stdout + r.stderr).strip()
    return json.loads(txt[txt.index("{"):txt.rindex("}") + 1])


def gate(theme, out):
    mode = tomllib.load(open(f"{ROOT}/themes/{theme}/theme.toml", "rb"))["mode"]
    rows = []
    add = lambda label, fg, bg, mn: rows.append((label, cr(fg, bg), mn))
    C = json.load(open(f"{out}/hush/Colors.json"))
    col = lambda k: rgb(C[k])

    # kitty
    k = kitty(f"{out}/kitty/theme.conf")
    bg, fg = k["background"], k["foreground"]
    add("kitty fg/bg", fg, bg, 4.5)
    add("kitty selection fg/bg", k["selection_foreground"], k["selection_background"], 4.5)
    add("kitty cursor/bg", k["cursor"], bg, 3.0)
    for i in range(16):
        add(f"kitty color{i}/bg", k[f"color{i}"], bg, 3.0)

    # nvim (resolved after load; a NONE background is the terminal's)
    g = nvim_groups(f"{out}/nvim/colors/hush.lua")
    nbg = rgb(g["Normal"]["bg"]) if g["Normal"].get("bg") else bg
    nfg = rgb(g["Normal"]["fg"])
    cl = rgb(g["CursorLine"]["bg"]) if g["CursorLine"].get("bg") else nbg
    rows.append(("nvim background matches mode", 99.0 if (lum(nbg) < 0.18) == (mode == "dark") else 0.0, 1.0))
    for grp, mn in NVIM_TEXT:
        f = rgb(g[grp]["fg"]) if g[grp].get("fg") else nfg
        add(f"nvim {grp}/Normal bg", f, nbg, mn)
        if grp in ("Comment", "String", "Keyword", "Function", "Type", "LineNr"):
            add(f"nvim {grp}/CursorLine", f, cl, mn)
    for grp, mn in NVIM_BOXED:
        h = g[grp]
        f = rgb(h["fg"]) if h.get("fg") else nfg
        b = rgb(h["bg"]) if h.get("bg") else nbg
        if h.get("reverse"):
            f, b = b, f
        add(f"nvim {grp} text/bg", f, b, mn)

    # fastfetch (keys, title on the terminal background; values are the terminal fg)
    ff = json.loads("\n".join(l for l in open(f"{out}/fastfetch/config.jsonc") if not l.lstrip().startswith("//")))
    add("fastfetch keys/bg", rgb(ff["display"]["color"]["keys"]), bg, 4.5)
    add("fastfetch title/bg", rgb(ff["display"]["color"]["title"]), bg, 4.5)
    add("fastfetch value (fg)/bg", fg, bg, 4.5)

    # p10k (lean style: segments have no background, so fg sits on the terminal bg)
    for m in re.finditer(r"POWERLEVEL9K_(\w+?)_(?:\{[^}]*\}_)?FOREGROUND='(#[0-9a-fA-F]{6})'", open(f"{out}/hush/p10k-colors.zsh").read()):
        add(f"p10k {m.group(1).lower()}/bg", rgb(m.group(2)), bg, 4.5)

    # waybar fallback
    w = dict(re.findall(r"@define-color (\w+) (#[0-9a-fA-F]{6});", open(f"{out}/waybar/colors.css").read()))
    W = lambda x: rgb(w[x])
    add("waybar on_surface/surface", W("on_surface"), W("surface"), 4.5)
    add("waybar on_surface/surface_container", W("on_surface"), W("surface_container"), 4.5)
    add("waybar on_surface_variant/surface_container", W("on_surface_variant"), W("surface_container"), 4.5)
    add("waybar on_primary/primary", W("on_primary"), W("primary"), 4.5)

    # GTK (3 and 4 come from the same template)
    for ver in ("gtk-3.0", "gtk-4.0"):
        gt = dict(re.findall(r"@define-color (\w+) (#[0-9a-fA-F]{6});", open(f"{out}/{ver}/gtk.css").read()))
        G = lambda x: rgb(gt[x])
        for f_, b_ in (("window_fg_color", "window_bg_color"), ("view_fg_color", "view_bg_color"),
                       ("headerbar_fg_color", "headerbar_bg_color"), ("card_fg_color", "card_bg_color"),
                       ("dialog_fg_color", "dialog_bg_color"), ("popover_fg_color", "popover_bg_color"),
                       ("sidebar_fg_color", "sidebar_bg_color"), ("accent_fg_color", "accent_bg_color"),
                       ("destructive_fg_color", "destructive_bg_color"),
                       ("theme_selected_fg_color", "theme_selected_bg_color"),
                       ("theme_text_color", "theme_base_color"), ("accent_color", "window_bg_color"),
                       ("error_color", "window_bg_color"), ("success_color", "window_bg_color"),
                       ("warning_color", "window_bg_color")):
            add(f"{ver} {f_.replace('_color', '')}/{b_.replace('_color', '')}", G(f_), G(b_), 4.5)

    # qt6ct (QPalette role order)
    roles = ["WindowText", "Button", "Light", "Midlight", "Dark", "Mid", "Text", "BrightText", "ButtonText",
             "Base", "Window", "Shadow", "Highlight", "HighlightedText", "Link", "LinkVisited", "AlternateBase",
             "NoRole", "ToolTipBase", "ToolTipText", "PlaceholderText"]
    qt = open(f"{out}/qt6ct/colors.conf").read()
    for grp in ("active", "inactive"):
        vals = [rgb(x) for x in re.search(rf"^{grp}_colors=(.*)$", qt, re.M).group(1).split(",")]
        Q = dict(zip(roles, vals))
        for f_, b_, mn in (("WindowText", "Window", 4.5), ("Text", "Base", 4.5), ("Text", "AlternateBase", 4.5),
                           ("ButtonText", "Button", 4.5), ("HighlightedText", "Highlight", 4.5),
                           ("ToolTipText", "ToolTipBase", 4.5), ("Link", "Base", 4.5),
                           ("PlaceholderText", "Base", 3.0)):
            add(f"qt6ct {grp} {f_}/{b_}", Q[f_], Q[b_], mn)

    # Kvantum
    kv = dict(re.findall(r"^([\w.]+)=(#[0-9a-fA-F]{6})\s*$", open(f"{out}/Kvantum/hush/hush.kvconfig").read().split("[GeneralColors]")[1].split("\n[")[0], re.M))
    K = lambda x: rgb(kv[x])
    for f_, b_, mn in (("text.color", "base.color", 4.5), ("text.color", "alt.base.color", 4.5),
                       ("window.text.color", "window.color", 4.5), ("button.text.color", "button.color", 4.5),
                       ("highlight.text.color", "highlight.color", 4.5), ("tooltip.text.color", "tooltip.base.color", 4.5),
                       ("link.color", "base.color", 4.5), ("disabled.text.color", "window.color", 3.0)):
        add(f"kvantum {f_.replace('.color', '')}/{b_.replace('.color', '')}", K(f_), K(b_), mn)

    # hyprlock: input field text on its inner colour; the clock over the dimmed, blurred wallpaper
    hl = dict(re.findall(r"^\$(\w+) = rgba\(([0-9a-fA-F]{6})ff\)", open(f"{out}/hyprlock/colors.conf").read(), re.M))
    H = lambda x: rgb(hl[x])
    # the pill is the island: black with dark-scheme roles; the placeholder is islandText at 60 %
    add("hyprlock pill dots/text on black", H("hushIslandText"), H("hushIslandBg"), 4.5)
    add("hyprlock pill placeholder (60 %) on black", blend(H("hushIslandText"), H("hushIslandBg"), 0.6), H("hushIslandBg"), 4.5)
    add("hyprlock pill glyphs on black", H("hushIslandMuted"), H("hushIslandBg"), 3.0)
    add("hyprlock pill check outline on black", H("hushIslandCheck"), H("hushIslandBg"), 3.0)
    add("hyprlock pill fail outline on black", H("hushIslandFail"), H("hushIslandBg"), 3.0)
    # labels on the wallpaper: blurred, contrast then brightness from lockscreen/layout.toml (hyprland
    # blur pass); label colours from the generated widgets (alpha vars are blended over the wallpaper)
    blur = tomllib.load(open(f"{ROOT}/lockscreen/layout.toml", "rb"))["blur"]
    con, bri = float(blur["contrast"]), float(blur["brightness"])
    lay = subprocess.run([sys.executable, f"{ROOT}/lockscreen/gen.py", "hyprlock", "-"], capture_output=True, text=True).stdout
    hla = dict(re.findall(r"^\$(\w+) = rgba\(([0-9a-fA-F]{8})\)", open(f"{out}/hyprlock/colors.conf").read(), re.M))
    # each label is checked over the wallpaper band it sits on (32x18 grid); large text (>= 18 pt, hyprlock font_size)
    # and icon glyphs need 3.0 (WCAG large text / non-text), body text 4.5; font_size is in points
    from PIL import Image
    im = Image.open(f"{ROOT}/themes/{theme}/wallpaper.png").convert("RGB").resize((32, 18), Image.BOX)
    for name, body in re.findall(r"label \{ # ([\w ]+?)[,(\n][^}]*?\n(.*?)\n\}", lay, re.S):
        var = re.search(r"\bcolor = \$(\w+)", body).group(1)
        if var.startswith("hushIsland"):
            continue
        size = int(re.search(r"font_size = (\d+)", body).group(1))
        icons = "Material Symbols" in body
        pos = re.search(r"position = (-?[\d.]+%?), (-?[\d.]+%?)", body)
        if "valign = top" in body:
            band, cols = range(0, 2), range(27, 32)
        else:
            cy = 0.5 - float(pos.group(2).rstrip("%")) / 100
            r0 = int(cy * 18)
            band, cols = range(max(0, r0 - 1), min(18, r0 + 2)), range(10, 22)
        need = 3.0 if (size >= 18 or icons) else 4.5
        h8 = hla[var]; al = int(h8[6:], 16) / 255
        worst = 99.0
        for y in band:
            for x in cols:
                p = tuple(min(255, max(0, ((ch / 255 - 0.5) * con + 0.5) * bri * 255)) for ch in im.getpixel((x, y)))
                if "shadow_passes" in body:  # halo in $hushWallShade: model as a 35 % blend under the text
                    p = blend(rgb(hla["hushWallShade"][:6]), p, 0.35)
                worst = min(worst, cr(blend(rgb(h8[:6]), p, al), p))
        rows.append((f"hyprlock {name} ${var}/dimmed wall", worst, need))

    # SDDM: clock/date/labels over the blurred wallpaper (saturation 0.1) under a 20 % surface dim.
    from PIL import Image
    im = Image.open(f"{ROOT}/themes/{theme}/wallpaper.png").convert("RGB").resize((32, 18), Image.BOX)
    sur = col("surface")
    worst_fg = worst_var = 99.0
    for y in range(2, 12):          # clock to password field band
        for x in range(8, 24):      # centre half
            p = im.getpixel((x, y))
            grey = 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
            p = blend(p, (grey,) * 3, 0.1)
            p = blend(sur, p, 0.2)
            worst_fg = min(worst_fg, cr(col("on_surface"), p))
            worst_var = min(worst_var, cr(col("on_surface_variant"), p))
    rows.append(("sddm label fg/wallpaper overlay (worst)", worst_fg, 4.5))
    rows.append(("sddm date fgVar/wallpaper overlay (worst)", worst_var, 3.0))
    hs = blend(col("surface_container_high"), sur, 0.6)  # password box: surfaceHigh @ 0.6 over the dim
    add("sddm password text/box", col("on_surface"), hs, 4.5)

    # helium browser manifest
    hm = json.load(open(f"{out}/hush/helium-theme/manifest.json"))["theme"]["colors"]
    Hm = lambda x: tuple(hm[x])
    for f_, b_ in (("tab_text", "frame"), ("tab_background_text", "frame"), ("toolbar_text", "toolbar"),
                   ("bookmark_text", "toolbar"), ("toolbar_button_icon", "toolbar"), ("ntp_text", "ntp_background"),
                   ("ntp_link", "ntp_background"), ("omnibox_text", "omnibox_background")):
        add(f"helium {f_}/{b_}", Hm(f_), Hm(b_), 4.5)

    # gloview: borders (non-text, 3.0) against the card and backdrop they outline
    gtxt = open(f"{out}/hypr/modules/gloview-colors.lua").read()
    gv = {n: (int(a, 16) / 255, rgb(c)) for n, a, c in re.findall(r"(\w+) = 0x([0-9a-fA-F]{2})([0-9a-fA-F]{6})", gtxt)}
    back = blend(gv["backdrop_color"][1], col("surface"), gv["backdrop_color"][0])
    act = blend(gv["strip_active_color"][1], back, gv["strip_active_color"][0])
    add("gloview active border/active card", gv["strip_active_border"][1], act, 3.0)
    add("gloview hover border/backdrop", gv["hover_border"][1], back, 3.0)
    add("gloview select border/backdrop", gv["select_border"][1], back, 3.0)
    return rows


def main(argv):
    verbose = "--verbose" in argv
    argv = [a for a in argv if a != "--verbose"]
    outputs = None
    if "--outputs" in argv:
        i = argv.index("--outputs"); outputs = argv[i + 1]; del argv[i:i + 2]
    names = argv or THEMES
    table = {}
    for t in names:
        out = os.path.join(outputs, t) if outputs else render(t)
        table[t] = gate(t, out)
    order = [l for l, *_ in table[names[0]]]
    bad = 0
    print("%-50s" % "pair (min)" + "".join("%-13s" % n for n in names))
    for i, label in enumerate(order):
        mn = table[names[0]][i][2]
        cells, row_bad = [], 0
        for n in names:
            r = table[n][i][1]; ok = r >= mn; row_bad += not ok
            cells.append("%-13s" % ("%5.2f %s" % (min(r, 99), "ok" if ok else "FAIL")))
        bad += row_bad
        if verbose or row_bad:
            print("%-50s" % f"{label} ({mn:g})"[:50] + "".join(cells))
    per = {n: sum(1 for _, r, mn in table[n] if r < mn) for n in names}
    print(f"app contrast gate: {len(order)} pairs x {len(names)} themes, {bad} failing cells "
          f"({', '.join(f'{n} {per[n]}' for n in names)})", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

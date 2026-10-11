# Configuration

Paths assume a clone at `~/hush`. Settings live in `~/.config/hush/settings.json` and are
hot-reloaded; defaults are in `quickshell/hush/config/settings.default.json`.

## Hyprland

Hush ships no keybinds and no Hyprland config. Autostart `hush reload` then `hush shell start`,
and bind the IPC calls you want (README, Use).

The island is one transparent, full-width layer per monitor (`hush-island`, 360 px, never
resized); only its input mask follows the pill. Blur it with a layer rule:

```lua
hl.layer_rule({ match = { namespace = "hush-island" }, blur = true, ignore_alpha = 0.2 })
```

`island.mode`: `reserve` (default, `island.reserve` px exclusive zone), `overlay` (no reserved
space), `autohide` (1 px strip at the top edge reveals the pill on hover, workspace change and
events). A fullscreen window retracts the pill; the top edge still reveals it, and OSDs use their
own layer.

## Interaction

Hover 120 ms opens the hover face; it closes 300 ms after the pointer leaves. `island.clickLeft`,
`clickRight`, `clickMiddle` take `cc`, `notifs`, `media`, `calendar`, `launcher` or `none`;
`island.scroll` takes `volume`, `brightness` or `none`; `island.clock` is `24` or `12` (pill, lock
and login). Esc or a click outside closes a panel;
buttons ignore clicks for the first `motion.armMs` (500 ms). Critical notifications stay until
clicked.

Settings, Modules composes the island: which surfaces exist, what sits left and right of the
clock at rest, and the ordered chips of the hover face and tiles of the control center (1x1 or
2x1). It writes the `layout` key; "Reset layout" removes it. Over IPC:
`qs -c hush ipc call hush settingsSet layout.hover ' [...]'` (note the leading space).

## Environment

| Variable | Meaning |
| --- | --- |
| `HUSH_ROOT` | checkout to read themes, templates and the shell from (default: where `bin/hush` lives) |
| `XDG_CONFIG_HOME` | where generated files are written (default `~/.config`) |
| `HUSH_WALL_DIRS` | colon-separated extra wallpaper folders |
| `HUSH_REDUCED_MOTION` | `1` makes theme and wallpaper changes instant |

## Generated files

`hush generated` lists them: Hyprland `theme.lua` and `gloview-colors.lua`, kitty, Neovim,
GTK, qt6ct, Kvantum, fastfetch, waybar, hyprlock, and `~/.config/hush/` (colours, p10k, a
Chromium theme to load unpacked once from `chrome://extensions`). If `~/.config` is a git repo,
`hush track off` marks them skip-worktree.

## Plugins

`hush plugins install` runs `hyprpm add` and `enable` for GloView and dynamic-cursors (needs the
Hyprland headers; no sudo). Load the generated fragment once from `hyprland.lua`:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/hush/plugins.lua")
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("hush overview"))
```

## Lock and login

Both share `lockscreen/layout.toml`: a thin clock and date over the blurred wallpaper and one
black pill holding the avatar and the password. `hush face <image>` sets the avatar for both.

hyprlock: `hush reload` writes `~/.config/hush/hyprlock-layout.conf`, sourced by the shipped
`hyprlock.conf`; `hush lock` locks.

SDDM: `sudo sddm/install.sh` once. It copies the Qt 6 greeter with its fonts to
`/usr/share/sddm/themes/hush`, writes `/etc/sddm.conf.d/hush.conf` and links the theme's
`current` to `~/.cache/hush/sddm`, which `hush sddm sync` (called by `hush theme` and
`hush wall`) keeps up to date. A `Current=` line in `/etc/sddm.conf` wins over `conf.d`; the
installer prints the fix. `$HOME` must be traversable by the `sddm` user (`chmod o+x ~`).
Preview: `sddm-greeter-qt6 --test-mode --theme sddm/hush` in a nested compositor.

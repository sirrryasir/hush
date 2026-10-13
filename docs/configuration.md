# Configuration

Paths are relative to the clone. Settings live in `~/.config/hush/settings.json`, hot-reloaded
over the defaults in `quickshell/hush/config/settings.default.json`.

## Hyprland

Hush ships no Hyprland config; autostart and binds are in the README. The island is one
transparent layer per monitor (`hush-island`, full width, 360 px); only its input mask follows
the pill. Blur it with a layer rule:

```lua
hl.layer_rule({ match = { namespace = "hush-island" }, blur = true, ignore_alpha = 0.2 })
```

`island.mode`: `reserve` (default, `island.reserve` px exclusive zone), `overlay` (no reserved
space), `autohide` (1 px strip at the top edge reveals the pill on hover, workspace change and
events). A fullscreen window retracts the pill; the top edge still reveals it.

## Interaction

Hover 120 ms opens the hover face; it closes 300 ms after the pointer leaves. `island.clickLeft`,
`clickRight`, `clickMiddle` take `cc`, `notifs`, `media`, `calendar`, `launcher` or `none`;
`island.scroll` takes `volume`, `brightness` or `none`; `island.clock` is `24` or `12` (pill, lock
and login). Esc or a click outside closes a panel; buttons ignore clicks for the first
`motion.armMs` (500 ms). Critical notifications stay until clicked.

Settings, Modules composes the island: which surfaces exist, what sits left and right of the
clock at rest, and the ordered chips of the hover face and tiles of the control center (1x1 or
2x1) into the `layout` key; "Reset layout" removes it. Over IPC (note the leading space):
`qs -c hush ipc call hush settingsSet layout.hover ' [...]'`.

## Environment

| Variable | Meaning |
| --- | --- |
| `HUSH_ROOT` | checkout to read themes, templates and the shell from (default: where `bin/hush` lives) |
| `XDG_CONFIG_HOME` | where generated files are written (default `~/.config`) |
| `HUSH_WALL_DIRS` | colon-separated extra wallpaper folders |
| `HUSH_REDUCED_MOTION` | `1` makes theme and wallpaper changes instant |

## Generated files

`hush generated` lists them: Hyprland, GloView, kitty, Neovim, GTK, qt6ct, Kvantum, fastfetch,
waybar, hyprlock, p10k and a Chromium theme (load `~/.config/hush/helium-theme` unpacked from
`chrome://extensions`). If `~/.config` is a git repo, `hush track off` marks them skip-worktree.

## Plugins

`hush plugins install` runs `hyprpm add` and `enable` for GloView and dynamic-cursors (needs the
Hyprland headers; no sudo). Load the generated fragment once from `hyprland.lua`:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/hush/plugins.lua")
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("hush overview"))
```

## Lock and login

The lock and the login screen are one QML file, `lockscreen/Screen.qml`, sized by
`lockscreen/layout.toml`: a clock and the date over the blurred, dimmed wallpaper and one black
password pill with a status line under it. `hush face <image>` sets the login avatar; the lock has none.

Settings, Lock (or `lock.*` in `settings.json`): `lock.clock` `"quiet"` (default), `"bold"` (heavy
150 px figures) or `"stacked"` (hours over minutes, the pill lower); `lock.date`, `lock.name`,
`lock.status` (`true`) show the date, the user name over the pill and the fingerprint / wrong
password line; `lock.reveal` (`true`) hides the pill until a key, `false` keeps it shown.
The lock and the greeter read the same values; the page runs `hush sddm sync` on a change. The
hyprlock fallback takes only the clock's weight and size (on one line) and `lock.date`.

`hush lock` runs `quickshell/hush/lock.qml` as its own process, so a shell restart cannot unlock
it. The password goes through the PAM service `login`; with fprintd installed a finger on the
reader works too (`lockscreen/pam/fprint`, in parallel). If the lock dies, Hyprland keeps the
session locked: from a TTY run `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`, then
`hush lock`. `hush lock --hyprlock` uses hyprlock with the layout `hush reload` writes to
`~/.config/hush/hyprlock-layout.conf`.

SDDM: `sudo sddm/install.sh` once. It copies the greeter and its fonts to
`/usr/share/sddm/themes/hush`, writes `/etc/sddm.conf.d/hush.conf` and links the theme's `current`
to `~/.cache/hush/sddm`, which `hush sddm sync` (run by `hush theme` and `hush wall`) keeps up to
date. A `Current=` line in `/etc/sddm.conf` wins over `conf.d`; the installer prints the fix.
`$HOME` must be traversable by the `sddm` user (`chmod o+x ~`). `tests/test_sddm.sh` shows how to
preview the greeter with `sddm-greeter-qt6 --test-mode` in a nested compositor.

## Boot menu

`sudo integrations/refind/install.sh [theme]` copies an optional rEFInd theme to the ESP and
includes it from `refind.conf`. The banner is the theme's wallpaper at install time (default: the
current theme); rerun after `hush theme` to update it. To remove it, delete the
`include themes/hush/theme.conf` line from `refind.conf`.

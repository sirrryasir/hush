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

The lock and the login screen are one QML file, `lockscreen/Screen.qml`, sized by
`lockscreen/layout.toml`: a thin clock and the date over the wallpaper (blurred and multiplied by
0.6, or 0.3 in light themes so the white text reads), and one black pill for the password,
hidden until a key, a pointer move or a tap, with a status line under it. `hush face <image>`
sets the login avatar; the lock has none.

Settings, Lock (or `lock.*` in `settings.json`): `lock.clock` `"quiet"` (default), `"bold"` (heavy
150 px figures) or `"stacked"` (hours over minutes, the pill lower); `lock.date`, `lock.name`,
`lock.status` (`true`) show the date, the user name over the pill and the fingerprint / wrong
password line; `lock.reveal` (`true`) hides the pill until a key, `false` keeps it shown.
`lockscreen/gen.py` reads them into the generated layout, so the lock and the greeter agree; the
page runs `hush sddm sync` on a change. The hyprlock fallback takes only the clock's weight and size
(on one line) and `lock.date`.

Lock: `hush lock` runs `quickshell/hush/lock.qml` as its own Quickshell process (a shell restart
cannot unlock it). The password goes through the PAM service `login`. With fprintd installed a
second PAM context runs `lockscreen/pam/fprint` (`auth required pam_fprintd.so`) at the same
time: put a finger on the reader instead of typing; its prompts show under the pill. If the lock
process dies, Hyprland keeps the session locked; recover from a TTY with
`hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'` and run `hush lock` again.

hyprlock fallback: `hush lock --hyprlock`. `hush reload` writes
`~/.config/hush/hyprlock-layout.conf` (same geometry), sourced by the shipped `hyprlock.conf`.

SDDM: `sudo sddm/install.sh` once. It copies the Qt 6 greeter with its fonts to
`/usr/share/sddm/themes/hush` (with `lockscreen/Screen.qml`), writes `/etc/sddm.conf.d/hush.conf` and links the theme's
`current` to `~/.cache/hush/sddm`, which `hush sddm sync` (called by `hush theme` and
`hush wall`) keeps up to date. A `Current=` line in `/etc/sddm.conf` wins over `conf.d`; the
installer prints the fix. `$HOME` must be traversable by the `sddm` user (`chmod o+x ~`).
Preview: copy `lockscreen/Screen.qml` next to `sddm/hush/Main.qml` in a scratch copy, then
`sddm-greeter-qt6 --test-mode --theme <copy>` in a nested compositor (`tests/test_sddm.sh` does this).

## Boot menu

`integrations/refind/` is an optional rEFInd theme: white OS glyphs, a small triangle under the chosen one.
Install with `sudo integrations/refind/install.sh`; it copies the theme to the ESP and includes it from `refind.conf`.
The banner is the current theme's wallpaper at install time (or `install.sh <theme>`); rerun the installer after `hush theme` to update it.
Remove: delete the `include themes/hush/theme.conf` line from `refind.conf`.

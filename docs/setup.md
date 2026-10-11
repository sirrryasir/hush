# Setup details

Details moved out of the README. Paths assume a clone at `~/hush`.

## Hyprland

Hush ships no keybinds and no Hyprland config of its own. Start it from autostart with
`hush reload` then `hush shell start`, and bind the IPC calls you want (see the README).

The island is one transparent, full-width layer per monitor (namespace `hush-island`, 360 px
tall, never resized); only its input mask follows the pill, so clicks beside the pill reach your
windows. Blur it with a layer rule; `ignore_alpha` keeps the transparent area unblurred:

```lua
hl.layer_rule({ match = { namespace = "hush-island" }, blur = true, ignore_alpha = 0.2 })
```

`island.mode` in `~/.config/hush/settings.json`:

- `reserve` (default): `island.reserve` (40 px) exclusive zone.
- `overlay`: no reserved space.
- `autohide`: a 1 px strip at the top edge (`hush-island-reveal`) shows the pill on hover, on
  workspace change and for OSDs, notifications and the control center.

A fullscreen window retracts the pill; moving the pointer to the top edge reveals it over the
window, and OSDs show on their own layer (`hush-island-osd`).

## Island interaction

Hovering the pill for 120 ms opens the hover face (this monitor's workspaces, the date, the
playing title); it closes 300 ms after the pointer leaves. Clicks map through `island.clickLeft`,
`clickRight` and `clickMiddle` (`cc`, `notifs`, `media`, `calendar`, `launcher` or `none`;
defaults: control center, notification center, media). `island.scroll` is `volume`,
`brightness` or `none`. Clicking the date on the hover face opens the calendar. Esc or a click
outside closes a panel; its buttons ignore clicks for the first 500 ms (`motion.armMs`). A
critical notification stays up until clicked and holds later cards in the queue.

## Composing the island

Settings, Modules decides what the island shows, in four sections. Surfaces turns whole surfaces
(media, notifications, calendar, launcher, wallpapers, settings) on or off. Rest picks the resting
pill's sides: the activity circle on the left, the status slot on the right (Behaviour, Status
centre), the clock always in the middle. Hover face and Control center list their chips and
tiles as rows: a switch shows or hides one, the arrows (or Shift+Up/Down) move it, and a control
center tile toggles between 1x1 and 2x1 on a four-column grid. Every change applies at once and
is saved to the `layout` key of `~/.config/hush/settings.json`, which can also be set over IPC:
`qs -c hush ipc call hush settingsSet layout.hover ' [...]'` (a space before an array).
"Reset layout" removes the key so `quickshell/hush/config/settings.default.json` applies again.

## Environment

| Variable | Default | Meaning |
| --- | --- | --- |
| `HUSH_ROOT` | the checkout `bin/hush` lives in | where themes, templates and the shell are read from |
| `XDG_CONFIG_HOME` | `~/.config` | where generated files are written |
| `HUSH_WALL_DIRS` | unset | colon-separated extra wallpaper folders for `hush wall random` and the grid |
| `HUSH_REDUCED_MOTION` | unset | `1` makes theme and wallpaper changes an instant swap |

## Plugins

`hyprpm` builds plugins from source, so it needs the Hyprland headers (`hyprpm update` pulls
them). `hush plugins install` runs `hyprpm add` and `enable` for whatever is missing and never
uses sudo; `hush check` only warns when a plugin is not loaded. `install.sh` links
`hypr/plugins.lua` to `~/.config/hush/plugins.lua`; load it once from `hyprland.lua` and it
loads both plugins from the hyprpm cache (skipping any that are missing), configures
dynamic-cursors and applies the generated GloView colours:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/hush/plugins.lua")
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("hush overview"))
```

## Generated files

`hush generated` lists them. They land in `~/.config`: Hyprland `hypr/modules/theme.lua` and
`gloview-colors.lua`, kitty `theme.conf`, `nvim/colors/hush.lua`, GTK, qt6ct, Kvantum,
fastfetch, waybar, hyprlock and `~/.config/hush/` (`Colors.json`, p10k colours, browser theme).
If `~/.config` is itself a dotfiles repo, `hush track off` marks the tracked ones
`skip-worktree` so `git commit -a` leaves them alone. The fastfetch template reads its logo from
`~/.config/fastfetch/logo.txt`.

## What `install.sh` links

`~/.config/quickshell/hush`, `~/.config/matugen`, `~/.config/hyprlock`,
`~/.config/hypr/hyprlock.conf`, `~/.local/bin/hush*`, `~/.config/hush/plugins.lua` and (for
LazyVim) `~/.config/nvim/lua/plugins/hush-theme.lua` point into the checkout. Fonts go to
`~/.local/share/fonts/hush`, the git hooks are enabled and `harbor` is applied on first run
(`--no-fonts` and `--no-theme` skip those steps). It is idempotent and never overwrites a real
file: anything in the way is moved to `~/.cache/hush/backup-<timestamp>/`.

## Helium (Chromium)

`hush theme` also writes a Chromium theme to `~/.config/hush/helium-theme/`. Load it once:
`chrome://extensions`, Developer mode, Load unpacked, choose that folder. Restart the browser after
a theme change; pages that follow `prefers-color-scheme` switch with the GTK preference `hush` sets.

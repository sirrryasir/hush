<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/social/readme-header-dark.svg" />
    <source media="(prefers-color-scheme: light)" srcset="assets/brand/social/readme-header-light.svg" />
    <img src="assets/brand/social/readme-header-light.svg" alt="Hush" width="600" />
  </picture>
  <p>A quiet, Apple-calm Hyprland desktop: one Quickshell shell, six themes, one command that recolors everything.</p>
  <img src="assets/themes/harbor-cc.png" alt="Hush, harbor theme, control center open" width="860" />
</div>

## What it is

Hush is a quiet, Apple-calm desktop for Hyprland (0.55+, Lua config) on Arch. A single Quickshell shell provides the dynamic island (clock, media, OSD, notifications, control center), launcher, wallpaper grid, settings and notification center, all grown out of the island. `hush theme <name>` picks a wallpaper, runs matugen and re-renders colors for the shell, Hyprland, kitty, Neovim, GTK, Qt, Kvantum, hyprlock, fastfetch and the browser theme in one pass.

<table>
  <tr>
    <td><img src="assets/themes/dusk.png" alt="dusk" /><br/><sub>dusk</sub></td>
    <td><img src="assets/themes/ember.png" alt="ember" /><br/><sub>ember</sub></td>
    <td><img src="assets/themes/fog.png" alt="fog" /><br/><sub>fog</sub></td>
  </tr>
  <tr>
    <td><img src="assets/themes/harbor.png" alt="harbor" /><br/><sub>harbor</sub></td>
    <td><img src="assets/themes/moss.png" alt="moss" /><br/><sub>moss</sub></td>
    <td><img src="assets/themes/paper.png" alt="paper" /><br/><sub>paper</sub></td>
  </tr>
</table>

Control center per theme: [dusk](assets/themes/dusk-cc.png), [ember](assets/themes/ember-cc.png), [fog](assets/themes/fog-cc.png), [harbor](assets/themes/harbor-cc.png), [moss](assets/themes/moss-cc.png), [paper](assets/themes/paper-cc.png).

## What's inside

- `quickshell/hush/`: the shell (island and its surfaces: control center, launcher, wallpaper grid, settings, notification center; notification daemon)
- `bin/hush`: the CLI; `bin/hush-wallgen`, `bin/hush-fonts`, `bin/hush-gtk`: helpers
- `matugen/`: templates and per-target config fragments that render the theme
- `themes/`: one folder per theme (`theme.toml` plus a generated wallpaper)
- `hyprlock/`: lock screen config and layout (colors are generated)
- `sddm/`: SDDM login theme and its sudo installer
- `lockscreen/`: the shared lock/login layout spec and its generator
- `integrations/nvim/`: a LazyVim plugin spec that follows the generated colorscheme
- `tests/`: `bash tests/run_all.sh` (live tests drive the running shell and Hyprland)

## Commands

| Command | What it does |
| --- | --- |
| `hush list` | list the themes |
| `hush theme <name\|next\|prev>` | apply a theme (wallpaper, colors, reloads) |
| `hush wall <path\|random>` | change the wallpaper, keep the theme's scheme |
| `hush wall/theme ... --from X,Y` | circle-reveal transition from pixel X,Y (default: island centre on the focused monitor); `HUSH_REDUCED_MOTION=1` or `island.reducedMotion` gives an instant swap |
| `hush reload` | re-render templates for the current state |
| `hush status` | print active theme, wallpaper, mode, scheme |
| `hush check` | validate generated config (exit 1 on problems) |
| `hush generated` / `hush track <on\|off>` | list generated files that a git repo tracks / mark them skip-worktree there |
| `hush fallback` | stop the Hush shell, start Waybar and SwayNC |
| `hush shell <start\|stop\|restart\|status\|log>` | manage the Quickshell shell |
| `hush sddm sync` | refresh the SDDM theme's wallpaper, colors and avatar |
| `hush lock` | lock the screen with hyprlock (once) |
| `hush face <image>` | set the lock and login avatar (round crop to `~/.face`, then `hush sddm sync`) |
| `hush settings` | open (or close) the settings surface in the island |
| `hush overview` | open the GloView overview (needs the plugin) |
| `hush plugins [status\|install]` | status of, or install, the optional Hyprland plugins |
| `hush timer <N>m\|<N>s\|<N>h\|stop` | start a countdown shown at rest in the island, or cancel it |
| `hush volume up\|down\|mute\|mic-mute [step]` | change the output volume (default 5 %, capped at 100 %) or toggle mute; the island shows the OSD |
| `hush brightness up\|down [step]` | change the screen brightness (default 5 %); the island shows the OSD |
| `hush --version` | print the version |

### Keyboard

In the island's panels, Tab and Shift+Tab (or the arrow keys) move focus, Left and Right step a slider (hold Shift for steps of ten), Enter or Space activates the focused control, and Esc closes the panel. Suggested binds: Super+Backspace for the control center and Super+Space for the launcher; scrolling over the pill changes the volume.

## Add a theme

1. Create `themes/<name>/` with a `theme.toml` (copy an existing one) and a wallpaper.
2. Run `hush-wallgen` to generate its wallpapers.
3. `hush theme <name>`.

## Keybinds

Hush ships no keybinds; bind the IPC calls and commands in your Hyprland config, for example:

```lua
hl.bind("SUPER + Backspace", hl.dsp.exec_cmd("qs -c hush ipc call hush toggleControlCenter"))
hl.bind("SUPER + A",         hl.dsp.exec_cmd("qs -c hush ipc call hush toggleLauncher"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("qs -c hush ipc call hush toggleDrawer"))
hl.bind("SUPER + CTRL + W",  hl.dsp.exec_cmd("qs -c hush ipc call hush toggleWallpapers"))
hl.bind("SUPER + V",         hl.dsp.exec_cmd("qs -c hush ipc call hush showLauncher clip"))
hl.bind("SUPER + ALT + right", hl.dsp.exec_cmd("~/.local/bin/hush theme next"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/hush wall random"))
```

and start it from autostart: `hush reload` then `hush shell start`.

The island is one transparent, full-width layer per monitor (namespace `hush-island`, 360 px tall, never resized); only its input mask follows the pill, so clicks beside the pill reach your windows. Blur it with a layer rule; `ignore_alpha` keeps the transparent area unblurred:

```lua
hl.layer_rule({ match = { namespace = "hush-island" }, blur = true, ignore_alpha = 0.2 })
```

`island.mode` in `~/.config/hush/settings.json` picks `reserve` (default, `island.reserve` = 40 px exclusive zone), `overlay` (no reserve) or `autohide` (a 1 px strip at the top edge, `hush-island-reveal`, shows the pill on hover, on workspace change and for OSDs, notifications and the control center). A fullscreen window retracts the pill.

Hovering the pill for 120 ms opens the hover face (this monitor's workspaces, the date, the playing title); it closes 300 ms after the pointer leaves. Left click opens the control center, right click the notification center, middle click the media panel, and the wheel sets the volume (`island.clickLeft`/`clickRight`/`clickMiddle`: `cc`, `notifs`, `media`, `calendar`, `launcher` or `none`; `island.scroll`: `volume` or `none`; timings under `motion`). Clicking the date on the hover face opens the calendar. Esc or a click outside closes a panel, and its buttons ignore clicks for the first 500 ms (`motion.armMs`).

## Plugins (optional)

Two Hyprland plugins pair well with Hush; both are optional and Hush works without them.

- **GloView** is a Mission Control style overview: every window of every workspace, with a workspace strip on top, coloured from the active theme.
- **dynamic-cursors** makes the cursor feel physical and adds shake to find: wiggle the mouse and the cursor grows (2x) so you can spot it.

```bash
hush plugins            # status: loaded (hyprctl) and installed (hyprpm)
hush plugins install    # hyprpm add + enable for whatever is missing; never uses sudo
```

`hyprpm` builds plugins from source, so it needs the Hyprland headers (`hyprpm update` pulls them). `hush check` only warns when a plugin is not loaded. `hush overview` runs `hyprctl gloview`; bind it, for example `hl.bind("SUPER + Tab", hl.dsp.exec_cmd("hush overview"))`, and press Super+Tab for the overview. `install.sh` links `hypr/plugins.lua` to `~/.config/hush/plugins.lua`; load it once from `hyprland.lua` and it loads both plugins from the hyprpm cache (skipping any that are missing), configures dynamic-cursors and applies the generated GloView colours:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/hush/plugins.lua")
```

## Installation

Needs Hyprland, Quickshell (`qs`), matugen, python3 with Pillow, lua, awww (wallpapers), imagemagick and git.

```bash
git clone https://github.com/sirrryasir/hush.git ~/hush
~/hush/install.sh          # --no-fonts / --no-theme to skip those steps
```

`install.sh` symlinks `~/.config/quickshell/hush`, `~/.config/matugen`, `~/.config/hyprlock`, `~/.config/hypr/hyprlock.conf`, `~/.local/bin/hush*` and (for LazyVim) `~/.config/nvim/lua/plugins/hush-theme.lua` into the checkout, installs the fonts into `~/.local/share/fonts/hush`, enables the git hooks and applies `harbor` on first run. It is idempotent and never overwrites a real file: anything in the way is moved to `~/.cache/hush/backup-<timestamp>/`.

## Configuration

| Setting | Default | Meaning |
| --- | --- | --- |
| `HUSH_ROOT` | the checkout that `bin/hush` lives in | where themes, templates and the shell are read from |
| `XDG_CONFIG_HOME` | `~/.config` | where generated files are written |
| `HUSH_WALL_DIRS` | unset | colon-separated extra wallpaper folders for `hush wall random` and the wallpaper grid |

### Composing the island

Settings → Modules decides what the island shows, in four sections. Surfaces turns whole surfaces (media, notifications, calendar, launcher, wallpapers, settings) on or off. Rest picks the resting pill's sides: the activity circle on the left, the status slot on the right (what the slot shows is Behaviour → Status centre), the clock always in the middle. Hover face and Control center list their chips and tiles as rows: a switch shows or hides one, the arrows move it (or Shift+Up/Down with the row focused), and a control center tile toggles between 1x1 and 2x1 on a four-column grid; chips for things that are not there (Bluetooth off, no battery, no timer) leave no gap. The Sliders, Media, Themes and Power chips under the tiles switch those control center sections off. Every change applies at once and is saved to the `layout` key of `~/.config/hush/settings.json` (`hush settings`, or `qs -c hush ipc call hush settingsSet layout.hover ' [...]'`, with a space before an array); "Reset layout" removes the key so the defaults in `config/settings.default.json` apply again.

### Lock and login screens

Both screens share one layout, "island-native" (`lockscreen/layout.toml`, sizes at 1080p, positions as fractions of the screen height): a thin Inter clock with tabular figures and the date over the blurred, dimmed wallpaper, and one black pill, the same black as the bar island, holding your avatar and the password. Battery and network sit top right as icons only. A wrong password turns the pill's hairline red; no "wrong password" text is shown. `hush face <image>` sets the avatar for both (a round 512 px crop written to `~/.face`).

- Lock (`hush lock`, hyprlock): `hush reload` and `hush lock` generate `~/.config/hush/hyprlock-layout.conf` from the spec, one widget set per connected monitor; `hyprlock/hyprlock.conf` sources it. Caps lock and the fingerprint prompt show as glyphs inside the pill. hyprlock cannot animate shapes, so the lock screen is the static form of the layout.
- Login (SDDM): `sddm/hush/` is a Qt6 greeter with the same layout plus motion: the pill grows when you type, a round submit button appears, it shrinks to a circle with a spinning arc while checking, shakes with a red hairline and clears on a wrong password, and fades with the clock lifting on success. Three black buttons at the bottom open the session list (Hyprland first, your last choice remembered), suspend, and restart/shut down. It is keyboard-first: type and press Enter; Tab reaches the buttons, arrows and Enter pick a session, Esc closes.

Install the greeter once, as root (`install.sh` never runs sudo for you):

```
sudo sddm/install.sh
```

This copies the theme to `/usr/share/sddm/themes/hush` with Inter and Material Symbols (the greeter runs as the `sddm` user and cannot see your fonts), writes `/etc/sddm.conf.d/hush.conf` (`[Theme] Current=hush`) and links `hush/current` to `~/.cache/hush/sddm`. A `Current=` line in `/etc/sddm.conf` is read last and wins over `hush.conf`; the installer prints the one-line fix when it finds one. `hush sddm sync` writes the wallpaper, avatar, palette (`colors.qml`) and layout (`layout.qml`) there, world-readable; `hush theme` and `hush wall` call it once that directory exists, `hush face` always does. `$HOME` must be traversable by the `sddm` user (`chmod o+x ~`); `hush sddm sync` warns when it is not. Preview without logging out: `sddm-greeter-qt6 --test-mode --theme sddm/hush` inside a nested compositor (`tests/test_sddm.sh` does this in a nested Hyprland).

Generated files (`hush generated`) land in `~/.config`: Hyprland `hypr/modules/theme.lua` and `gloview-colors.lua`, kitty `theme.conf`, `nvim/colors/hush.lua`, GTK, qt6ct, Kvantum, fastfetch, waybar, hyprlock and `~/.config/hush/` (Colors.json, p10k colors, browser theme). If `~/.config` is itself a dotfiles repo, `hush track off` marks the tracked ones `skip-worktree` so `git commit -a` leaves them alone. The fastfetch template reads its logo from `~/.config/fastfetch/logo.txt`.

## Contributing

Conventional Commits, one coherent change per commit, tests green first; see [docs/COMMITS.md](docs/COMMITS.md). `install.sh` enables the `pre-commit` (personal-data scan and `hush check`) and `commit-msg` hooks.

## Credits

[Quickshell](https://quickshell.org), [matugen](https://github.com/InioX/matugen), and the caelestia and Tide-island shells as references.

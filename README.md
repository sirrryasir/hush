# Hush

A dynamic island shell for Hyprland, built on Quickshell. One pill at the top of each monitor
replaces the bar, launcher, notification daemon and control center.

<table>
  <tr><td><img src="assets/screens/hover.png" alt="hover face" /><br/><sub>hover</sub></td><td><img src="assets/screens/control-center.png" alt="control center" /><br/><sub>control center</sub></td></tr>
  <tr><td><img src="assets/screens/launcher.png" alt="launcher" /><br/><sub>launcher</sub></td><td><img src="assets/screens/lock.png" alt="lock screen" /><br/><sub>lock</sub></td></tr>
</table>

## Install

Needs Hyprland 0.56 or later (Lua config), Quickshell 0.3, matugen 4, awww, python3 with Pillow, lua, imagemagick and git; fprintd is optional, for fingerprint unlock.

```bash
yay -S hush-shell && hush install    # Arch (hush-git tracks main)
git clone https://github.com/sirrryasir/hush.git ~/hush
~/hush/install.sh                    # --no-fonts / --no-theme skip those steps
```

`install.sh` links the shell, matugen files and `hush*` into `~/.config` and `~/.local/bin`, installs
fonts and sets the `harbor` theme. It never uses sudo and never overwrites a real file: anything in
the way moves to `~/.cache/hush/backup-<timestamp>/`. Then start `hush reload` and `hush shell start`
from `hyprland.lua`.

## Use

- **Pill**: clock, timer, recording and now playing at rest; click or scroll it for more.
- **Hover face**: hover the pill for workspaces, date and the current track.
- **Control center**: Wi-Fi, Bluetooth, VPN, sound, battery, tiles; `Super+Backspace`.
- **Launcher**: apps, windows, calculator and clipboard history; `Super+A`, `Super+V`.
- **Notifications**: popups queue by priority; the drawer keeps the rest; `Super+Shift+N`.
- **Calendar**: month view with reminders that notify when due.
- **Wallpapers**: a grid that sets wallpaper and colours; `Super+Ctrl+W`.
- **Lock**: `hush lock`; password or fingerprint, and a shell restart cannot unlock it.
- **Settings**: `hush settings`; island, behaviour, shortcuts, modules and theme.
- **Terminal jobs**: a card when a command takes 20 s or more; source `~/.config/hush/shell.sh`.

## Themes

Six themes ship: dusk, ember, fog, harbor, moss and paper. `hush theme <name|next|prev>` applies one
and `hush wall <path|random>` takes the colours from any image instead. Either one recolours the
shell, Hyprland, GTK, Qt (Kvantum and qt6ct), kitty and Neovim. A new theme is a `themes/<name>/`
folder with a `theme.toml` and a `wallpaper.png`.

## Keys

Hush ships no keybinds. Suggested ones, as `hl.bind(combo, hl.dsp.exec_cmd(cmd))`:

| Keys | Command |
| --- | --- |
| Super+Backspace | `qs -c hush ipc call hush toggleControlCenter` |
| Super+A | `qs -c hush ipc call hush toggleLauncher` |
| Super+V | `qs -c hush ipc call hush showLauncher clip` |
| Super+Shift+N | `qs -c hush ipc call hush toggleDrawer` |
| Super+Ctrl+W | `qs -c hush ipc call hush toggleWallpapers` |
| Super+Shift+W | `hush wall random` |
| Super+Tab | `hush overview` |

Inside any panel: Tab and the arrows move focus, Enter or Space activates, Esc closes.

## Settings

`hush settings` writes `~/.config/hush/settings.json`, which loads over
`quickshell/hush/config/settings.default.json` and can be edited by hand. It sets the island mode
(`reserve`, `overlay` or `autohide`), what each click and scroll does, which surfaces and control center
tiles exist, your shortcuts (with copyable bind blocks) and the theme. Other commands: `hush status`,
`hush reload`, `hush shell <start|stop|restart|status|log>`, `hush timer 25m`, `hush volume`,
`hush brightness`. `HUSH_ROOT`, `XDG_CONFIG_HOME`, `HUSH_WALL_DIRS` and `HUSH_REDUCED_MOTION` change paths and motion.

## License

MIT.

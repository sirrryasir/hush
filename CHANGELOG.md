# Changelog

All notable changes to Hush are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). Commit rules are in the README (Contributing).

## [Unreleased]

### Added

- `lock` in settings.json: `hyprlock` makes `hush lock`, the control center and hypridle use hyprlock instead of the Quickshell lock.

## [0.3.0] - 2026-10-28

### Added

- Focus page: the ring is a dial (drag or scroll) for the focus, break and long-break minutes, and the cycles row sets 1 to 8 blocks; saved in `focus` in settings.json.
- Settings, Modules: the Rest and Hover face tabs show a live preview of the real rest pill or hover face above the rows.
- Settings: a Shortcuts page records a key combo per island action and shows copyable Hyprland and Lua bind blocks built from them.
- Control center: a Focus tile (on by default) opens the focus session page and reads the running phase and time; the control center grid places tiles first-fit, so a 2x1 no longer leaves empty cells.
- Job done: a terminal command that ran 20 s or more raises a card on the island when it ends
  (tick or cross, command, duration, exit code, terminal and workspace; Open focuses it), through
  `integrations/shell/hush.sh` for zsh and bash.
- Island: a file shelf. Drag files onto the pill to keep them for 24 h, then drag them out of the strip into any app, copy or remove them; a `shelf` chip on the hover face (on by default, shown while files are kept) opens the strip.
- Reminders: a time and a text kept in `~/.config/hush/reminders.json`; due ones raise a notification, the calendar shows a dot on days that have one, lists the selected day and adds or removes them (it replaces the khal list), and the next one within the hour shows on the rest pill.
- Island: a removable drive raises a card (name, size, filesystem, Mount, Open, Eject; "Safe to
  remove" after an eject) from `udisksctl monitor` and `dump`; a USB glyph on the rest pill while
  one is plugged in.
- Control center: log out (ends the Hyprland session) next to lock.
- Login: the name over the pill opens the user list when the machine has more than one account.
- Control center, Wi-Fi page: the joined network's signal, band, security and IPv4; Forget on a
  saved network (asks twice); "Join hidden network"; a hotspot row (`nmcli dev wifi hotspot`).
- Control center: `vpn` tile (on by default, hidden without a VPN or WireGuard profile); one
  profile toggles on tap, several open a page listing them.
- Control center: `airplane` tile (off by default, hidden without an rfkill switch), `rfkill block
  all` / `unblock all`; the rfkill probe moved from Bt into `services/Rfkill.qml`.
- Control center: `caffeine` tile ("Stay awake", off by default) holds a Wayland idle inhibitor until
  turned off; the rest pill's status ring shows a cup meanwhile.
- Control center: a focus page behind the timer tile (25 / 5 / 15 min, long break after the fourth
  block, a notification at each phase change); do not disturb is on for the session and restored
  after; the rest pill shows the block count ("2/4"); the session survives a shell restart.
- Control center: app status icons (StatusNotifierItem) behind a button in the top row, shown with
  their count while an app registers one; the page lists them, a tap activates, a right click or the
  trailing glyph lists the item's menu in place.
- Control center: sound page behind the volume slider's end glyph: output devices (tap picks the
  default), the microphone and each playing application, each with a level and a mute.
- Control center: power profile page behind the battery chip when powerprofilesctl is installed; the
  chip names the profile while power-saver is active.

### Fixed

- Control center: the panel grows for the tiles it holds instead of squeezing them; the hover face widens for its chips; "again to confirm" no longer pushes the power buttons off the edge.
- Settings: option lists open inside the surface instead of being clipped; the Shortcuts page records Super from the real keyboard.

- Boot menu: the Windows icon applies to Windows 8 and later (`os_win8.png`), and Linux boots
  without the rEFInd text screen.

## [0.2.0] - 2026-10-13

### Added

- Island: one fixed full-width layer per monitor with an input mask and a spring morph; rest pill
  (clock, activity circle, status ring), hover face, click and scroll mapping.
- Surfaces: control center (Wi-Fi password entry, Bluetooth pairing), media with spectrum,
  calendar, notification center, launcher (apps, windows, calculator, clipboard), wallpapers, settings.
- Priority arbiter with a resuming queue for OSDs and notifications; critical notifications stay.
- Live activities at rest: recording, countdown (`hush timer`), now playing, mic and camera in use.
- Modes `reserve`, `overlay`, `autohide`; fullscreen retract and OSD overlay; keyboard navigation;
  reduced motion.
- Settings surface and `settings.json` (hot-reloaded), with a composer for the rest pill, hover
  face and control center.
- Circle-reveal wallpaper transition (`--from`) and shell colour cross-fade.
- Lock and login from one QML screen (`lockscreen/Screen.qml`): `hush lock` with PAM password and
  fprintd, and an SDDM greeter (`sddm/install.sh`, `hush sddm sync`, `hush face`).
- Lock clock styles (quiet, bold, stacked) and `lock.*` settings; 12 or 24 hour clock (`island.clock`).
- Optional rEFInd boot menu theme (`integrations/refind`).
- CLI: `lock [--hyprlock]`, `face`, `settings`, `timer`, `volume`, `brightness`, `plugins`,
  `overview`; optional GloView and dynamic-cursors plugins.
- `tests/sandbox.sh` runs the suite in a nested headless Hyprland.
- Demo video, theme screenshots and brand files (icon, README header, social preview).

### Fixed

- Contrast of light themes in the island, hyprlock, Neovim, kitty ANSI black and p10k.
- No volume OSD when the default sink switches; scroll to brightness; Media `canSeek` guard.
- The single-instance rule counts only this compositor; Bluetooth lifts an rfkill block.
- Settings pages scroll; the Live activities switch hides the pill slot; an empty clipboard
  history no longer reads as a missing cliphist; the first surface after start-up gets keys.

### Changed

- README rewritten to cover configuration.
- hyprlock is now the fallback lock (`hush lock --hyprlock`).

## [0.1.0] - 2026-10-02

First release, extracted from the author's dotfiles into its own repository.

### Added

- Quickshell shell `hush` (`qs -c hush`): a dynamic island per monitor that follows the
  focused monitor (clock, media, volume and brightness OSD, notifications, control center
  with a theme strip), rounded screen corners, an app/window/calculator/clipboard launcher,
  a wallpaper grid, a notification drawer and its own notification daemon, all driven over
  `qs -c hush ipc call hush ...`.
- `hush` CLI: `list`, `theme <name|next|prev>`, `wall <path|random> [--mode]` (colours and
  light/dark mode derived from the image), `reload`, `status`, `check`, `generated`,
  `track <on|off>`, `fallback`, `shell <start|stop|restart|status|log>` and `--version`.
  Renders are atomic and serialized with a lock; `state.json` is written last.
- Six themes (dusk, ember, fog, harbor, moss, paper) with wallpapers generated by
  `hush-wallgen` from a seed in each `theme.toml`.
- matugen templates for the shell (`Colors.json`), Hyprland (`theme.lua`, gloview), kitty,
  Neovim, GTK 3/4, qt6ct, Kvantum, hyprlock, fastfetch, waybar, powerlevel10k and a
  Chromium/Helium browser theme. Fragments use `@HUSH_ROOT@`/`@CONFIG@` placeholders, so
  nothing depends on where the repository is cloned.
- hyprlock config and a default layout that read the generated colours and wallpaper.
- LazyVim integration (`integrations/nvim/hush-theme.lua`) that reloads the colorscheme
  when the theme changes.
- `install.sh` (idempotent symlinks with backups, fonts, git hooks, first theme),
  `hush-fonts` and `hush-gtk` (no sudo).
- Test suite (`tests/run_all.sh`): template rendering, CLI behaviour, live Hyprland and
  shell checks, WCAG contrast across themes, git hooks and a personal-data scan.
- Git hooks: `pre-commit` (personal-data scan, `hush check`) and `commit-msg`
  (Conventional Commits).

[Unreleased]: https://github.com/sirrryasir/hush/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sirrryasir/hush/releases/tag/v0.1.0

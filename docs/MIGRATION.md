# Migration from the dotfiles repo (2026-10-02)

Hush grew inside the author's personal dotfiles (`~/dotfiles`). For 0.1.0 it was copied into
this repository with a fresh history; the old history stays in the dotfiles repo. This file
records where every piece went and how the live `~/.config` resolves now.

## Mapping

| dotfiles path | Hush path | Notes |
| --- | --- | --- |
| `bin/hush`, `bin/hush-wallgen`, `bin/hush-fonts`, `bin/hush-gtk` | same | `DOTS=/home/...` replaced by `HUSH_ROOT` (default: the checkout `bin/hush` resolves into); `hush --version` reads `VERSION` |
| `quickshell/hush/` | same | new `config/Paths.qml` resolves the repo (`HUSH_ROOT` env, else `readlink -f <shellDir>/../..`); no absolute paths, no monitor names (fallback is the first screen) |
| `themes/` | same | |
| `matugen/config.toml.head`, `matugen/config.d/`, `matugen/templates/` | same | fragments use `@HUSH_ROOT@` (inputs) and `@CONFIG@` (outputs, `${XDG_CONFIG_HOME:-~/.config}`), substituted by `assemble_config`; fastfetch logo read from `~/.config/fastfetch/logo.txt` |
| `hypr/hyprlock.conf` | `hyprlock/hyprlock.conf` | linked to `~/.config/hypr/hyprlock.conf` |
| `hyprlock/layouts/layout_<owner>.conf` | `hyprlock/layouts/layout_default.conf` | renamed from the owner-named layout |
| `hyprlock/colors.conf` | `hyprlock/colors.conf` | generated; gitignored here |
| `nvim/lua/plugins/hush-theme.lua` | `integrations/nvim/hush-theme.lua` | linked into `~/.config/nvim/lua/plugins/` |
| `docs/hush/helium.md` | `docs/helium.md` | |
| `.githooks/pre-commit` | same | now also runs `tests/test_no_personal.sh`; new `commit-msg` hook |
| `tests/` (all but `test_remnants.sh`) | same | paths via `HUSH_ROOT` and `CFG` from `tests/lib.sh`; monitor names discovered at runtime; new `test_no_personal.sh` |
| `assets/themes/`, `assets/evidence/timelapse/` | same | |
| `README.md` | same | rewritten for a standalone repo |

### Left in the dotfiles repo on purpose

- `tests/test_remnants.sh`: checks the dotfiles for HyDE leftovers; personal.
- `hyprlock/` legacy layouts, scripts and wallpapers (third-party layouts with foreign home
  paths and a personal photo path); unused since `~/.config/hyprlock` points here.
- `docs/superpowers/` and `.superpowers/` (design spec, plans, build evidence, review): they
  are written around the author's machine and paths, so they stay with the dotfiles history.
- `docs/research/`: still being written when the move happened; to be moved later.
- `Kvantum/hush/`: both files are matugen output, so nothing was moved; the dotfiles repo
  untracked and gitignored them and Hush renders them to `~/.config/Kvantum/hush/`.

### Generated files

`hush generated` lists every matugen output that some git repo tracks, as an absolute path;
`hush track off` marks each one `skip-worktree` in that repo. After the move:

| output (under `~/.config`) | lives in | status |
| --- | --- | --- |
| `hypr/modules/theme.lua`, `hypr/modules/gloview-colors.lua`, `kitty/theme.conf`, `nvim/colors/hush.lua`, `fastfetch/config.jsonc`, `qt6ct/colors.conf`, `waybar/colors.css` | dotfiles | tracked as seeds (Hyprland needs `theme.lua` at first start), `skip-worktree` |
| `hyprlock/colors.conf` | this repo | gitignored |
| `Kvantum/hush/hush.kvconfig`, `Kvantum/hush/hush.svg` | dotfiles tree | untracked, gitignored there |
| `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`, `hush/Colors.json`, `hush/p10k-colors.zsh`, `hush/helium-theme/manifest.json` | plain `~/.config` | not in any repo |

## How `~/.config` resolves now

`install.sh` creates these links (backing up any real file to `~/.cache/hush/backup-<ts>/`):

```
~/.config/quickshell/hush          -> ~/hush/quickshell/hush
~/.config/matugen                  -> ~/hush/matugen
~/.config/hyprlock                 -> ~/hush/hyprlock
~/.config/hypr/hyprlock.conf       -> ~/hush/hyprlock/hyprlock.conf    (inside the dotfiles hypr/ dir)
~/.config/nvim/lua/plugins/hush-theme.lua -> ~/hush/integrations/nvim/hush-theme.lua
~/.local/bin/hush, hush-wallgen, hush-fonts, hush-gtk -> ~/hush/bin/...
```

Everything else in `~/.config` (hypr, kitty, nvim, fastfetch, qt6ct, Kvantum, waybar, ...)
still links into the dotfiles repo, whose `install.sh` clones this repo to `~/hush` if needed
and runs `~/hush/install.sh`. Hyprland keeps calling `~/.local/bin/hush`, so autostart and
binds did not change. Personal settings moved to the dotfiles: `HUSH_WALL_DIRS` (extra
wallpaper folders) is set in `hypr/modules/env.lua`.

## Follow-ups

- `assets/themes/*.png` screenshots show the author's `user@host` in the fastfetch title (seen on
  `harbor.png`): to regenerate on a neutral user.
- `hush fallback` starts the minimal waybar from `~/.config/waybar/minimal-*`, which still
  lives in the dotfiles repo.

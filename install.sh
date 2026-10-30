#!/usr/bin/env bash
# Hush installer: links this checkout into ~/.config and ~/.local/bin. No sudo.
# Idempotent. Never overwrites a real file: anything in the way is moved to
# ~/.cache/hush/backup-<timestamp>/ (and the move is printed).
set -euo pipefail
HUSH_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
BACKUP="$HOME/.cache/hush/backup-$(date +%Y%m%d-%H%M%S)"
SKIP_FONTS=0; SKIP_THEME=0
for a in "$@"; do
  case "$a" in
    --no-fonts) SKIP_FONTS=1 ;;
    --no-theme) SKIP_THEME=1 ;;
    -h|--help) echo "usage: install.sh [--no-fonts] [--no-theme]"; exit 0 ;;
    *) echo "install.sh: unknown option $a" >&2; exit 2 ;;
  esac
done
say() { printf 'hush install: %s\n' "$*"; }

link() { # source target
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    if [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then say "ok      $dst"; return; fi
    say "relink  $dst (was -> $(readlink "$dst"))"
    ln -sfn "$src" "$dst"; return
  fi
  if [[ -e "$dst" ]]; then
    local keep="$BACKUP/${dst#"$HOME"/}"
    mkdir -p "$(dirname "$keep")"
    mv "$dst" "$keep"
    say "backup  $dst -> $keep"
  fi
  ln -sfn "$src" "$dst"
  say "link    $dst -> $src"
}

command -v qs >/dev/null || say "warning: quickshell (qs) not found; the shell will not start"
command -v matugen >/dev/null || say "warning: matugen not found; hush theme will not run"

link "$HUSH_ROOT/quickshell/hush"            "$CFG/quickshell/hush"
link "$HUSH_ROOT/matugen"                    "$CFG/matugen"
link "$HUSH_ROOT/hyprlock"                   "$CFG/hyprlock"
link "$HUSH_ROOT/hyprlock/hyprlock.conf"     "$CFG/hypr/hyprlock.conf"
link "$HUSH_ROOT/hypr/plugins.lua"           "$CFG/hush/plugins.lua"
link "$HUSH_ROOT/integrations/shell/hush.sh"  "$CFG/hush/shell.sh"
for b in hush hush-wallgen hush-fonts hush-gtk; do link "$HUSH_ROOT/bin/$b" "$BIN/$b"; done
if [[ -d "$CFG/nvim/lua/plugins" ]]; then
  link "$HUSH_ROOT/integrations/nvim/hush-theme.lua" "$CFG/nvim/lua/plugins/hush-theme.lua"
else
  say "skip    nvim plugin (no $CFG/nvim/lua/plugins; LazyVim layout expected)"
fi
# Kvantum/hush holds only generated files; hush renders them there.
mkdir -p "$CFG/Kvantum/hush" "$CFG/hush"
# hyprlock sources the generated lock layout; write a single-monitor one now so the lock screen
# works before the first `hush reload` (which regenerates it per connected monitor).
if [[ ! -f "$CFG/hush/hyprlock-layout.conf" ]]; then
  python3 "$HUSH_ROOT/lockscreen/gen.py" hyprlock "$CFG/hush/hyprlock-layout.conf" && say "ok      lock screen layout ($CFG/hush/hyprlock-layout.conf)"
fi

if [[ -d "$HUSH_ROOT/.git" ]]; then
  git -C "$HUSH_ROOT" config core.hooksPath .githooks
  say "ok      git hooks (.githooks)"
fi

if [[ $SKIP_FONTS == 0 ]]; then "$HUSH_ROOT/bin/hush-fonts" || say "warning: hush-fonts failed (continuing)"; fi

if [[ $SKIP_THEME == 0 ]]; then
  if [[ ! -f "$CFG/hush/state.json" ]]; then
    "$HUSH_ROOT/bin/hush" theme harbor || say "warning: hush theme harbor failed"
  else
    say "ok      theme state exists ($("$HUSH_ROOT/bin/hush" status | head -1)); run 'hush reload' to re-render"
  fi
  # Outputs that land in a git repo (e.g. dotfiles behind ~/.config) stay out of commits.
  "$HUSH_ROOT/bin/hush" track off >/dev/null && say "ok      generated files marked skip-worktree where tracked"
fi
[[ -d "$BACKUP" ]] && say "backups are in $BACKUP"
say "optional: hush plugins install  (dynamic-cursors; see README, Plugins)"
say "optional: sudo $HUSH_ROOT/sddm/install.sh  (Hush login screen; run it yourself, install.sh never uses sudo)"
say "done. Start the shell with: hush shell start"

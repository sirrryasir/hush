#!/bin/sh
# Hush bootstrap for any distro:  curl -fsSL https://raw.githubusercontent.com/sirrryasir/hush/main/get.sh | sh
# Clones (or updates) the checkout under ~/.local/share/hush and runs its install.sh. No sudo, no packages:
# Hyprland, Quickshell, matugen and python are yours to install first.
set -eu
dir="${HUSH_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/hush}"
miss=""
for c in git hyprctl qs matugen python3; do command -v "$c" >/dev/null 2>&1 || miss="$miss $c"; done
if [ -n "$miss" ]; then
  echo "hush: install first:$miss (Hyprland 0.56+, quickshell, matugen, python)" >&2
  exit 1
fi
if [ -d "$dir/.git" ]; then git -C "$dir" pull -q --ff-only
else git clone -q https://github.com/sirrryasir/hush.git "$dir"; fi
exec "$dir/install.sh" "$@"

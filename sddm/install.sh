#!/usr/bin/env bash
# Install the Hush SDDM theme. Run once by the maintainer: sudo sddm/install.sh [user]
# Copies the theme to /usr/share/sddm/themes/hush, selects it in /etc/sddm.conf.d/hush.conf and
# links hush/current to the user's ~/.cache/hush/sddm (refreshed by `hush sddm sync`).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo $0 [user]" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
user=${1:-${SUDO_USER:-}}
[[ -n "$user" ]] || { echo "no target user (pass one: sudo $0 <user>)" >&2; exit 1; }
home=$(getent passwd "$user" | cut -d: -f6)
[[ -d "$home" ]] || { echo "no home directory for $user" >&2; exit 1; }
dest=/usr/share/sddm/themes/hush

rm -rf "$dest"
mkdir -p "$dest"
cp -a "$here/hush/." "$dest/"
rm -f "$dest/current"
# The greeter runs as the sddm user and cannot see ~/.local/share/fonts: ship Inter inside the theme.
inter=""
for f in "$home/.local/share/fonts/hush/InterVariable.ttf" "$(fc-match -f '%{file}' 'Inter Variable' 2>/dev/null || true)"; do
  [[ -f "$f" && "$f" == *Inter* ]] && { inter=$f; break; }
done
mkdir -p "$dest/fonts"
if [[ -n "$inter" ]]; then cp "$inter" "$dest/fonts/InterVariable.ttf"; else echo "warning: Inter not found; the theme falls back to the system sans" >&2; fi
ln -sfn "$home/.cache/hush/sddm" "$dest/current"

mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=hush\n' > /etc/sddm.conf.d/hush.conf

echo "installed $dest (current -> $home/.cache/hush/sddm)"
sudo -u "$user" env HOME="$home" "$here/../bin/hush" sddm sync || echo "warning: run 'hush sddm sync' as $user" >&2
if ! sudo -u sddm test -x "$home" 2>/dev/null; then
  echo "note: $home is not traversable by the sddm user; run: chmod o+x $home" >&2
fi

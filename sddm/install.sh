#!/usr/bin/env bash
# Install the Hush SDDM theme, once: sudo sddm/install.sh [user]
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
cp "$here/../lockscreen/Screen.qml" "$dest/Screen.qml"   # the screen the lock uses too; the theme must be self-contained
rm -f "$dest/current"
# The greeter runs as the sddm user and cannot see ~/.local/share/fonts: ship Inter inside the theme.
inter=""
for f in "$home/.local/share/fonts/hush/InterVariable.ttf" "$(fc-match -f '%{file}' 'Inter Variable' 2>/dev/null || true)"; do
  [[ -f "$f" && "$f" == *Inter* ]] && { inter=$f; break; }
done
mkdir -p "$dest/fonts"
if [[ -n "$inter" ]]; then cp "$inter" "$dest/fonts/InterVariable.ttf"; else echo "warning: Inter not found; the theme falls back to the system sans" >&2; fi
icons=""
for f in "$home/.local/share/fonts/hush/MaterialSymbolsRounded.ttf" "$(fc-match -f '%{file}' 'Material Symbols Rounded' 2>/dev/null || true)"; do
  [[ -f "$f" && "$f" == *MaterialSymbols* ]] && { icons=$f; break; }
done
if [[ -n "$icons" ]]; then cp "$icons" "$dest/fonts/MaterialSymbolsRounded.ttf"; else echo "warning: Material Symbols Rounded not found; the buttons fall back to text glyphs" >&2; fi
ln -sfn "$home/.cache/hush/sddm" "$dest/current"

mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=hush\n' > /etc/sddm.conf.d/hush.conf
# /etc/sddm.conf is read after sddm.conf.d and wins: a Current= there would hide the line above.
if [[ -f /etc/sddm.conf ]] && grep -Eq '^\s*Current\s*=' /etc/sddm.conf && ! grep -Eq '^\s*Current\s*=\s*hush\s*$' /etc/sddm.conf; then
  echo "note: /etc/sddm.conf sets $(grep -E '^\s*Current\s*=' /etc/sddm.conf | head -1) and overrides hush.conf; fix: sudo sed -i 's/^\s*Current\s*=.*/Current=hush/' /etc/sddm.conf" >&2
fi
# Leftovers from other themes: a virtual keyboard input method pops an on-screen keyboard over the greeter.
if grep -Eqs '^\s*(InputMethod\s*=\s*\S|GreeterEnvironment\s*=.*(QT_IM_MODULE|QML2_IMPORT_PATH))' /etc/sddm.conf /etc/sddm.conf.d/*.conf; then
  echo "note: an InputMethod or GreeterEnvironment line in /etc/sddm.conf* comes from another theme; remove it or the greeter shows an on-screen keyboard" >&2
fi

echo "installed $dest (current -> $home/.cache/hush/sddm)"
sudo -u "$user" env HOME="$home" "$here/../bin/hush" sddm sync || echo "warning: run 'hush sddm sync' as $user" >&2
if ! sudo -u sddm test -x "$home" 2>/dev/null; then
  echo "note: $home is not traversable by the sddm user; run: chmod o+x $home" >&2
fi

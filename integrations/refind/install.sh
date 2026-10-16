#!/usr/bin/env bash
# Install the Hush rEFInd theme: sudo integrations/refind/install.sh [theme]
# Copies the theme to <ESP>/EFI/refind/themes/hush, renders the banner from the theme's wallpaper
# (default: the current theme, else harbor) and includes it from refind.conf once.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo $0" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
themes=$here/../../themes
name=${1:-}
[[ -n "$name" || -z "${SUDO_USER:-}" ]] || name=$(sudo -u "$SUDO_USER" env HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)" "$here/../../bin/hush" status 2>/dev/null | awk '$1=="theme"{print $2}') || true
name=${name:-harbor}
[[ "$name" =~ ^[a-z0-9-]+$ && -f "$themes/$name/wallpaper.png" ]] || { echo "no theme '$name' in $themes" >&2; exit 1; }
refind=""
for d in /boot/efi/EFI/refind /boot/EFI/refind /efi/EFI/refind; do
  [[ -f "$d/refind.conf" ]] && { refind=$d; break; }
done
[[ -n "$refind" ]] || { echo "no refind.conf under /boot/efi, /boot or /efi; is the ESP mounted?" >&2; exit 1; }
dest=$refind/themes/hush

rm -rf "$dest"
mkdir -p "$dest"
cp -r "$here/theme.conf" "$here/selection_big.png" "$here/selection_small.png" "$here/icons" "$dest/"
cp "$dest/icons/os_win.png" "$dest/icons/os_win8.png"   # rEFInd asks for os_win8 on Windows 8 and later
# Blurred, dimmed and a little desaturated, like the lock background.
magick "$themes/$name/wallpaper.png" -resize 1920x1080^ -gravity center -extent 1920x1080 -blur 0x12 -modulate 55,90 -strip "$dest/banner.png"
echo "installed $dest (banner: $name)"
line='include themes/hush/theme.conf'
if grep -Eq '^\s*include\s+themes/hush/theme\.conf\s*$' "$refind/refind.conf"; then
  echo "refind.conf already includes the theme"
else
  printf '\n%s\n' "$line" >> "$refind/refind.conf"
  echo "added '$line' to $refind/refind.conf"
fi
echo "the next boot shows the Hush boot menu"

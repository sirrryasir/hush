#!/usr/bin/env bash
# Install the Hush rEFInd theme: sudo integrations/refind/install.sh
# Copies the theme to <ESP>/EFI/refind/themes/hush and includes it from refind.conf once.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo $0" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
refind=""
for d in /boot/efi/EFI/refind /boot/EFI/refind /efi/EFI/refind; do
  [[ -f "$d/refind.conf" ]] && { refind=$d; break; }
done
[[ -n "$refind" ]] || { echo "no refind.conf under /boot/efi, /boot or /efi; is the ESP mounted?" >&2; exit 1; }
dest=$refind/themes/hush

rm -rf "$dest"
mkdir -p "$dest"
cp -r "$here/theme.conf" "$here/banner.png" "$here/selection_big.png" "$here/selection_small.png" "$here/icons" "$dest/"
echo "installed $dest"
line='include themes/hush/theme.conf'
if grep -Eq '^\s*include\s+themes/hush/theme\.conf\s*$' "$refind/refind.conf"; then
  echo "refind.conf already includes the theme"
else
  printf '\n%s\n' "$line" >> "$refind/refind.conf"
  echo "added '$line' to $refind/refind.conf"
fi
echo "the next boot shows the Hush boot menu"

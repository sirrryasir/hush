#!/usr/bin/env bash
# The repo is public: no user names, home paths, monitor names or personal folders in the tree.
# Allowed: the author's GitHub handle (sirrryasir) in README.md, CHANGELOG.md and LICENSE credits and links.
cd "$(dirname "$0")/.." || exit 1
pattern='yasir|abdulebaroo|/home/[a-z]+|sirrryasir|HDMI-A-1|eDP-1|Pictures/Wallpapers|layout_yasir'
hits=$(grep -rniIE "$pattern" --exclude-dir=.git --exclude=test_no_personal.sh . | while IFS= read -r line; do
  case "$line" in
    ./README.md:*|./CHANGELOG.md:*|./LICENSE:*)
      # Drop the allowed handle; anything personal left on the line still counts.
      printf '%s\n' "${line#*:*:}" | sed 's/sirrryasir//g' | grep -qiE "$pattern" && printf '%s\n' "$line" ;;
    *) printf '%s\n' "$line" ;;
  esac
done)
names=$(find . -path ./.git -prune -o -print | grep -iE 'yasir|abdulebaroo' || true)
if [[ -z "$hits" && -z "$names" ]]; then echo "PASS no personal data"; exit 0; fi
echo "FAIL: personal data in the tree:"; printf '%s\n' "$hits" "$names" | grep -v '^$' | head -40
exit 1

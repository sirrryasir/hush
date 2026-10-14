#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
fail=0
for t in hover control-center launcher lock; do
  for s in ""; do
    f=assets/screens/$t$s.png
    [ -f "$f" ] || { echo "FAIL: $f missing"; fail=1; continue; }
    [ "$(stat -c %s "$f")" -lt 716800 ] || { echo "FAIL: $f over 700 KB"; fail=1; }
    grep -q "$f" README.md || { echo "FAIL: README does not reference $f"; fail=1; }
  done
done
n=$(grep -c 'hush ' README.md); [ "$n" -ge 8 ] || { echo "FAIL: only $n 'hush ' lines"; fail=1; }
for c in $(sed -n '/^    list) list_themes/,/^    \*) usage/p' bin/hush | awk '/^    [a-z-]+\)/{sub(/\).*/,"");print $1}' | grep -v '^version$\|^help$'); do
  grep -q "hush $c" README.md || { echo "FAIL: README lacks subcommand $c"; fail=1; }
done
grep -q '^### Keyboard' README.md || { echo "FAIL: README lacks Keyboard section"; fail=1; }
[ $fail -eq 0 ] && echo "PASS readme"; exit $fail

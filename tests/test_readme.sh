#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
fail=0
for t in dusk ember fog harbor moss paper; do
  for s in "" -cc; do
    f=assets/themes/$t$s.png
    [ -f "$f" ] || { echo "FAIL: $f missing"; fail=1; continue; }
    [ "$(stat -c %s "$f")" -lt 716800 ] || { echo "FAIL: $f over 700 KB"; fail=1; }
    grep -q "$f" README.md || { echo "FAIL: README does not reference $f"; fail=1; }
  done
done
n=$(grep -c 'hush ' README.md); [ "$n" -ge 8 ] || { echo "FAIL: only $n 'hush ' lines"; fail=1; }
[ $fail -eq 0 ] && echo "PASS readme"; exit $fail

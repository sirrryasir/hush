#!/usr/bin/env bash
cd "$(dirname "$0")"
# Every tests/test_*.sh runs. List a file in SKIP only if it needs hardware that is absent on the
# machine (add a comment saying which); nothing needs skipping on a Hyprland desktop with a GPU.
SKIP=()
pass=0 failn=0 skip=0 rc=0
for t in test_*.sh; do
  if [[ " ${SKIP[*]} " == *" $t "* ]]; then echo "=== $t (SKIP) ==="; skip=$((skip+1)); continue; fi
  echo "=== $t ==="
  if bash "$t"; then pass=$((pass+1)); else failn=$((failn+1)); rc=1; fi
done
echo "$pass PASS $failn FAIL $skip SKIP"
exit $rc

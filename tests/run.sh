#!/usr/bin/env bash
# Runs every tests/test_*.sh; prints PASS/FAIL per file and a total.
cd "$(dirname "$0")/.." || exit 1
export QS_DISABLE_CRASH_HANDLER=1
p=0 f=0
for t in tests/test_*.sh; do
  if bash "$t" >/dev/null 2>&1; then echo "PASS $t"; p=$((p+1)); else echo "FAIL $t"; f=$((f+1)); fi
done
echo "total: $p passed, $f failed"
[[ $f -eq 0 ]]

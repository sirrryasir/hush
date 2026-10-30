#!/usr/bin/env bash
# Hijri.js against known dates (needs node; the library pragma line is stripped for it).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_hijri() {
  command -v node >/dev/null || { fail "node not installed"; return; }
  local out; out=$( { sed 1d quickshell/hush/config/Hijri.js; echo '
for (const [y, m, d] of [[2026, 10, 31], [2026, 2, 18], [2025, 3, 1]]) console.log(format(new Date(y, m - 1, d)))
console.log(format(new Date(2026, 9, 31), false))'; } | node --input-type=module 2>&1)
  assert_eq $'19 Jumada al-Ula 1448\n1 Ramadan 1447\n1 Ramadan 1446\n19 Jumada al-Ula' "$out" "known Gregorian dates convert"
}
run_test "hijri" t_hijri
finish

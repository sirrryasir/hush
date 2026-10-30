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
  out=$( { sed 1d quickshell/hush/config/Hijri.js; echo '
let bad = 0
for (let t = Date.UTC(2020, 0, 1); t < Date.UTC(2032, 0, 1); t += 86400000) {
  const u = new Date(t), d = new Date(u.getUTCFullYear(), u.getUTCMonth(), u.getUTCDate()), h = convert(d)
  if (toDate(h.year, h.month, h.day).getTime() !== d.getTime()) bad++
}
console.log(bad, toDate(1448, 5, 1).toDateString(), monthLength(1448, 5), monthLength(1448, 6))
console.log(span(new Date(2026, 10, 1), new Date(2026, 10, 30)))'; } | node --input-type=module 2>&1)
  assert_eq $'0 Tue Oct 13 2026 30 29\nJumada al-Ula – Jumada al-Akhirah 1448' "$out" "Hijri to Gregorian round-trips 2020-2031, month lengths, spans"
}
run_test "hijri" t_hijri
finish

#!/usr/bin/env bash
# BatteryAlert.js: which threshold to announce, and the time-left text (needs node).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_battery_alert() {
  command -v node >/dev/null || { fail "node not installed"; return; }
  local out; out=$( { sed 1d quickshell/hush/services/BatteryAlert.js; echo '
const A = [20, 10, 5]
console.log([next(A, 50, 101), next(A, 20, 101), next(A, 19, 20), next(A, 10, 20), next(A, 4, 20), next(A, 3, 5), next(A, 8, 101)].join(" "))
console.log([left(0), left(720), left(3900)].join("|"))'; } | node --input-type=module 2>&1)
  assert_eq $'-1 20 -1 10 5 -1 10\n|12 min|1 h 05 min' "$out" "thresholds fire once each, lowest crossed wins; time left"
}
run_test "battery alert" t_battery_alert
finish

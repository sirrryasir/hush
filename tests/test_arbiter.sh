#!/usr/bin/env bash
# Island Arbiter (modules/island/Arbiter.qml) under plain qmltestrunner: no Quickshell, no display.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
runner=$(for r in /usr/lib/qt6/bin/qmltestrunner qmltestrunner6 qmltestrunner-qt6; do command -v "$r" && break; done)  # /usr/bin/qmltestrunner may be Qt 5
t_arbiter() {
  [[ -x "$runner" ]] || { fail "qmltestrunner not found"; return; }
  local out; out=$(QT_QPA_PLATFORM=offscreen "$runner" -input tests/qml/tst_arbiter.qml 2>&1); local rc=$?
  local totals; totals=$(grep -E '^Totals:' <<<"$out")
  if [[ $rc -eq 0 ]]; then pass "tst_arbiter: $totals"; else grep -E 'FAIL|Actual|Expected|Loc:|error' <<<"$out" | head -30; fail "tst_arbiter: ${totals:-rc $rc}"; fi
}
run_test "arbiter" t_arbiter
finish

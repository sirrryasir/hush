#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
F="$HOME/.config/hush/settings.json"; BAK=$(mktemp)
if [[ -f "$F" ]]; then cp "$F" "$BAK"; HAD=1; else HAD=0; fi
restore() { if [[ $HAD == 1 ]]; then cp "$BAK" "$F"; else rm -f "$F"; fi; rm -f "$BAK"; }
trap restore EXIT
t_defaults() {
  rm -f "$F"; shell_restart; sleep 2
  assert_eq "140" "$(shell_ipc settingsGet island.width)" "default width"
  assert_eq '"reserve"' "$(shell_ipc settingsGet island.mode)" "default mode"
  assert_eq "120" "$(shell_ipc settingsGet motion.hoverDwellMs)" "default dwell"
}
t_set() {
  shell_ipc settingsSet island.width 160 >/dev/null; sleep 0.5
  assert_eq "160" "$(shell_ipc settingsGet island.width)" "getter after set"
  assert_eq "160" "$(python3 -c "import json;print(json.load(open('$F'))['island']['width'])")" "file written"
  assert_eq "36" "$(shell_ipc settingsGet island.height)" "other defaults kept"
}
t_hot_reload() {
  echo '{"island":{"width":150}}' > "$F"; sleep 1
  assert_eq "150" "$(shell_ipc settingsGet island.width)" "external edit hot-reloads"
  assert_eq "36" "$(shell_ipc settingsGet island.height)" "defaults merged under user file"
}
t_restore() {
  shell_ipc settingsSet island.width 140 >/dev/null; sleep 0.5
  assert_eq "140" "$(shell_ipc settingsGet island.width)" "restored"
  assert_eq "pong" "$(shell_ipc ping)" "shell alive"
}
t_log() { local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"; }
run_test "defaults" t_defaults; run_test "set" t_set; run_test "hot reload" t_hot_reload; run_test "restore" t_restore; run_test "log" t_log
finish

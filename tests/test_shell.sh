#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
colors_json_primary() { python3 -c "import json;print(json.load(open('$CFG/hush/Colors.json'))['primary'])"; }
t_start() {
  shell_restart && pass "shell restarts" || fail "shell restart failed"
  shell_alive && pass "shell process alive" || fail "shell not running"
  assert_eq "pong" "$(shell_ipc ping)" "ipc ping answers pong"
  (( $(shell_ipc screens) >= 1 )) && pass "shell sees >=1 monitor" || fail "shell sees no monitors"
}
t_colors() {
  local before; before=$(shell_ipc colorsLoaded)
  assert_eq "true" "$before" "Colors loaded from Colors.json"
  bin/hush theme ember >/dev/null; sleep 2
  assert_eq "$(colors_json_primary)" "$(shell_ipc primary)" "shell primary matches Colors.json after ember"
  bin/hush theme harbor >/dev/null; sleep 2
  assert_eq "$(colors_json_primary)" "$(shell_ipc primary)" "shell primary matches Colors.json after harbor (second switch)"
  assert_eq "$(python3 -c "import json;print(json.load(open('$CFG/hush/Colors.json'))['dark']['on_surface'])")" "$(shell_ipc darkOnSurface)" "darkOnSurface follows Colors.json dark block"
}
t_literals() {
  # config/Colors.qml holds the harbor fallback palette; it is the one place hex literals belong.
  local hits; hits=$(grep -rnE '#[0-9a-fA-F]{6}' quickshell/hush --include='*.qml' | grep -v '^quickshell/hush/config/Colors.qml:' | grep -v '"#000000"' || true)
  [[ -z "$hits" ]] && pass "no literal colors in QML" || fail "literal colors: $hits"
}
run_test "start" t_start
run_test "colors" t_colors
run_test "log" shell_log_check
run_test "literals" t_literals
finish

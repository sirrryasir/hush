#!/usr/bin/env bash
# Job done: integrations/shell/hush.sh raises a job card on the island when a command that ran
# HUSH_JOB_SECS or longer ends in a terminal that is no longer focused: tick or cross, the command,
# the duration, the exit code and the terminal; Open focuses that window. The card is driven straight
# with notify-send and the hints, then zsh and bash run the hook against the sandbox's two kitty
# windows. PNGs of a finished and a failed job land in $HUSH_SHOTS (default ../cc-shots).
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"; source "$(dirname "$0")/lib/input.sh"
cd "$(dirname "$0")/.."
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
HOOK="$PWD/integrations/shell/hush.sh"
mapfile -t TERMS < <(hyprctl clients -j | python3 -c "import json,sys; print('\n'.join(c['address'] for c in json.load(sys.stdin) if c['class']=='hush-sandbox-term'))")
A=${TERMS[0]:-}; B=${TERMS[1]:-}
focus() { hyprctl dispatch "hl.dsp.focus({ window = \"address:$1\" })" >/dev/null; sleep 0.4; }
active() { hyprctl activewindow -j | python3 -c "import json,sys; print(json.load(sys.stdin)['address'])"; }
text() { shell_ipc islandControlText "$1"; }
job() { notify-send -a hush -h string:x-hush-kind:job -h "int:x-hush-exit:$1" -h "string:x-hush-window:$2" -- "$3" "$4"; }
# The driven island's pill, cropped out of its monitor.
shot() {
  local x y w h r wh; read -r x y w h r < <(mon_geom "$(shell_ipc islandScreen)"); wh=$(shell_ipc islandSize)
  local top; top=$(shell_ipc settingsGet island.topGap); top=${top:-6}
  grim -g "$((x + (w - ${wh%x*}) / 2)),$((y + top)) $wh" "$SHOTS/$1.png" 2>/dev/null
  assert_file "$SHOTS/$1.png" "saved $SHOTS/$1.png"
}
wait_text() { local i; for i in $(seq 30); do [[ "$(text "$1")" == *"$2"* ]] && return 0; sleep 0.2; done; return 1; }
cleanup() { shell_ipc clearNotifications >/dev/null 2>&1; }
trap cleanup EXIT

t_up() {
  shell_restart; sleep 2
  [[ -n "$A" && -n "$B" ]] && pass "two sandbox terminals ($A, $B)" || fail "need two hush-sandbox-term windows"
  shell_ipc clearNotifications >/dev/null
}
t_card() {
  job 0 "$A" "make -j8" "2 m 14 s"
  shell_wait_state notification && pass "a job notification shows on the island" || fail "state $(shell_state)"
  assert_eq "make -j8" "$(text notifTitle)" "the command is the title"
  assert_eq "finished" "$(text jobVerb)" "exit 0 reads finished"
  assert_eq "check" "$(text notifGlyph)" "tick glyph"
  wait_text notifBody "on workspace" || true
  local ws; ws=$(hyprctl clients -j | python3 -c "import json,sys; print(next(c['workspace']['name'] for c in json.load(sys.stdin) if c['address']=='$A'))")
  assert_eq "2 m 14 s · exit 0 · hush-sandbox-term on workspace $ws" "$(text notifBody)" "duration, exit code, terminal class and workspace"
  assert_eq "true" "$(shell_ipc islandControlVisible jobOpen)" "Open button shown"
  assert_eq "56" "$(qs -c hush ipc call notifs islandHeight)" "job card is 56 tall"
  sleep 0.4; shot job-ok
  shell_ipc clearNotifications >/dev/null; shell_wait_state rest
  job 101 "$A" "cargo build --release" "41 s"
  shell_wait_state notification && pass "failed job shows" || fail "state $(shell_state)"
  assert_eq "failed" "$(text jobVerb)" "exit 101 reads failed"
  assert_eq "close" "$(text notifGlyph)" "cross glyph"
  wait_text notifBody "exit 101" && pass "body carries exit 101" || fail "body: $(text notifBody)"
  sleep 0.4; shot job-fail
  shell_ipc clearNotifications >/dev/null; shell_wait_state rest
  job 0 "" "sleep 30" "30 s"; shell_wait_state notification
  assert_eq "false" "$(shell_ipc islandControlVisible jobOpen)" "no Open without a window address"
  shell_ipc clearNotifications >/dev/null; shell_wait_state rest
}
# Open focuses the terminal the shell named, through the Hyprland dispatcher, and lowers the card.
t_open() {
  input_start || { pass "$(input_why): Open click skipped"; return; }
  focus "$B"; assert_eq "$B" "$(active)" "the other terminal is focused first"
  job 0 "$A" "make -j8" "2 m 14 s"; shell_wait_state notification
  local x y w h r c; read -r x y w h r < <(mon_geom "$(shell_ipc islandScreen)"); c=$(shell_ipc islandControl jobOpen)
  input_move "$((x + ${c% *}))" "$((y + ${c#* }))"; sleep 0.2; input_click; sleep 0.6
  assert_eq "$A" "$(active)" "Open focused the job's terminal"
  shell_wait_state rest && pass "the card lowered" || fail "state $(shell_state)"
  input_move "$((x + w / 2))" "$((y + h / 2))"; input_stop
}
# The hook in each shell: the first command records the terminal; the card comes only once the
# command ran HUSH_JOB_SECS and the terminal lost focus.
run_hook() { # shell command...
  local sh=$1; shift
  focus "$A"
  printf 'source %q\n%s\nexit\n' "$HOOK" "$*" | HUSH_JOB_SECS=1 $sh -i >/dev/null 2>&1 &
  sleep 0.8; focus "$B"; wait $!
}
t_zsh() {
  command -v zsh >/dev/null || { pass "no zsh: skipped"; return; }
  run_hook "zsh -f" "sleep 2"
  shell_wait_state notification 60 && pass "zsh: the card shows after the command" || fail "zsh: state $(shell_state)"
  assert_eq "sleep 2" "$(text notifTitle)" "zsh: the command line is the title"
  assert_eq "finished" "$(text jobVerb)" "zsh: finished"
  wait_text notifBody "2 s · exit 0 · hush-sandbox-term" && pass "zsh: duration, exit and terminal" || fail "zsh body: $(text notifBody)"
  shell_ipc clearNotifications >/dev/null; shell_wait_state rest
}
t_bash() {
  run_hook "bash --norc" "sleep 2; false"
  shell_wait_state notification 60 && pass "bash: the card shows after the command" || fail "bash: state $(shell_state)"
  assert_eq "sleep 2; false" "$(text notifTitle)" "bash: the command line is the title"
  assert_eq "failed" "$(text jobVerb)" "bash: a non-zero exit reads failed"
  wait_text notifBody "exit 1 · hush-sandbox-term" && pass "bash: exit code and terminal" || fail "bash body: $(text notifBody)"
  shell_ipc clearNotifications >/dev/null; shell_wait_state rest
  # Focused terminal: nothing. Short command: nothing.
  focus "$A"; printf 'source %q\nsleep 2\ntrue\nexit\n' "$HOOK" | HUSH_JOB_SECS=1 bash --norc -i >/dev/null 2>&1
  sleep 1; assert_eq "rest" "$(shell_state)" "no card while the terminal stays focused, none for a short command"
}
run_test up t_up; run_test card t_card; run_test open t_open; run_test zsh t_zsh; run_test bash t_bash
run_test log shell_log_check
finish

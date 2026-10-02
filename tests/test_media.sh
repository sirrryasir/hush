#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
WAV=/tmp/hush-silence.wav
play_start() {
  if command -v mpv >/dev/null; then mpv --no-video --really-quiet --audio-device=null "$WAV" >/dev/null 2>&1 &
  else cvlc --intf dummy --no-video --aout dummy "$WAV" >/dev/null 2>&1 & fi
  PLAYER_PID=$!
}
play_stop() { kill "$PLAYER_PID" 2>/dev/null; pkill -x mpv 2>/dev/null; pkill -x vlc 2>/dev/null; true; }
t_media() {
  if ! command -v ffmpeg >/dev/null || ! { command -v mpv >/dev/null || command -v cvlc >/dev/null; }; then
    echo "SKIPPED: need ffmpeg and mpv (or vlc)"; return 0
  fi
  [[ -f $WAV ]] || ffmpeg -loglevel quiet -f lavfi -i anullsrc -t 20 "$WAV"
  shell_restart; sleep 3
  assert_eq "rest" "$(shell_ipc islandState)" "starts at rest"
  local narrow; narrow=$(shell_ipc restWidth)
  play_start; local i; for i in $(seq 40); do [[ "$(shell_ipc islandState)" == media ]] && break; sleep 0.05; done
  assert_eq "media" "$(shell_ipc islandState)" "a new track shows the 1.1 s now-playing card"
  sleep 2.5
  assert_eq "rest" "$(shell_ipc islandState)" "then media sits at rest as the activity circle (no capsule)"
  [[ "$(shell_ipc restWidth)" -gt "$narrow" ]] && pass "rest pill widens for the circle ($narrow -> $(shell_ipc restWidth))" || fail "rest width $(shell_ipc restWidth)"
  [[ -n "${HUSH_SHOT:-}" ]] && shell_screenshot "$HUSH_SHOT"
  play_stop; sleep 2
  assert_eq "rest" "$(shell_ipc islandState)" "stopping stays at rest"
  assert_eq "$narrow" "$(shell_ipc restWidth)" "and the circle goes"
  local e; e=$(shell_log_errors); [[ -z "$e" ]] && pass "no errors in shell log" || fail "shell log errors: $e"
}
run_test "media" t_media
finish

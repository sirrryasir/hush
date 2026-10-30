#!/usr/bin/env bash
# Pointer and keyboard input for the tests: a private ydotoold (uinput) per test. Source it after lib.sh.
#   input_start             get ready; fails (the caller skips its checks) when input is unavailable
#   input_stop              tear down (call it from the test's cleanup)
#   input_click [button]    left (default), right or middle
#   input_key name...       Tab Escape Return space Up Down Left Right, optionally shift+<name>
_INPUT_YPID=""; _INPUT_SOCK=""
input_why() { echo "no writable uinput/ydotoold"; }
input_start() {
  [[ -w /dev/uinput ]] && command -v ydotoold >/dev/null || return 1
  _INPUT_SOCK="${XDG_RUNTIME_DIR:-/tmp}/hush-test-ydotool-$$.sock"; rm -f "$_INPUT_SOCK"
  ydotoold -p "$_INPUT_SOCK" >/dev/null 2>&1 & _INPUT_YPID=$!
  sleep 1.5 # the uinput device needs a moment before libinput sees it
}
input_stop() {
  [[ -n "$_INPUT_YPID" ]] && kill "$_INPUT_YPID" 2>/dev/null
  [[ -n "$_INPUT_SOCK" ]] && rm -f "$_INPUT_SOCK"
  _INPUT_YPID=""; _INPUT_SOCK=""
}
_yd() { YDOTOOL_SOCKET="$_INPUT_SOCK" ydotool "$@" >/dev/null 2>&1; }
input_click() {
  local b=${1:-left}
  case $b in right) _yd click 0xC1 ;; middle) _yd click 0xC2 ;; *) _yd click 0xC0 ;; esac
}
_input_code() { # key name -> evdev code
  case $1 in
    Tab) echo 15 ;; Escape) echo 1 ;; Return) echo 28 ;; space) echo 57 ;; shift) echo 42 ;;
    Up) echo 103 ;; Down) echo 108 ;; Left) echo 105 ;; Right) echo 106 ;; *) return 1 ;;
  esac
}
input_key() {
  local k mod name c m
  for k in "$@"; do
    mod=""; name=$k; [[ $k == *+* ]] && { mod=${k%%+*}; name=${k#*+}; }
    c=$(_input_code "$name") || return 1
    if [[ -n $mod ]]; then m=$(_input_code "$mod") || return 1; _yd key "$m:1" "$c:1" "$c:0" "$m:0"
    else _yd key "$c:1" "$c:0"; fi
  done
}

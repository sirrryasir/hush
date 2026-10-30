#!/usr/bin/env bash
# Pointer and keyboard input for the tests. Source it after lib.sh.
# Live desktop: a private ydotoold (uinput) per test, as the tests always did.
# Sandbox (HUSH_SANDBOX=1, tests/sandbox.sh): wtype (virtual-keyboard) and tests/lib/vpointer
# (wlr virtual-pointer) on the compositor in WAYLAND_DISPLAY. uinput is a kernel device: its events
# reach the real compositor, never the nested one, so the sandbox must not use it.
#   input_start             get ready; fails (the caller skips its checks) when input is unavailable
#   input_stop              tear down (call it from the test's cleanup)
#   input_move x y          warp the pointer (global layout px; hl.dsp.cursor.move in both modes)
#   input_click [button]    left (default), right or middle
#   input_key name...       Tab Escape Return space Up Down Left Right, optionally shift+<name>
#   input_type text         type a string
#   input_wheel steps       vertical wheel, positive = down
_INPUT_YPID=""; _INPUT_SOCK=""
_INPUT_VP="${XDG_CACHE_HOME:-$HOME/.cache}/hush/vpointer"
input_sandbox() { [[ "${HUSH_SANDBOX:-0}" == 1 ]]; }
input_why() { # why input_start failed, for the skip message
  if input_sandbox; then echo "no wtype or vpointer (needs gcc, wayland-scanner, wayland-client)"; else echo "no writable uinput/ydotoold"; fi
}
_input_vpointer() { # build tests/lib/vpointer.c once (rebuilt when the source is newer)
  local src="$HUSH_ROOT/tests/lib/vpointer.c" xml="$HUSH_ROOT/tests/lib/wlr-virtual-pointer-unstable-v1.xml" b
  [[ -x "$_INPUT_VP" && "$_INPUT_VP" -nt "$src" ]] && return 0
  command -v wayland-scanner >/dev/null && command -v cc >/dev/null || return 1
  b=$(mktemp -d) || return 1
  wayland-scanner client-header "$xml" "$b/wlr-virtual-pointer-unstable-v1-client-protocol.h" \
    && wayland-scanner private-code "$xml" "$b/proto.c" \
    && mkdir -p "$(dirname "$_INPUT_VP")" \
    && cc -O2 -I"$b" -o "$_INPUT_VP" "$src" "$b/proto.c" $(pkg-config --cflags --libs wayland-client 2>/dev/null || echo -lwayland-client)
  local rc=$?; rm -rf "$b"; return $rc
}
input_start() {
  if input_sandbox; then
    command -v wtype >/dev/null && _input_vpointer
    return
  fi
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
input_move() { hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })" >/dev/null; }
input_click() {
  local b=${1:-left}
  if input_sandbox; then "$_INPUT_VP" click "$b"; return; fi
  case $b in right) _yd click 0xC1 ;; middle) _yd click 0xC2 ;; *) _yd click 0xC0 ;; esac
}
_input_code() { # key name -> evdev code
  case $1 in
    Tab) echo 15 ;; Escape) echo 1 ;; Return) echo 28 ;; space) echo 57 ;; shift) echo 42 ;;
    Up) echo 103 ;; Down) echo 108 ;; Left) echo 105 ;; Right) echo 106 ;; *) return 1 ;;
  esac
}
input_key() {
  local k mod name
  for k in "$@"; do
    mod=""; name=$k; [[ $k == *+* ]] && { mod=${k%%+*}; name=${k#*+}; }
    if input_sandbox; then
      if [[ -n $mod ]]; then wtype -M "$mod" -k "$name" -m "$mod"; else wtype -k "$name"; fi
    else
      local c m; c=$(_input_code "$name") || return 1
      if [[ -n $mod ]]; then m=$(_input_code "$mod") || return 1; _yd key "$m:1" "$c:1" "$c:0" "$m:0"
      else _yd key "$c:1" "$c:0"; fi
    fi
  done
}
input_type() { if input_sandbox; then wtype "$1"; else _yd type "$1"; fi; }
input_wheel() {
  if input_sandbox; then "$_INPUT_VP" wheel "$1"; return; fi
  _yd mousemove -w -x 0 -y "$1"
}

#!/usr/bin/env bash
# Nested Hyprland for lock/login screenshots. Source it, then:
#   nested_start <scratch> "NAME:WxH" ...   start a nested Hyprland (a window on the live session)
#                                         with one headless output per argument; exports NEST_ENV
#   nest <cmd...>                          run a command inside the nested session
#   nested_stop                            kill it
# The live session is never touched: commands run with the nested WAYLAND_DISPLAY and instance.
nested_start() {
  local dir="$1"; shift
  mkdir -p "$dir"/{cfg,data,state,cache}
  local lua="$dir/nested.lua" spec name mode x=0
  : > "$lua"
  for spec in "$@"; do
    name=${spec%%:*}; mode=${spec#*:}
    printf 'hl.monitor({ output = "%s", mode = "%s@60", position = "%dx0", scale = 1 })\n' "$name" "$mode" "$x" >> "$lua"
    x=$((x + ${mode%x*} + 100))
  done
  cat >> "$lua" <<'LUA'
hl.monitor({ output = "WAYLAND-1", mode = "1280x720", position = "-2000x0", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, allow_session_lock_restore = true },
            animations = { enabled = false }, cursor = { invisible = true }, debug = { disable_logs = true } })
LUA
  local host_wl="${NEST_HOST_WAYLAND:-${WAYLAND_DISPLAY:-wayland-1}}"
  # setsid: the nested compositor must not die with the caller's process group mid-test
  env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$host_wl" XDG_CONFIG_HOME="$dir/cfg" XDG_DATA_HOME="$dir/data" \
    XDG_STATE_HOME="$dir/state" XDG_CACHE_HOME="$dir/cache" setsid dbus-run-session -- Hyprland -c "$lua" >"$dir/hyprland.log" 2>&1 &
  NEST_PID=$!
  # find our instance by its environment (XDG_CONFIG_HOME=$dir/cfg): other nested sessions may be
  # starting at the same time, so "the newest instance" is not reliable
  local i sig="" wl=""
  for ((i = 0; i < 100; i++)); do
    read -r sig wl < <(hyprctl -j instances 2>/dev/null | python3 -c "
import json, sys
for i in json.load(sys.stdin):
    try: env = open('/proc/%d/environ' % i['pid'], 'rb').read().split(b'\\0')
    except OSError: continue
    if b'XDG_CONFIG_HOME=$dir/cfg' in env: print(i['instance'], i['wl_socket']); break" 2>/dev/null)
    [[ -n "$sig" && -n "$wl" && -S "$XDG_RUNTIME_DIR/hypr/$sig/.socket.sock" ]] && break
    sig=""; sleep 0.1
  done
  [[ -n "$sig" ]] || { echo "nested Hyprland did not start (see $dir/hyprland.log)" >&2; return 1; }
  NEST_SIG=$sig
  NEST_WL=$wl
  for spec in "$@"; do nest hyprctl output create headless "${spec%%:*}" >/dev/null; done
  sleep 1
}
nest() { env HYPRLAND_INSTANCE_SIGNATURE="$NEST_SIG" WAYLAND_DISPLAY="$NEST_WL" "$@"; }
nested_stop() {
  [[ -n "${NEST_SIG:-}" ]] && nest hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
  sleep 0.5
  [[ -n "${NEST_PID:-}" ]] && kill "$NEST_PID" 2>/dev/null
  NEST_SIG=""; NEST_PID=""
}

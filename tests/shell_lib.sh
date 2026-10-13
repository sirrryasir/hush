#!/usr/bin/env bash
# Helpers for live tests of the Hush Quickshell shell. Source after lib.sh.
# The process pattern is anchored so it never matches a shell whose command line merely mentions qs.
HUSH_LOG="$HOME/.cache/hush/shell.log"
HUSH_PROC='^qs -c hush$'
shell_restart() { "$HUSH_ROOT/bin/hush" shell restart >/dev/null; }
shell_alive() { session_pgrep -f "$HUSH_PROC" >/dev/null; }
shell_has_layer() { hyprctl layers -j | grep -q "\"namespace\": \"$1\""; }
shell_ipc() { qs -c hush ipc call hush "$@"; }
# Keep the user's settings.json (in $F) across a test that writes it: save first, restore in cleanup.
shell_settings_save() { F="$HOME/.config/hush/settings.json"; BAK=$(mktemp); if [[ -f "$F" ]]; then cp "$F" "$BAK"; HAD=1; else HAD=0; fi; }
shell_settings_restore() { if [[ $HAD == 1 ]]; then cp "$BAK" "$F"; else rm -f "$F"; fi; rm -f "$BAK"; }
shell_state() { shell_ipc islandState; }
shell_wait_state() { # state [polls, 50 ms apart; default 40]
  local i; for i in $(seq "${2:-40}"); do [[ "$(shell_state)" == "$1" ]] && return 0; sleep 0.05; done; return 1
}
shell_wait_ipc() { # ipc-call...: until it answers something other than empty or 0
  local i v; for i in $(seq 40); do v=$(shell_ipc "$@"); [[ -n "$v" && "$v" != 0 ]] && return 0; sleep 0.05; done; return 1
}
# Monitor names, the focused one, and "x y logical-w logical-h top-reserve" of one by name.
mon_names() { hyprctl monitors -j | python3 -c "import json,sys;print(' '.join(m['name'] for m in json.load(sys.stdin)))"; }
mon_focused() { hyprctl monitors -j | python3 -c "import json,sys;print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))"; }
mon_geom() { hyprctl monitors -j | python3 -c "
import json,sys
m=next(m for m in json.load(sys.stdin) if m['name']=='$1')
print(m['x'], m['y'], round(m['width']/m['scale']), round(m['height']/m['scale']), m['reserved'][1])"; }
# Prints log lines since the last restart that look like problems; returns 1 if it printed any.
# Quickshell tags warnings with an upper-case WARN, matched case-sensitively. Qt 6.12's text-input-v3
# bookkeeping warns when a layer surface it never saw activated loses a text field (Qt-internal
# noise, see test_modes keyboard); it is not a shell error.
shell_log_errors() {
  local marker hits; marker=$(cat "$HOME/.cache/hush/shell.restart-marker" 2>/dev/null || echo 0)
  hits=$(tail -n +"$((marker + 1))" "${1:-$HUSH_LOG}" 2>/dev/null \
    | grep -E -e 'WARN' -e '[Ee][Rr][Rr][Oo][Rr]|[Ww][Aa][Rr][Nn][Ii][Nn][Gg]|TypeError|ReferenceError' \
    | grep -v 'QML Connections: Implicitly' \
    | grep -v 'qt.qpa.wayland.textinput.*Trying to \(dis\|en\)able' || true)
  [[ -z "$hits" ]] && return 0
  printf '%s\n' "$hits"; return 1
}
shell_log_check() { local e; if e=$(shell_log_errors); then pass "no errors in shell log"; else fail "shell log errors: $e"; fi; }
# The sandbox points HUSH_EVIDENCE_DIR elsewhere so its headless captures stay out of the real cache.
shell_screenshot() {
  local d="${HUSH_EVIDENCE_DIR:-$HOME/.cache/hush/evidence}"
  hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null; sleep 1; mkdir -p "$d"; grim "$d/$1.png"
}
# ms from the last "$1" mark to the first "$2" mark after it in the island history (-1 if absent).
history_gap() { shell_ipc islandHistory | python3 -c "
import json,sys
h=json.load(sys.stdin); a=None
for i,(n,t) in enumerate(h):
  if n=='$1': a=(i,t)
b=next((t for n,t in h[a[0]+1:] if n=='$2'), None) if a else None
print(-1 if b is None else b-a[1])"; }
# Idle CPU % of the shell over 10 s from /proc (utime+stime delta / wall time; no bc needed).
# Other work may restart the shell mid-sample, so retry up to six times when the pid vanishes.
shell_cpu_idle() {
  local pid out
  for _ in 1 2 3 4 5 6; do
    pid=$(session_pgrep -f "$HUSH_PROC" | head -1)
    out=$(python3 -c "
import os,time
def t(): f=open('/proc/$pid/stat').read().rsplit(')',1)[1].split(); return int(f[11])+int(f[12])
hz=os.sysconf('SC_CLK_TCK'); a=t(); time.sleep(10); b=t()
print('%.2f' % ((b-a)/hz/10*100))" 2>/dev/null) && { echo "$out"; return; }
  done
  echo "nan"
}

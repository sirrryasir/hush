#!/usr/bin/env bash
# Helpers for live tests of the Hush Quickshell shell. Source after lib.sh.
# The process pattern is anchored so it never matches a shell whose command line merely mentions qs.
HUSH_LOG="$HOME/.cache/hush/shell.log"
HUSH_PROC='^qs -c hush$'
shell_restart() { "$HUSH_ROOT/bin/hush" shell restart >/dev/null; }
shell_alive() { session_pgrep -f "$HUSH_PROC" >/dev/null; }
shell_has_layer() { hyprctl layers -j | grep -q "\"namespace\": \"$1\""; }
shell_ipc() { qs -c hush ipc call hush "$@"; }
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
# The sandbox (tests/sandbox.sh) points HUSH_EVIDENCE_DIR at its own directory: its headless outputs
# are not the desktop the evidence images document.
shell_screenshot() {
  local d="${HUSH_EVIDENCE_DIR:-$HOME/.cache/hush/evidence}"
  hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null; sleep 1; mkdir -p "$d"; grim "$d/$1.png"
}
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

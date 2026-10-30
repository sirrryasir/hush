#!/usr/bin/env bash
# Minimal test helpers for Hush. Source this file; call run_test for each test function.
HUSH_ROOT="${HUSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}" # where the live config (and the matugen outputs) live
export HUSH_ROOT CFG
# pgrep/pkill limited to this session (processes with our XDG_RUNTIME_DIR), as in bin/hush: a bare pkill -x mpv or
# pgrep -f '^qs -c hush$' would reach another session's processes.
session_pgrep() { # pgrep-args...; prints the pids, fails when there are none
  local p out=""
  for p in $(pgrep "$@"); do
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]] || tr '\0' '\n' </proc/"$p"/environ 2>/dev/null | grep -qxF "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"; then
      out+="$p"$'\n'
    fi
  done
  [[ -n "$out" ]] && printf '%s' "$out"
}
session_pkill() { # [-SIGNAL] pgrep-args...
  local sig=-TERM pids; [[ "$1" == -[A-Z0-9]* ]] && { sig=$1; shift; }
  pids=$(session_pgrep "$@") && kill "$sig" $pids 2>/dev/null
}
_HUSH_TEST_FAILS=0
_HUSH_TEST_COUNT=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; _HUSH_TEST_FAILS=$((_HUSH_TEST_FAILS+1)); }
assert_eq() { # expected actual message
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$1', got '$2')"; fi
}
assert_file() { # path message
  if [[ -s "$1" ]]; then pass "$2"; else fail "$2 (missing or empty: $1)"; fi
}
assert_contains() { # haystack_file needle message
  if grep -qF -- "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3 (no '$2' in $1)"; fi
}
assert_exit() { # expected_code message command...
  local want=$1; shift; local msg=$1; shift
  "$@" >/dev/null 2>&1; local got=$?
  if [[ $got -eq $want ]]; then pass "$msg"; else fail "$msg (exit $got, wanted $want)"; fi
}
run_test() { # name function
  _HUSH_TEST_COUNT=$((_HUSH_TEST_COUNT+1))
  printf '\033[1m%s\033[0m\n' "$1"; "$2"
}
finish() {
  printf '\n%d test group(s), %d failure(s)\n' "$_HUSH_TEST_COUNT" "$_HUSH_TEST_FAILS"
  [[ $_HUSH_TEST_FAILS -eq 0 ]]
}

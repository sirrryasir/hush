#!/usr/bin/env bash
# Launcher surface in its own scratch Quickshell window (never touches the live shell). A stub cliphist
# on PATH stands in for the clipboard history (a text db, one "id<TAB>preview" line per entry).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export QS_DISABLE_CRASH_HANDLER=1
H="tests/harness/launcher.qml"
hq() { qs -p "$H" ipc call harness-launcher "$@" 2>/dev/null; }
STUB=$(mktemp -d); HLOG=$(mktemp); PID=""
PNG='iVBORw0KGgoAAAANSUhEUgAAABAAAAAKAQMAAACHcEzfAAAAA1BMVEXgbHXnv0xiAAAAC0lEQVQI12NgwAcAAB4AAW6FRzIAAAAASUVORK5CYII='
# Entry 3 is an image, entry 2 is UTF-16-ish text (NULs between letters), entry 1 has runs of blanks.
printf '3\t[[ binary data 1 KiB png 16x10 ]]\n2\tb\0l\0o\0b\0:\0x\n1\t  hello \t\t  world  \n' >"$STUB/db"
cat >"$STUB/cliphist" <<EOF
#!/bin/sh
echo "\$*" >>"$STUB/log"
case "\$1" in
  list) cat "$STUB/db" ;;
  decode) [ "\$2" = 3 ] && echo "$PNG" | base64 -d ;;
  delete) line=\$(cat); id=\${line%%	*}; echo "delete \$id" >>"$STUB/log"; grep -av "^\$id	" "$STUB/db" >"$STUB/db.new"; mv "$STUB/db.new" "$STUB/db" ;;
esac
EOF
chmod +x "$STUB/cliphist"
cleanup() { [[ -n "$PID" ]] && kill "$PID" 2>/dev/null; rm -rf "$STUB" "$HLOG"; }
trap cleanup EXIT
start() { # mode
  [[ -n "$PID" ]] && { kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; }
  PATH="$STUB:$PATH" HUSH_LAUNCHER_MODE="$1" qs -p "$H" >>"$HLOG" 2>&1 & PID=$!
  local i; for i in $(seq 30); do sleep 0.2; [[ -n "$(hq size)" ]] && return 0; done; return 1
}
wait_count() { local i n; for i in $(seq 30); do n=$(hq count); [[ "$n" == "$1" ]] && break; sleep 0.1; done; echo "$n"; }

t_launcher() {
  start apps && pass "harness starts" || { fail "harness did not start"; return; }
  hyprctl layers -j | grep -q '"namespace": "hush-harness-launcher"' && pass "layer hush-harness-launcher present" || fail "layer missing"
  assert_eq "520x300" "$(hq size)" "declared size 520x300"
  assert_eq "true" "$(hq wantsKeyboard)" "wantsKeyboard"
  hq setQuery kitty >/dev/null; sleep 0.5
  hq first | grep -qi kitty && pass "kitty query: first result is $(hq first)" || fail "first result: $(hq first)"
  local d; d=$(hq rowDesc 0); [[ -n "$d" && "$d" != *"No running"* ]] && pass "app row carries a description ($d)" || fail "app row has no description"
  hq setQuery "=2*21" >/dev/null; sleep 1
  assert_eq "calc" "$(hq mode)" "= switches to calc mode"
  assert_eq "42" "$(hq first)" "=2*21 gives 42"
  hq setQuery ";" >/dev/null
  assert_eq "3" "$(wait_count 3)" "; lists the three stub entries"
  assert_eq "clip" "$(hq mode)" "; switches to clip mode"
  hq setQuery ";WOR" >/dev/null; sleep 0.3
  assert_eq "hello world" "$(hq first)" "; filter is case-insensitive"
}
# Opened straight in clip mode (Super+V) the list must load.
t_clip_open() {
  start clip && pass "harness starts in clip mode" || { fail "harness did not start"; return; }
  assert_eq "3" "$(wait_count 3)" "clip mode lists every entry on the first open"
  assert_eq "clip" "$(hq mode)" "mode is clip"
  printf '4\tnew entry\n' | cat - "$STUB/db" >"$STUB/db.new" && mv "$STUB/db.new" "$STUB/db"
  hq reopen clip >/dev/null
  assert_eq "4" "$(wait_count 4)" "a reopen reads the history again (new entry shows)"
  assert_eq "new entry" "$(hq first)" "newest entry first"
  local n; n=$(grep -c '^list' "$STUB/log"); (( n >= 2 )) && pass "cliphist list ran on each open ($n)" || fail "cliphist list ran $n time(s)"
}
t_clip_rows() {
  sleep 0.5
  assert_eq "Image" "$(hq rowName 1)" "image entry is named Image"
  assert_eq "image" "$(hq rowGlyph 1)" "image entry has the image glyph"
  local i; for i in $(seq 30); do [[ "$(hq rowThumbReady 1)" == true ]] && break; sleep 0.1; done
  assert_eq "true" "$(hq rowThumbReady 1)" "image entry shows a decoded thumbnail"
  grep -q '^decode 3' "$STUB/log" && pass "thumbnail came from cliphist decode 3" || fail "no decode call: $(cat "$STUB/log")"
  assert_eq "blob:x" "$(hq rowName 2)" "NULs stripped from text"
  assert_eq "hello world" "$(hq rowName 3)" "whitespace collapsed to one line"
  assert_eq "content_paste" "$(hq rowGlyph 3)" "text entries use the clipboard glyph"
  local dir; dir=$(hq thumbDir | tr -d '"')
  [[ -s "$dir/3" ]] && pass "thumbnail cached in $dir" || fail "no cached thumbnail in $dir"
  hq select 2 >/dev/null; assert_eq "blob:x" "$(hq current)" "selected the NUL entry"
  assert_eq "true" "$(hq deleteCurrent)" "Delete removes the selected entry"
  assert_eq "3" "$(wait_count 3)" "list shrinks by one"
  grep -q '^delete 2$' "$STUB/log" && pass "cliphist delete got entry 2" || fail "delete log: $(grep delete "$STUB/log")"
  sleep 0.6; assert_eq "3" "$(hq count)" "history re-read after the delete still has 3"
  hq reopen apps >/dev/null; sleep 0.6
  [[ ! -e "$dir" ]] && pass "thumbnail cache removed on close" || fail "cache dir left behind: $dir"
  : >"$STUB/db"; hq reopen clip >/dev/null; sleep 0.8
  assert_eq "Clipboard is empty" "$(hq emptyText)" "an empty history says so"
  local e; e=$(grep -iE "error|binding loop|TypeError|ReferenceError" "$HLOG" | head -3)
  [[ -z "$e" ]] && pass "no errors in harness log" || fail "harness log errors: $e"
}
run_test "launcher surface" t_launcher
run_test "clip opens in clip mode" t_clip_open
run_test "clip rows" t_clip_rows
finish

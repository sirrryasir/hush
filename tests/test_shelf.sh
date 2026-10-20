#!/usr/bin/env bash
# Shelf: files kept by path show as a glyph on the rest pill and as chips (name, folder, time left) in the
# strip the glyph opens; removing one updates both, removing the last closes the strip, a 25 h old entry
# never shows. The drop capsule is raised through IPC; a real drag needs a drag source and is not driven.
source "$(dirname "$0")/lib.sh"; source "$(dirname "$0")/shell_lib.sh"
cd "$(dirname "$0")/.."
sh() { qs -c hush ipc call shelf "$@"; }
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
shot() { hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null; sleep 1; grim -g "660,0 600x80" "$SHOTS/$1.png"; assert_file "$SHOTS/$1.png" "saved $1.png"; }
t_shelf() {
  shell_restart; sleep 2
  assert_eq "0" "$(sh count)" "shelf starts empty"
  assert_eq "false" "$(shell_ipc islandControlVisible shelfGlyph)" "no glyph on the rest pill when empty"
  sh add /tmp/hs-docs/quarterly-report.pdf >/dev/null; sh add /tmp/hs-pics/IMG_4821.jpg >/dev/null
  sh addAged /tmp/hs-old/ancient.txt 25 >/dev/null; sleep 0.5
  assert_eq "2" "$(sh count)" "two paths kept, the 25 h old one is not"
  assert_eq "true" "$(shell_ipc islandControlVisible shelfGlyph)" "shelf glyph on the rest pill"
  shell_ipc openSurface shelf >/dev/null; shell_wait_state shelf && pass "strip opens" || fail "state is $(shell_state)"
  sleep 1
  assert_eq $'quarterly-report.pdf | hs-docs · 24 h left\nIMG_4821.jpg | hs-pics · 24 h left' "$(sh rows)" "chips show name, folder and time left"
  assert_eq "520x56" "$(shell_ipc islandSize)" "strip is 520x56"
  shot shelf-row
  sh remove /tmp/hs-docs/quarterly-report.pdf >/dev/null; sleep 0.5
  assert_eq "IMG_4821.jpg | hs-pics · 24 h left" "$(sh rows)" "removed chip is gone"
  sh remove /tmp/hs-pics/IMG_4821.jpg >/dev/null
  shell_wait_state rest && pass "strip closes when the shelf empties" || fail "state is $(shell_state)"
  assert_eq "false" "$(shell_ipc islandControlVisible shelfGlyph)" "glyph gone with the last file"
}
t_drop() {
  sh drag true >/dev/null; shell_wait_state shelfDrop && pass "a file over the pill morphs it to the drop capsule" || fail "state is $(shell_state)"
  sleep 1; assert_eq "320x44" "$(shell_ipc islandSize)" "drop capsule is 320x44"
  shot shelf-drop
  sh drag false >/dev/null; shell_wait_state rest && pass "leaving the pill restores it" || fail "state is $(shell_state)"
}
t_log() { shell_log_check; }
run_test shelf t_shelf; run_test drop t_drop; run_test log t_log
finish

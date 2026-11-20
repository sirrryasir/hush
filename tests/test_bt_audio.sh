#!/usr/bin/env bash
# BtAudio.js: a headset counts as connected while PipeWire has its bluez node (needs node).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_bt_audio() {
  command -v node >/dev/null || { fail "node not installed"; return; }
  local out; out=$( { sed 1d quickshell/hush/services/BtAudio.js; echo '
console.log(["bluez_output.F9_EB_29_D1_0D_19.1", "bluez_input.F9:EB:29:D1:0D:19", "bluez_output.aa_bb_cc_dd_ee_ff",
  "bluez_capture_internal.F9:EB:29:D1:0D:19", "bluez_midi.server", "alsa_output.pci-0000_00_1f.3", "", undefined].map(addr).join("|"))'; } | node --input-type=module 2>&1)
  assert_eq "F9:EB:29:D1:0D:19|F9:EB:29:D1:0D:19|AA:BB:CC:DD:EE:FF|||||" "$out" "sink and source names give the address; other nodes give none"
}
run_test "bt audio" t_bt_audio
finish

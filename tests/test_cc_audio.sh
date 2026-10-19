#!/usr/bin/env bash
# Sound page of the control center in the cc harness (tests/harness/cc.qml): a second null sink and a
# silent pw-cat stream on the sandbox PipeWire. Saves PNGs of each surface to $HUSH_SHOTS (default
# ../cc-shots next to the checkout).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
H=(qs -p "$PWD/tests/harness/cc.qml")
cc() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call cc "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
STUB=$(mktemp -d)
# A second output (pw-cli -m keeps the node alive) and a playing application (pw-cat plays zeros).
pw-cli -m create-node adapter '{ factory.name=support.null-audio-sink node.name=hush-test-sink node.description="Test headphones" media.class=Audio/Sink audio.position=[FL FR] }' >/dev/null 2>&1 & PWCLI=$!
pw-cat -p --raw --format s16 --rate 48000 --channels 2 -P '{ application.name = "Fake Player" }' /dev/zero >/dev/null 2>&1 & PWCAT=$!
LOG=$(mktemp); PATH="$STUB:$PATH" HUSH_BT_NO_ADAPTER=1 "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID $PWCLI $PWCAT 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
# Crops the harness layer out of the output into $SHOTS/$1.png.
shot() {
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
for o in json.load(sys.stdin).values():
  for lv in o['levels'].values():
    for l in lv:
      if l['namespace']=='hush-harness-cc': print('%d,%d %dx%d' % (l['x'],l['y'],l['w'],l['h']))")
  [[ -n "$g" ]] && grim -g "$g" "$SHOTS/$1.png" 2>/dev/null
  assert_file "$SHOTS/$1.png" "saved $SHOTS/$1.png"
}
# PipeWire node id by node.name or application.name.
node_id() { pw-dump | python3 -c "
import json,sys
for o in json.load(sys.stdin):
  p=o.get('info',{}).get('props',{})
  if o.get('type')=='PipeWire:Interface:Node' and '$1' in (p.get('node.name'),p.get('application.name')): print(o['id']); break"; }
default_sink() { wpctl inspect @DEFAULT_AUDIO_SINK@ | sed -n 's/.*node.name = "\(.*\)"/\1/p'; }
wait_for() { local i; for i in $(seq 25); do eval "$1" && return 0; sleep 0.3; done; return 1; }
t_up() {
  local i; for i in $(seq 20); do [[ "$(cc page)" == main ]] && break; sleep 0.5; done
  assert_eq "main" "$(cc page)" "harness starts on the main page"
  wait_for '[[ -n "$(node_id hush-test-sink)" && -n "$(node_id "Fake Player")" ]]' || fail "test sink or stream missing from PipeWire"
}
# The slider's end glyph opens the page: both outputs with the default marked, the microphone and
# the playing application with level and mute.
t_rows() {
  sleep 0.5; shot volume-chevron
  cc openAudio >/dev/null; assert_eq "audio" "$(cc page)" "openAudio opens the sound page"
  wait_for '[[ "$(cc rowCount audioPage)" == 4 ]]' || fail "rows: $(cc audioRows)"
  local rows; rows=$(cc audioRows | tr -d '"')
  assert_contains <(echo "$rows") "sink:Sandbox speakers" "the default output is listed"
  assert_contains <(echo "$rows") "sink:Test headphones" "the second output is listed"
  assert_contains <(echo "$rows") "source:Sandbox microphone" "the default microphone is listed"
  assert_contains <(echo "$rows") "stream:Fake Player" "the playing application is listed by its name"
  sleep 0.5
  assert_eq "true" "$(cc visibleIn audioPage 'Sandbox speakers' audioDefault)" "default output carries the check"
  assert_eq "false" "$(cc visibleIn audioPage 'Test headphones' audioDefault)" "the other output does not"
  assert_eq "false" "$(cc visibleIn audioPage 'Sandbox speakers' audioLevel)" "outputs have no slider"
  assert_eq "true" "$(cc visibleIn audioPage 'Sandbox microphone' audioLevel)" "microphone has a slider"
  assert_eq "true" "$(cc visibleIn audioPage 'Fake Player' audioMute)" "application has a mute"
  shot sound
}
# Tap on an output makes it the default (preferredDefaultAudioSink); the check follows.
t_default() {
  assert_eq "hush-sandbox-sink" "$(default_sink)" "sandbox speakers are the default to begin with"
  cc press audioPage 'Test headphones' "" >/dev/null
  wait_for '[[ "$(default_sink)" == hush-test-sink ]]'
  assert_eq "hush-test-sink" "$(default_sink)" "tap makes the output the default sink"
  sleep 0.4
  assert_eq "true" "$(cc visibleIn audioPage 'Test headphones' audioDefault)" "check moves to the new default"
  assert_eq "false" "$(cc visibleIn audioPage 'Sandbox speakers' audioDefault)" "old default loses it"
  cc press audioPage 'Sandbox speakers' "" >/dev/null
  wait_for '[[ "$(default_sink)" == hush-sandbox-sink ]]'
  assert_eq "hush-sandbox-sink" "$(default_sink)" "tap on the speakers switches back"
}
# Mute and level of a stream and of the microphone reach PipeWire (wpctl reads them back).
t_levels() {
  local id; id=$(node_id "Fake Player")
  cc press audioPage 'Fake Player' audioMute >/dev/null
  wait_for '[[ "$(wpctl get-volume '"$id"')" == *MUTED* ]]'
  assert_contains <(wpctl get-volume "$id") "MUTED" "mute silences the application stream"
  cc press audioPage 'Fake Player' audioMute >/dev/null
  wait_for '[[ "$(wpctl get-volume '"$id"')" != *MUTED* ]]'
  [[ "$(wpctl get-volume "$id")" == *MUTED* ]] && fail "second tap left the stream muted" || pass "second tap unmutes it"
  assert_eq "true" "$(cc moveLevel 'Fake Player' 0.3)" "the stream row has a slider"
  wait_for '[[ "$(wpctl get-volume '"$id"')" == "Volume: 0.30" ]]'
  assert_eq "Volume: 0.30" "$(wpctl get-volume "$id")" "slider sets the stream level"
  assert_eq "0.30" "$(cc nodeVolume 'Fake Player')" "the row reads the level back"
  cc press audioPage 'Sandbox microphone' audioMute >/dev/null
  wait_for '[[ "$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)" == *MUTED* ]]'
  assert_contains <(wpctl get-volume @DEFAULT_AUDIO_SOURCE@) "MUTED" "microphone mute reaches the default source"
  cc press audioPage 'Sandbox microphone' audioMute >/dev/null
  wait_for '[[ "$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)" != *MUTED* ]]'
  [[ "$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)" == *MUTED* ]] && fail "microphone left muted" || pass "microphone unmuted again"
  assert_eq "true" "$(cc back)" "back leaves the sound page"; assert_eq "main" "$(cc page)" "back lands on main"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test up t_up; run_test rows t_rows; run_test default t_default; run_test levels t_levels; run_test log t_log
finish

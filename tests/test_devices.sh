#!/usr/bin/env bash
# Device notifier in a harness (tests/harness/device.qml) with a fake udisksctl on PATH: `monitor` prints a
# fixed stream (one event a second), `dump` lists an internal disk and, once $STUB/plugged exists, a removable
# drive with a filesystem; `mount` / `unmount` / `power-off` log their arguments and change what `dump` says.
# Saves PNGs of the card and of "Safe to remove" to $HUSH_SHOTS (default ../cc-shots next to the checkout).
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
SHOTS="${HUSH_SHOTS:-$PWD/../cc-shots}"; mkdir -p "$SHOTS"
H=(qs -p "$PWD/tests/harness/device.qml")
dv() { local o i; for i in 1 2 3 4 5 6 7 8; do o=$("${H[@]}" ipc call harness-device "$@" 2>/dev/null) && { echo "$o"; return 0; }; sleep 0.5; done; return 1; }
STUB=$(mktemp -d); : >"$STUB/calls"
cat >"$STUB/udisksctl" <<EOF2
#!/bin/sh
case "\$1" in
  monitor) echo "Monitoring the udisks daemon. Press Ctrl+C to exit."
           while sleep 1; do echo "14:32:01.000: Properties Changed /org/freedesktop/UDisks2/block_devices/sdb1"; done ;;
  dump)
    printf '/org/freedesktop/UDisks2/block_devices/sda1:\n  org.freedesktop.UDisks2.Block:\n    Device:  /dev/sda1\n    Drive:  '"'"'/org/freedesktop/UDisks2/drives/Internal'"'"'\n    Size:  500000000000\n  org.freedesktop.UDisks2.Filesystem:\n    MountPoints:  /\n/org/freedesktop/UDisks2/drives/Internal:\n  org.freedesktop.UDisks2.Drive:\n    Removable:  false\n'
    [ -e "$STUB/plugged" ] && printf '/org/freedesktop/UDisks2/block_devices/sdb1:\n  org.freedesktop.UDisks2.Block:\n    Device:  /dev/sdb1\n    Drive:  '"'"'/org/freedesktop/UDisks2/drives/Kingston'"'"'\n    IdLabel:\n    IdType:  exfat\n    Size:  28900000000\n  org.freedesktop.UDisks2.Filesystem:\n    MountPoints:  %s\n/org/freedesktop/UDisks2/drives/Kingston:\n  org.freedesktop.UDisks2.Drive:\n    Model:  DataTraveler\n    Vendor:  Kingston\n    Removable:  true\n' "\$(cat "$STUB/mnt" 2>/dev/null)"
    exit 0 ;;
  mount) echo "mount \$*" >>"$STUB/calls"; echo /run/media/x/KINGSTON >"$STUB/mnt" ;;
  unmount) echo "unmount \$*" >>"$STUB/calls"; rm -f "$STUB/mnt" ;;
  power-off) echo "power-off \$*" >>"$STUB/calls"; rm -f "$STUB/plugged" ;;
esac
EOF2
chmod +x "$STUB/udisksctl"
LOG=$(mktemp); PATH="$STUB:$PATH" "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
wait_for() { local i; for i in $(seq 25); do eval "$1" && return 0; sleep 0.3; done; return 1; }
shot() {
  local g; g=$(hyprctl layers -j | python3 -c "
import json,sys
for o in json.load(sys.stdin).values():
  for lv in o['levels'].values():
    for l in lv:
      if l['namespace']=='hush-harness-device$2': print('%d,%d %dx%d' % (l['x'],l['y'],l['w'],l['h']))")
  [[ -n "$g" ]] && grim -g "$g" "$SHOTS/$1.png" 2>/dev/null
  assert_file "$SHOTS/$1.png" "saved $SHOTS/$1.png"
}
# Nothing shows for the drives present when the shell starts; a plug raises the card.
t_card() {
  dv current >/dev/null; sleep 1.5
  assert_eq "" "$(dv current)" "no card at start"
  assert_eq "false" "$(dv usb)" "no USB glyph on the rest pill without a removable drive"
  touch "$STUB/plugged"
  wait_for '[[ "$(dv current)" == device ]]'
  assert_eq "device" "$(dv current)" "plugging a removable drive raises the device card"
  assert_eq "Kingston DataTraveler" "$(dv title)" "card names the drive (the internal disk is skipped)"
  assert_eq "28.9 GB · exfat · not mounted" "$(dv sub)" "size, filesystem, mount state"
  assert_eq "Mount,Open,eject" "$(dv buttons)" "Mount, Open, Eject"
  assert_eq "true" "$(dv usb)" "USB glyph on the rest pill while it is plugged in"
  sleep 0.6; shot device-card; shot device-glyph -ring
}
t_mount() {
  dv press mount >/dev/null
  wait_for '[[ -s "$STUB/calls" ]]'
  assert_eq "mount mount -b /dev/sdb1" "$(head -1 "$STUB/calls")" "Mount calls udisksctl with the device"
  wait_for '[[ "$(dv sub)" == *"· mounted" ]]'
  assert_eq "28.9 GB · exfat · mounted" "$(dv sub)" "the card follows the next dump"
  assert_eq "Open,eject" "$(dv buttons)" "Mount goes once mounted"
}
t_eject() {
  dv press eject >/dev/null
  wait_for '[[ "$(dv title)" == "Safe to remove" ]]'
  assert_eq "Safe to remove" "$(dv title)" "after the eject the card says so"
  assert_eq "Kingston DataTraveler unmounted and powered off" "$(dv sub)" "and names the drive"
  assert_eq "unmount unmount -b /dev/sdb1|power-off power-off -b /dev/sdb1" "$(sed -n '2,3p' "$STUB/calls" | paste -sd'|')" "unmount, then power-off"
  assert_eq "device" "$(dv current)" "the card is up"
  wait_for '[[ "$(dv usb)" == false ]]'
  assert_eq "false" "$(dv usb)" "the glyph goes with the drive"
  sleep 0.6; shot device-safe
  wait_for '[[ "$(dv current)" == "" ]]' && pass "the card goes after its hold" || fail "card still up"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test card t_card; run_test mount t_mount; run_test eject t_eject; run_test log t_log
finish

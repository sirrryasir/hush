#!/usr/bin/env bash
# Device notifier in a harness (tests/harness/device.qml) with a fake udisksctl on PATH: `monitor` prints a
# fixed stream (one event a second), `dump` prints a removable drive with a filesystem and an internal
# disk, `mount` / `unmount` / `power-off` log their arguments.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
export HUSH_ROOT="$PWD"
export QS_DISABLE_CRASH_HANDLER=1
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
    printf '/org/freedesktop/UDisks2/block_devices/sdb1:\n  org.freedesktop.UDisks2.Block:\n    Device:  /dev/sdb1\n    Drive:  '"'"'/org/freedesktop/UDisks2/drives/Kingston'"'"'\n    IdLabel:\n    IdType:  exfat\n    Size:  28900000000\n  org.freedesktop.UDisks2.Filesystem:\n    MountPoints:  %s\n/org/freedesktop/UDisks2/drives/Kingston:\n  org.freedesktop.UDisks2.Drive:\n    Model:  DataTraveler\n    Vendor:  Kingston\n    Removable:  true\n' "\$(cat "$STUB/mnt" 2>/dev/null)" ;;
  mount) echo "mount \$*" >>"$STUB/calls"; echo /run/media/x/KINGSTON >"$STUB/mnt" ;;
  unmount|power-off) echo "\$1 \$*" >>"$STUB/calls"; rm -f "$STUB/mnt" ;;
esac
EOF2
chmod +x "$STUB/udisksctl"
LOG=$(mktemp); PATH="$STUB:$PATH" "${H[@]}" -n >"$LOG" 2>&1 & HPID=$!
trap 'kill $HPID 2>/dev/null; rm -rf "$LOG" "$STUB"' EXIT
wait_for() { local i; for i in $(seq 25); do eval "$1" && return 0; sleep 0.3; done; return 1; }
t_list() {
  wait_for '[[ "$(dv names)" == "Kingston DataTraveler" ]]'
  assert_eq "Kingston DataTraveler" "$(dv names)" "removable drive listed by vendor and model, internal disk skipped"
  assert_eq "28.9 GB · exfat · not mounted" "$(dv detail)" "size, filesystem, mount state"
}
t_mount() {
  dv mount >/dev/null
  wait_for '[[ -s "$STUB/calls" ]]'
  assert_eq "mount mount -b /dev/sdb1" "$(head -1 "$STUB/calls")" "Mount calls udisksctl with the device"
  wait_for '[[ "$(dv detail)" == *"· mounted" ]]'
  assert_eq "28.9 GB · exfat · mounted" "$(dv detail)" "a mount is picked up from the next dump"
}
t_log() { local e; e=$(grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' "$LOG" || true); [[ -z "$e" ]] && pass "no QML errors" || fail "QML errors: $e"; }
run_test list t_list; run_test mount t_mount; run_test log t_log
finish

#!/usr/bin/env bash
# island.clock "12" switches the lock and login clocks to 12-hour time; anything else is 24-hour.
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/hush"; echo '{"island":{"clock":"12"}}' > "$T/hush/settings.json"
XDG_CONFIG_HOME=$T python3 lockscreen/gen.py hyprlock "$T/a.conf"; grep -q "%-I:%M %p" "$T/a.conf"
XDG_CONFIG_HOME=$T python3 lockscreen/gen.py qml "$T/a.qml"; grep -q "clock12: 1" "$T/a.qml"
XDG_CONFIG_HOME=$T/none python3 lockscreen/gen.py hyprlock "$T/b.conf"; grep -q "%H:%M" "$T/b.conf"
echo "PASS clock format"

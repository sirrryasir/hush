import QtQuick
import Quickshell
import qs.services

// Headless harness for the live-activity services (no windows). tests/test_activity.sh runs it with a
// temporary config dir that symlinks services/ and config/ next to this file.
ShellRoot {
    Component.onCompleted: { Recording.enabled = true; Ipc.themeNames; Privacy.micInUse; Battery.justPlugged; Countdown.running }
}

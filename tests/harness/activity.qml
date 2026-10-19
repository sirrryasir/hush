import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Headless harness for the live-activity services (no windows). tests/test_activity.sh runs it with a
// temporary config dir that symlinks services/ and config/ next to this file.
ShellRoot {
    Component.onCompleted: { Recording.enabled = true; Ipc.themeNames; Privacy.micInUse; Battery.justPlugged; Countdown.running }
    // Test knobs: run the current phase down to one second, set the "before" DND state.
    IpcHandler {
        target: "focustest"
        function hurry(): void { Countdown.endsAt = Date.now() + 800 }
        function dnd(on: bool): void { Notifs.dnd = on }
        function dndOn(): bool { return Notifs.dnd }
        function phase(): string { return Countdown.phase }
    }
}

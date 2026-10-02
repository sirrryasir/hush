pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen-recorder watch: `active` and `kind` ("wf-recorder", "obs", "gpu-screen-recorder" or "").
// Polls pgrep every 2 s, and only while `enabled` (the island sets it from Settings liveActivities).
Singleton {
    id: root
    property bool enabled: true
    property bool active: false
    property string kind: ""
    readonly property var names: ["wf-recorder", "obs", "gpu-screen-recorder"]

    function poll() { if (enabled && !proc.running) proc.running = true }
    onEnabledChanged: { if (enabled) poll(); else { active = false; kind = "" } }

    Process {
        id: proc
        command: ["pgrep", "-x", "-l", "wf-recorder|obs|gpu-screen-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                // pgrep -l prints "<pid> <name>"; the first known name wins.
                const found = text.split("\n").map(l => l.trim().split(/\s+/)[1]).filter(n => root.names.indexOf(n) >= 0)
                root.kind = found.length ? found[0] : ""
                root.active = found.length > 0
            }
        }
    }
    Timer { interval: 2000; running: root.enabled; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }
}

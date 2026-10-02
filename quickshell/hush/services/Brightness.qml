pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level from /sys/class/backlight. changed("brightness") fires after the first 2 s.
Singleton {
    id: root
    property real level: 0
    property real maxLevel: 1
    property bool ready: false
    signal changed(string kind)

    function recompute() {
        const m = parseInt(maxFile.text()), b = parseInt(curFile.text())
        if (!(m > 0) || isNaN(b)) return
        maxLevel = m
        const l = Math.min(1, b / m)
        if (Math.abs(l - level) < 0.0005) return
        level = l
        if (ready) changed("brightness")
    }

    Process {
        id: finder
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim()
                if (d) { maxFile.path = d + "max_brightness"; curFile.path = d + "brightness" }
            }
        }
    }
    FileView { id: maxFile; onLoaded: root.recompute() }
    FileView { id: curFile; watchChanges: true; onFileChanged: reload(); onLoaded: root.recompute() }
    Timer { interval: 2000; running: true; onTriggered: root.ready = true }
    // sysfs inotify is unreliable for ACPI/key-driven changes; poll only while a device exists.
    Timer { interval: 2000; repeat: true; running: curFile.path !== ""; onTriggered: curFile.reload() }
}

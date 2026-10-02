import QtQuick
import Quickshell
import Quickshell.Io

// ";filter": cliphist history. Enter decodes the picked line back onto the clipboard.
Item {
    id: root
    property bool active: false
    property var lines: []
    property bool available: false

    onActiveChanged: if (active && available) { proc.running = false; proc.running = true }

    function items(q) {
        const out = []
        if (!available) return []
        for (const line of lines) {
            const tab = line.indexOf("\t")
            const text = tab >= 0 ? line.slice(tab + 1) : line
            if (q.length && text.toLowerCase().indexOf(q) < 0) continue
            out.push({
                kind: "clip", remember: false, icon: "edit-paste",
                name: text.replace(/\s+/g, " ").slice(0, 120), hint: "clipboard",
                run: () => Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", line])
            })
            if (out.length >= 50) break
        }
        return out
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist"]
        onExited: code => root.available = code === 0
    }
    Process {
        id: proc
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.lines = text.split("\n").filter(l => l.length > 0).slice(0, 200) }
    }
}

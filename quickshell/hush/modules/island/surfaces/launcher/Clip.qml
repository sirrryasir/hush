import QtQuick
import Quickshell
import Quickshell.Io

// ";filter": cliphist history. The list is read again every time clip mode becomes active (the
// launcher is built fresh on each open, so that is every open), never cached from start-up. Enter
// decodes the picked line back onto the clipboard.
Item {
    id: root
    property bool active: false
    property var lines: []
    // false until the first `cliphist list` exits 0 (missing binary or broken db: "not installed").
    property bool available: false
    property bool loaded: false

    function reload() {
        if (!active) return
        proc.running = false
        proc.running = true
    }
    onActiveChanged: reload()
    Component.onCompleted: reload()

    function items(q) {
        const out = []
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
        id: proc
        // 127: cliphist is not installed (the launcher says so instead of "empty").
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 127; exec cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: root.lines = text.split("\n").filter(l => l.length > 0)
        }
        onExited: code => { root.available = code === 0; root.loaded = true }
    }
}

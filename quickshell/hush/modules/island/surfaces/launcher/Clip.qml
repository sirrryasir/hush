import QtQuick
import Quickshell
import Quickshell.Io

// ";filter": cliphist history. The list is read again every time clip mode becomes active (the
// launcher is built fresh on each open, so that is every open), never cached from start-up. Enter
// decodes the picked entry back onto the clipboard, Delete removes it (`cliphist delete`). Image
// entries get a thumbnail: `cliphist decode <id>` into a per-open temp directory, removed on close.
Item {
    id: root
    property bool active: false
    property var lines: []
    // false until the first `cliphist list` ran and the binary exists; an empty history is just empty.
    property bool available: false
    property bool loaded: false
    // Decoded thumbnails by cliphist id: { "6620": "file:///run/user/1000/hush-clip-<pid>/6620" }.
    property var thumbs: ({})
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hush-clip-" + Date.now()
    property int loadCount: 0

    function reload() {
        if (!active) return
        proc.running = false
        proc.running = true
    }
    onActiveChanged: reload()
    Component.onCompleted: reload()
    Component.onDestruction: Quickshell.execDetached(["rm", "-rf", thumbDir])

    // "[[ binary data 223 KiB png 559x309 ]]" -> { size, fmt, dims }, else null.
    function binary(text) {
        const m = /^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/.exec(text)
        return m ? { size: m[1], fmt: m[2], dims: m[3].replace("x", "×") } : null
    }
    function items(q) {
        const out = [], want = []
        for (const line of lines) {
            const tab = line.indexOf("\t")
            const id = tab >= 0 ? line.slice(0, tab) : ""
            const raw = tab >= 0 ? line.slice(tab + 1) : line
            const bin = binary(raw)
            const text = bin ? "Image " + bin.dims + " " + bin.fmt : raw.replace(/[\u0000-\u0008\u000e-\u001f\u007f\ufeff]/g, "").replace(/\s+/g, " ").trim()
            if (q.length && text.toLowerCase().indexOf(q) < 0) continue
            const isImage = !!bin && /^(png|jpe?g|gif|webp|bmp)$/i.test(bin.fmt)
            if (isImage && !thumbs[id]) want.push(id)
            out.push({
                kind: "clip", remember: false, glyph: bin ? "image" : "content_paste",
                thumbId: isImage ? id : "",
                name: bin ? "Image" : text.slice(0, 160),
                hint: bin ? bin.dims + "  ·  " + bin.size : "",
                run: () => Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", line]),
                remove: () => root.remove(line)
            })
            if (out.length >= 50) break
        }
        if (want.length) Qt.callLater(root.decode, want)
        return out
    }

    function remove(line) {
        lines = lines.filter(l => l !== line)
        deleter.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", line]
        deleter.running = true
    }

    // Thumbnails: one queue, one process at a time; ids already decoded or in flight are skipped.
    property var queue: []
    property var pending: ({})
    function decode(ids) {
        const p = Object.assign({}, pending), q = queue.slice()
        for (const id of ids) if (!thumbs[id] && !p[id]) { p[id] = true; q.push(id) }
        pending = p; queue = q
        pump()
    }
    function pump() {
        if (decoder.running || !queue.length) return
        const batch = queue.slice(0, 12)
        queue = queue.slice(12)
        decoder.command = ["sh", "-c", "d=$1; shift; mkdir -p \"$d\" || exit 1; for id; do "
            + "cliphist decode \"$id\" >\"$d/$id.part\" 2>/dev/null && mv \"$d/$id.part\" \"$d/$id\" && echo \"$id\"; done",
            "sh", thumbDir].concat(batch)
        decoder.running = true
    }
    Process {
        id: decoder
        stdout: SplitParser {
            onRead: id => { const t = Object.assign({}, root.thumbs); t[id] = "file://" + root.thumbDir + "/" + id; root.thumbs = t }
        }
        onExited: Qt.callLater(root.pump)
    }

    Process {
        id: proc
        // 127: cliphist is not installed (the launcher says so instead of "empty").
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 127; exec cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: root.lines = text.split("\n").filter(l => l.length > 0)
        }
        onExited: code => { root.available = code !== 127; root.loaded = true; root.loadCount++ }
    }
    Process { id: deleter; onExited: root.reload() }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Files kept on the island by reference (nothing is copied): [{path, at}] with `at` the epoch ms they
// were dropped, forgotten after `ttlMs` (24 h). Kept in ~/.cache/hush/shelf.json so a restart keeps them.
// shortcut: a file deleted or moved after it was kept stays listed until it expires.
Singleton {
    id: root
    property var items: []
    readonly property int count: items.length
    readonly property real ttlMs: 24 * 3600 * 1000
    property real now: Date.now()
    readonly property string file: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hush/shelf.json"

    function nameOf(path) { return path.slice(path.lastIndexOf("/") + 1) }
    function folderOf(path) { const d = path.slice(0, path.lastIndexOf("/")); return d.slice(d.lastIndexOf("/") + 1) || "/" }
    function left(at) {
        const m = Math.max(0, Math.ceil((at + ttlMs - now) / 60000))
        return m >= 60 ? Math.ceil(m / 60) + " h left" : m + " min left"
    }
    // A drop hands over file:// URLs (or plain paths from IPC); `at` is for tests.
    function add(paths, at) {
        now = Date.now()
        const have = items.map(i => i.path), out = items.slice()
        for (const p of paths) {
            const s = String(p), path = s.indexOf("file://") === 0 ? decodeURIComponent(s.slice(7)) : s
            if (path && have.indexOf(path) < 0) { have.push(path); out.push({ path: path, at: at || now }) }
        }
        items = out; prune(); save()
    }
    function remove(path) { set(items.filter(i => i.path !== path)) }
    function set(list) { items = list; save() }
    function prune() { now = Date.now(); const keep = items.filter(i => i.at + ttlMs > now); if (keep.length !== items.length) set(keep) }
    function save() { store.setText(JSON.stringify(items)) }

    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: { try { root.items = JSON.parse(text()) } catch (e) {} root.prune() }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.prune() }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings: defaults (settings.default.json next to this file) deep-merged with
// ~/.config/hush/settings.json, hot-reloaded on change. `set` writes only the user's overrides.
Singleton {
    id: root
    readonly property string userPath: Quickshell.env("HOME") + "/.config/hush/settings.json"
    property var defaults: ({})
    property var user: ({})
    readonly property var data: root.merge(root.defaults, root.user)
    readonly property var island: root.data.island || ({})
    readonly property var modules: root.data.modules || ({})
    readonly property var motion: root.data.motion || ({})
    // The fallback covers the moment before settings.default.json has loaded.
    readonly property var focus: Object.assign({ focus: 25, break: 5, long: 15, cycles: 4 }, root.data.focus)
    readonly property var layout: root.data.layout || ({})

    function isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }
    function merge(a, b) {
        const out = JSON.parse(JSON.stringify(a || {}))
        for (const k in (b || {})) out[k] = (isObj(out[k]) && isObj(b[k])) ? merge(out[k], b[k]) : b[k]
        return out
    }
    function get(path) {
        let v = root.data
        for (const p of String(path).split(".")) { if (v === undefined || v === null) return undefined; v = v[p] }
        return v
    }
    // Atomic write: temp file in the same directory, then rename over the target.
    function set(path, value) {
        const keys = String(path).split("."), u = JSON.parse(JSON.stringify(root.user || {}))
        let o = u
        for (let i = 0; i < keys.length - 1; i++) { if (!isObj(o[keys[i]])) o[keys[i]] = {}; o = o[keys[i]] }
        o[keys[keys.length - 1]] = value
        root.write(u)
    }
    // Drop the user's override at `path` (and any empty parents), so the default applies again.
    function unset(path) {
        const keys = String(path).split("."), u = JSON.parse(JSON.stringify(root.user || {}))
        const chain = [u]
        for (let i = 0; i < keys.length - 1; i++) { const n = chain[i][keys[i]]; if (!isObj(n)) return; chain.push(n) }
        if (!(keys[keys.length - 1] in chain[chain.length - 1])) return
        delete chain[chain.length - 1][keys[keys.length - 1]]
        for (let i = chain.length - 1; i > 0; i--) if (Object.keys(chain[i]).length === 0) delete chain[i - 1][keys[i - 1]]
        root.write(u)
    }
    // One write at a time: a change made while the writer runs is queued (the latest wins), so two
    // quick changes (a row moved twice) never leave the older one on disk.
    property var pendingWrite: null
    function write(u) {
        root.user = u
        if (writer.running) { root.pendingWrite = u; return }
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "sh", root.userPath, JSON.stringify(u, null, 2)]
        writer.running = true
    }

    FileView {
        id: defFile
        path: Quickshell.shellDir + "/config/settings.default.json"
        blockLoading: true
        onLoaded: { try { root.defaults = JSON.parse(defFile.text()) } catch (e) { console.warn("settings.default.json parse failed: " + e) } }
    }
    FileView {
        id: userFile
        printErrors: false
        path: root.userPath
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        // A reload landing between two queued writes would briefly bring back the older one.
        onLoaded: { if (writer.running || root.pendingWrite !== null) return
            try { root.user = JSON.parse(userFile.text()) } catch (e) { console.warn("settings.json parse failed: " + e) } }
        onLoadFailed: root.user = ({})
    }
    Timer { id: reloadTimer; interval: 80; onTriggered: userFile.reload() }
    Process {
        id: writer
        onExited: if (root.pendingWrite !== null) { const u = root.pendingWrite; root.pendingWrite = null; root.write(u) }
    }
}

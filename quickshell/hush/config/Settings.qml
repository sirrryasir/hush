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
        root.user = u
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
        onLoaded: { try { root.user = JSON.parse(userFile.text()) } catch (e) { console.warn("settings.json parse failed: " + e) } }
        onLoadFailed: root.user = ({})
    }
    Timer { id: reloadTimer; interval: 80; onTriggered: userFile.reload() }
    Process { id: writer }
}

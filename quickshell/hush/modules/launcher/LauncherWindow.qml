import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.services
import "sources"

// The launcher controller plus one window per screen. Only the window on the focused
// monitor is ever shown. Results are computed once here and every window renders them.
Scope {
    id: root

    property bool visible: false
    property string screenName: ""
    property string query: ""
    // "all" merges apps and windows; "apps" and "windows" restrict to one source.
    property string mode: "all"
    property int currentIndex: 0
    property var recency: ({})

    readonly property bool calcMode: query.startsWith("=")
    readonly property bool clipMode: query.startsWith(";")
    readonly property var results: visible ? compute() : []
    readonly property int count: results.length
    readonly property var first: count > 0 ? results[0] : null

    function show(m) {
        mode = (m === "apps" || m === "windows") ? m : "all"
        query = m === "clip" ? ";" : ""
        currentIndex = 0
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
        if (Ipc.island && typeof Ipc.island.release === "function") Ipc.island.release("expanded")
        pendingRun = null
        visible = true
    }
    function hide() {
        // A switch queued by activate() in this same hide cycle survives; any other is stale.
        if (!queuingRun) { pendingRun = null; pendingTimer.stop() }
        visible = false; query = ""; currentIndex = 0
    }
    function toggle() { visible ? hide() : show("all") }
    function setQuery(q) { query = q; currentIndex = 0 }
    function move(d) { if (count > 0) currentIndex = (currentIndex + d + count) % count }
    // Focusing a window must wait until Hyprland has unmapped the launcher; otherwise its
    // focus restore on unmap lands after our dispatch and undoes it.
    property var pendingRun: null
    property bool queuingRun: false
    readonly property bool clipAvailable: clip.available
    function activate(i) {
        const item = results[i === undefined ? currentIndex : i]
        if (!item) return
        if (item.remember) bump(item.name)
        if (item.kind === "window") { pendingRun = item.run; queuingRun = true; pendingTimer.restart() }
        hide()
        queuingRun = false
        if (item.kind !== "window") item.run()
    }

    // Subsequence match with bonuses for a prefix hit, word starts, and consecutive runs.
    function fuzzy(q, s) {
        if (!s) return -1
        s = s.toLowerCase()
        if (q.length === 0) return 0
        let score = 0, si = 0, prev = -2
        for (let qi = 0; qi < q.length; qi++) {
            const c = q[qi]
            const at = s.indexOf(c, si)
            if (at < 0) return -1
            score += 1
            if (at === prev + 1) score += 3
            if (at === 0 || " -_./".indexOf(s[at - 1]) >= 0) score += 5
            prev = at; si = at + 1
        }
        if (s.startsWith(q)) score += 15
        if (s === q) score += 10
        return score - s.length * 0.05
    }
    function bump(name) {
        let r = Object.assign({}, recency)
        r[name] = (r[name] || 0) + 1
        // Keep the 200 most-used names so the file stays bounded.
        const keys = Object.keys(r)
        if (keys.length > 200) {
            const kept = {}
            keys.sort((a, b) => r[b] - r[a]).slice(0, 200).forEach(k => kept[k] = r[k])
            r = kept
        }
        recency = r
        recencyFile.setText(JSON.stringify(r))
    }
    function compute() {
        if (calcMode) return calc.items(query.slice(1))
        if (clipMode) return clip.items(query.slice(1).trim().toLowerCase())
        const q = query.trim().toLowerCase()
        let pool = []
        if (mode !== "windows") pool = pool.concat(apps.items())
        if (mode !== "apps") pool = pool.concat(windows.items())
        const out = []
        for (const it of pool) {
            let s = fuzzy(q, it.name)
            const h = fuzzy(q, it.keywords || it.hint) * 0.5
            if (h > s) s = h
            if (s < 0) continue
            // Windows rank above apps on an empty query; recency lifts frequent picks.
            s += Math.log(1 + (recency[it.name] || 0)) * 4 + (it.kind === "window" && q.length === 0 ? 100 : 0)
            out.push({ item: it, score: s })
        }
        out.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name))
        return out.slice(0, 50).map(o => o.item)
    }

    Apps { id: apps }
    Windows { id: windows }
    Calc { id: calc; query: root.calcMode ? root.query.slice(1).trim() : "" }
    Clip { id: clip; active: root.visible && root.clipMode }

    Connections {
        target: Hyprland
        enabled: root.pendingRun !== null
        function onRawEvent(event) {
            if (event.name !== "closelayer" || event.data !== "hush-launcher") return
            root.runPending()
        }
    }

    function runPending() {
        pendingTimer.stop()
        const run = pendingRun
        pendingRun = null
        if (run) run()
    }
    // Safety net: if closelayer never arrives, switch anyway rather than leak the request.
    Timer { id: pendingTimer; interval: 1500; onTriggered: root.runPending() }

    // The recency file lives in ~/.cache/hush; make sure the directory exists before any write.
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/hush"]
    }

    FileView {
        id: recencyFile
        atomicWrites: true
        path: Quickshell.env("HOME") + "/.cache/hush/launcher-recency.json"
        printErrors: false
        onLoaded: { try { root.recency = JSON.parse(text()) || {} } catch (e) { root.recency = {} } }
    }

    Variants {
        model: Quickshell.screens
        delegate: Launcher {
            required property var modelData
            screen: modelData
            controller: root
            shown: root.visible && modelData.name === root.screenName
        }
    }

    Component.onCompleted: Ipc.launcher = root
}

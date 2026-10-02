pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property string activeTitle: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
    readonly property string activeClass: {
        const t = Hyprland.activeToplevel;
        if (!t || !t.lastIpcObject) return "";
        return t.lastIpcObject.class || "";
    }
    // Sorted list of {id, name, active, occupied, monitor}: ids 1..5 plus any others that exist.
    property var workspaces: []
    readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    // True while the focused monitor's active workspace has a fullscreen window (the island retracts).
    readonly property bool fullscreenOnFocused: {
        const m = Hyprland.focusedMonitor
        return !!(m && m.activeWorkspace && m.activeWorkspace.hasFullscreen)
    }

    function rebuild() {
        const byId = {};
        const vals = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < vals.length; i++) {
            const w = vals[i];
            if (w.id > 0) byId[w.id] = w;
        }
        const ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        for (const k in byId) { const n = parseInt(k); if (ids.indexOf(n) < 0) ids.push(n); }
        ids.sort((a, b) => a - b);
        const out = [];
        for (const id of ids) {
            const w = byId[id];
            out.push({
                id: id,
                name: w ? w.name : String(id),
                active: id === root.focusedId,
                occupied: w ? w.toplevels.values.length > 0 : false,
                monitor: w && w.monitor ? w.monitor.name : ""
            });
        }
        const ma = {};
        const mons = Hyprland.monitors ? Hyprland.monitors.values : [];
        for (const m of mons) if (m.activeWorkspace) ma[m.name] = m.activeWorkspace.id;
        if (JSON.stringify(ma) !== JSON.stringify(root.monActive)) root.monActive = ma;
        if (JSON.stringify(out) !== JSON.stringify(root.workspaces)) root.workspaces = out;
    }

    property var monActive: ({})

    // Workspaces to show on one monitor: its own existing ones plus the 5-wide block around its active one
    // (Hyprland binds 1..5 and 6..10 to different monitors in this setup).
    function workspacesFor(monitorName) {
        const aid = root.monActive[monitorName] !== undefined ? root.monActive[monitorName] : root.focusedId;
        const block = Math.floor((aid - 1) / 5) * 5;
        const byId = {};
        for (const w of root.workspaces) byId[w.id] = w;
        const ids = [];
        for (let i = 1; i <= 5; i++) ids.push(block + i);
        for (const w of root.workspaces) if (w.monitor === monitorName && ids.indexOf(w.id) < 0) ids.push(w.id);
        ids.sort((x, y) => x - y);
        return ids.map(id => ({
            id: id,
            name: byId[id] ? byId[id].name : String(id),
            active: id === aid,
            occupied: byId[id] ? byId[id].occupied : false,
            monitor: monitorName
        }));
    }

    function go(id) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }
    function step(delta) {
        // Move through the focused monitor's workspaces.
        const m = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const list = root.workspacesFor(m);
        let idx = list.findIndex(w => w.id === root.focusedId);
        if (idx < 0) return;
        idx = Math.max(0, Math.min(list.length - 1, idx + delta));
        root.go(list[idx].id);
    }

    Component.onCompleted: rebuild()
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.rebuild() }
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.rebuild() }
    }
    Timer { id: debounce; interval: 100; onTriggered: root.rebuild() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            debounce.restart()
            // hasFullscreen is only re-read from a workspace refresh.
            if (ev.name === "fullscreen") Hyprland.refreshWorkspaces()
        }
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.rebuild() }
    }
}

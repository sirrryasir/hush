pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    // Modules register themselves here so IPC can reach them without import cycles.
    property var island: null
    // Islands by screen name. `island` (what IPC, OSD and notifications drive) is the one on the focused
    // monitor; an expanded island keeps the role until it collapses, so it never jumps between screens.
    property var islands: ({})
    property string islandScreenName: ""
    function registerIsland(name, isl) { const m = Object.assign({}, islands); m[name] = isl; islands = m; pick() }
    function unregisterIsland(name) { const m = Object.assign({}, islands); delete m[name]; islands = m; pick() }
    function pick() {
        if (island && island.surfaceOpen && Object.values(islands).indexOf(island) >= 0) return
        const names = Object.keys(islands)
        if (!names.length) { island = null; islandScreenName = ""; return }
        const n = islands[Hypr.focusedMonitorName] ? Hypr.focusedMonitorName
            : (Quickshell.screens.length && islands[Quickshell.screens[0].name] ? Quickshell.screens[0].name : names[0])
        if (island !== islands[n]) island = islands[n]
        islandScreenName = n
    }
    Connections { target: Hypr; function onFocusedMonitorNameChanged() { root.pick() } }

    Timer { id: probeOpen; onTriggered: { if (root.island) root.island.toggleExpanded(); if (probeClose.interval > 0) probeClose.restart() } }
    Timer { id: probeClose; onTriggered: if (root.island && root.island.state === "expanded") root.island.toggleExpanded() }

    IpcHandler {
        target: "hush"
        function ping(): string { return "pong" }
        function islandState(): string { return root.island ? (root.island.hidden ? "hidden" : root.island.state) : "none" }
        function islandScreen(): string { return root.islandScreenName }
        function islandSize(): string { return root.island ? Math.round(root.island.bodyWidth) + "x" + Math.round(root.island.bodyHeight) : "none" }
        function screens(): int { return Quickshell.screens.length }
        function colorsLoaded(): bool { return Colors.loaded }
        function primary(): string { return Colors.primary.toString() }
        function darkOnSurface(): string { return Colors.darkOnSurface.toString() }
        function focusedWorkspace(): int { return Hypr.focusedId }
        function restWidth(): int { return root.island ? root.island.restWidth : 0 }
        function restClock(): string { return root.island ? root.island.restClock : "" }
        function batteryPercent(): int { return Battery.percent }
        function netConnected(): bool { return Net.connected }
        function goWorkspace(id: int): void { Hypr.go(id) }
        function reload(): void { Quickshell.reload(false) }
        // --- modal surfaces (launcher, wallpapers, settings) inside the island ---
        function toggleLauncher(): void { if (root.island) root.island.toggleSurface("launcher", { mode: "apps" }) }
        function showLauncher(mode: string): void { if (root.island) root.island.openSurface("launcher", { mode: mode === "all" || !mode ? "apps" : mode }) }
        function launcherVisible(): bool { return root.island ? root.island.state === "launcher" : false }
        function launcherQuery(q: string): void { const l = root.surface("launcher"); if (l) l.setQuery(q) }
        function launcherCount(): int { const l = root.surface("launcher"); return l ? l.count : 0 }
        function launcherFirst(): string { const l = root.surface("launcher"); return l ? l.firstName : "" }
        function toggleWallpapers(): void { if (root.island) root.island.toggleSurface("wallpapers") }
        function wallpapersVisible(): bool { return root.island ? root.island.state === "wallpapers" : false }
        function wallpapersCount(): int { const w = root.surface("wallpapers"); return w ? w.count : 0 }
        // Picks the tile for path (the reveal grows from it); a path not in the grid applies directly.
        function wallpapersSelect(path: string): string {
            const w = root.surface("wallpapers")
            const i = w ? w.files.indexOf(path) : -1
            if (i >= 0) { w.pickIndex(i); return w.lastFrom }
            Quickshell.execDetached([Paths.hush, "wall", path])
            if (root.island) root.island.closeSurface()
            return ""
        }
        function settings(): void { if (root.island) root.island.toggleSurface("settings") }
        function settingsVisible(): bool { return root.island ? root.island.state === "settings" : false }
        function settingsWarning(): string { const s = root.surface("settings"); return s ? s.warning : "" }
        // Toasts and the notification center (toggleDrawer is the v1 name the keybinds still call).
        function toggleDrawer(): void { if (root.island) root.island.toggleSurface("notifCenter") }
        function toggleNotifications(): void { if (root.island) root.island.toggleSurface("notifCenter") }
        function toggleControlCenter(): void { if (root.island) root.island.toggleExpanded() }
        // --- hover and input (Task 6) ---
        function openSurface(name: string): void { if (root.island) root.island.openSurface(name) }
        function closeSurface(): void { if (root.island) root.island.closeSurface() }
        function islandClick(button: string): void { if (root.island) root.island.click(button === "right" ? Qt.RightButton : button === "middle" ? Qt.MiddleButton : Qt.LeftButton) }
        function islandArmed(): bool { return root.island ? root.island.armed : true }
        function islandHistory(): string { return root.island ? JSON.stringify(root.island.history) : "[]" }
        function islandHovered(): bool { return root.island ? root.island.pointerInside : false }
        // Window-local centre "x y" of a named control in the shown surface (tests click it), or "".
        function islandControl(name: string): string {
            const it = root.island && root.island.item ? root.findNamed(root.island.item, name) : null
            if (!it) return ""
            const p = it.mapToItem(null, it.width / 2, it.height / 2)
            return Math.round(p.x) + " " + Math.round(p.y)
        }
        // --- end hover and input ---
        // Morph probe for tests/test_morph.sh: open the control center after delayMs, reverse it
        // reverseMs later (0: stay open), timed in the shell so no IPC client start-up lands mid-capture.
        function morphProbe(delayMs: int, reverseMs: int): void { probeOpen.interval = Math.max(1, delayMs); probeClose.interval = Math.max(0, reverseMs); probeOpen.restart() }
        function islandStage(): string { return root.island ? root.island.shapeState + "/" + root.island.shownState + "/" + root.island.contentOpacity.toFixed(2) : "none" }
        function clearNotifications(): void { Notifs.clearAll() }
        function unread(): int { return Notifs.unread }
        function osd(kind: string): void { if (root.island) root.island.showOsd(kind) }
        function theme(name: string): void { root.setTheme(name) }
        function ccThemeCount(): int { return root.themeNames.length }
        function ccSetTheme(name: string): void { root.setTheme(name) }
        // --- settings (Task 1) ---
        function settingsGet(key: string): string { const v = Settings.get(key); return v === undefined ? "" : JSON.stringify(v) }
        function settingsSet(key: string, json: string): void { try { Settings.set(key, JSON.parse(json)) } catch (e) { console.warn("settingsSet: bad json for " + key) } }
        // --- end settings ---
    }
    // --- activity IPC (Task 15) ---
    IpcHandler {
        target: "activity"
        function timerStart(sec: int): void { Countdown.start(sec, "") }
        function timerStop(): void { Countdown.stop() }
        function timerRemaining(): int { return Countdown.remaining }
        function recording(): bool { return Recording.active }
        function micInUse(): bool { return Privacy.micInUse }
        function cameraInUse(): bool { return Privacy.cameraInUse }
        function justPlugged(): bool { return Battery.justPlugged }
    }
    // --- end activity IPC ---
    // The shown surface item of that name on the driven island, once loaded.
    function surface(name) { return root.island ? root.island.surfaceItem(name) : null }
    function findNamed(item, name) {
        if (item.objectName === name) return item
        for (let i = 0; i < item.children.length; i++) { const f = findNamed(item.children[i], name); if (f) return f }
        return null
    }
    property var themeNames: []
    function setTheme(name) { themeProc.command = [Paths.hush, "theme", name]; themeProc.running = true }
    Process { id: themeProc }
    // List the themes once the repo root has resolved (Paths reads it asynchronously).
    function listThemes() { if (!Paths.ready) return; themeLister.command = ["ls", Paths.repo + "/themes"]; themeLister.running = true }
    Process {
        id: themeLister
        stdout: StdioCollector { onStreamFinished: root.themeNames = text.trim().split("\n").filter(n => n) }
    }
    Connections { target: Paths; function onReadyChanged() { root.listThemes() } }
    Component.onCompleted: { listThemes(); Settings.data }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    // Modules register themselves here so IPC can reach them without import cycles.
    property var island: null
    property var launcher: null
    property var wallpapers: null
    property var drawer: null
    // Islands by screen name. `island` (what IPC, OSD and notifications drive) is the one on the focused
    // monitor; an expanded island keeps the role until it collapses, so it never jumps between screens.
    property var islands: ({})
    property string islandScreenName: ""
    function registerIsland(name, isl) { const m = Object.assign({}, islands); m[name] = isl; islands = m; pick() }
    function unregisterIsland(name) { const m = Object.assign({}, islands); delete m[name]; islands = m; pick() }
    function pick() {
        if (island && island.state === "expanded" && Object.values(islands).indexOf(island) >= 0) return
        const names = Object.keys(islands)
        if (!names.length) { island = null; islandScreenName = ""; return }
        const n = islands[Hypr.focusedMonitorName] ? Hypr.focusedMonitorName
            : (Quickshell.screens.length && islands[Quickshell.screens[0].name] ? Quickshell.screens[0].name : names[0])
        if (island !== islands[n]) island = islands[n]
        islandScreenName = n
    }
    Connections { target: Hypr; function onFocusedMonitorNameChanged() { root.pick() } }

    IpcHandler {
        target: "hush"
        function ping(): string { return "pong" }
        function islandState(): string { return root.island ? root.island.state : "none" }
        function islandScreen(): string { return root.islandScreenName }
        function islandSize(): string { return root.island ? Math.round(root.island.bodyWidth) + "x" + Math.round(root.island.bodyHeight) : "none" }
        function screens(): int { return Quickshell.screens.length }
        function colorsLoaded(): bool { return Colors.loaded }
        function primary(): string { return Colors.primary.toString() }
        function darkOnSurface(): string { return Colors.darkOnSurface.toString() }
        function focusedWorkspace(): int { return Hypr.focusedId }
        function batteryPercent(): int { return Battery.percent }
        function netConnected(): bool { return Net.connected }
        function goWorkspace(id: int): void { Hypr.go(id) }
        function reload(): void { Quickshell.reload(false) }
        function toggleLauncher(): void { if (root.launcher) root.launcher.toggle() }
        function showLauncher(mode: string): void { if (root.launcher) root.launcher.show(mode) }
        function launcherVisible(): bool { return root.launcher ? root.launcher.visible : false }
        function launcherQuery(q: string): void { if (root.launcher) root.launcher.setQuery(q) }
        function launcherCount(): int { return root.launcher ? root.launcher.count : 0 }
        function launcherFirst(): string { return root.launcher && root.launcher.first ? root.launcher.first.name : "" }
        function toggleWallpapers(): void { if (root.wallpapers) root.wallpapers.toggle() }
        function wallpapersVisible(): bool { return root.wallpapers ? root.wallpapers.visible : false }
        function wallpapersCount(): int { return root.wallpapers ? root.wallpapers.count : 0 }
        function wallpapersSelect(path: string): void { if (root.wallpapers) root.wallpapers.select(path) }
        function toggleControlCenter(): void { if (root.island) root.island.toggleExpanded() }
        function toggleDrawer(): void { if (root.drawer) root.drawer.toggle() }
        function clearNotifications(): void { Notifs.clearAll() }
        function unread(): int { return Notifs.unread }
        function osd(kind: string): void { if (root.island) root.island.showOsd(kind) }
        function theme(name: string): void { root.setTheme(name) }
        function ccThemeCount(): int { return root.themeNames.length }
        function ccSetTheme(name: string): void { root.setTheme(name) }
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
    Component.onCompleted: listThemes()
}

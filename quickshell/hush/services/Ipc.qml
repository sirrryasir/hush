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
        function batteryPresent(): bool { return Battery.present }
        function batteryCharging(): bool { return Battery.charging }
        function batterySummary(): string { return Battery.present ? Battery.percent + " % · " + Battery.stateText : "" }
        // What the rest status ring shows in its centre: "percent:80", "glyph:<name>" or "none".
        function ringGlyph(): string { const r = root.island ? root.findNamed(root.island, "statusRing") : null; return r ? r.glyph : "" }
        function ringCenter(): string { const r = root.island ? root.findNamed(root.island, "statusRing") : null; return r ? r.center : "" }
        function netConnected(): bool { return Net.connected }
        // Bluetooth: the control center's toggle (lifts an rfkill block when the adapter is missing).
        function btToggle(): void { Bt.toggle() }
        function btEnabled(): bool { return Bt.enabled }
        function btBlocked(): bool { return Bt.blocked }
        function btSubtitle(): string { return Bt.subtitle }
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
        // Toasts and the notification center.
        function toggleDrawer(): void { if (root.island) root.island.toggleSurface("notifCenter") }
        function toggleControlCenter(): void { if (root.island) root.island.toggleExpanded() }
        // --- hover and input ---
        function openSurface(name: string): void { if (root.island) root.island.openSurface(name) }
        function closeSurface(): void { if (root.island) root.island.closeSurface() }
        function islandHistory(): string { return root.island ? JSON.stringify(root.island.history) : "[]" }
        // Window-local centre "x y" of a named control in the shown surface (tests click it), or "".
        function islandControl(name: string): string {
            const it = root.island && root.island.item ? root.findNamed(root.island.item, name) : null
            if (!it) return ""
            const p = it.mapToItem(null, it.width / 2, it.height / 2)
            return Math.round(p.x) + " " + Math.round(p.y)
        }
        // True when the named control exists in the shown state and is visible on screen.
        function islandControlVisible(name: string): bool {
            const it = root.island && root.island.item ? root.findNamed(root.island.item, name) : null
            return !!it && it.visible
        }
        // The named control's text in the shown state ("" when absent).
        function islandControlText(name: string): string {
            const it = root.island && root.island.item ? root.findNamed(root.island.item, name) : null
            return it && it.text !== undefined ? String(it.text) : ""
        }
        // --- end hover and input ---
        // --- modes, fullscreen overlay, keyboard ---
        function osdOverlayVisible(): bool { return root.island ? root.island.overlayOsd : false }
        // The keyboard-focused control's objectName (or its class when unnamed), "" when none.
        function islandFocus(): string {
            const t = root.island ? root.island.navTarget : null
            return t && t.visible ? (t.objectName || String(t).split("(")[0]) : ""
        }
        function islandFocusRing(): bool {
            const r = root.island ? root.findNamed(root.island, "focusRing") : null
            return !!r && r.visible
        }
        // Workspace overview: the GloView Hyprland plugin (Hush builds none of its own).
        function overview(): void { root.overview() }
        // --- end modes ---
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
        // --- settings ---
        function settingsGet(key: string): string { const v = Settings.get(key); return v === undefined ? "" : JSON.stringify(v) }
        function settingsSet(key: string, json: string): void { try { Settings.set(key, JSON.parse(json)) } catch (e) { console.warn("settingsSet: bad json for " + key) } }
        // --- layout composer ---
        function settingsReset(key: string): void { Settings.unset(key) }
        // Visible items of the shown state named <prefix><id>, in reading order: "id,id,..".
        function islandChips(prefix: string): string {
            const root0 = root.island ? root.island.item : null, out = []
            const walk = it => {
                if (!it || !it.visible) return
                if (typeof it.objectName === "string" && it.objectName.indexOf(prefix) === 0 && it.width > 0) {
                    const p = it.mapToItem(root0, 0, 0); out.push({ id: it.objectName.slice(prefix.length), x: p.x, y: p.y })
                }
                for (let i = 0; i < it.children.length; i++) walk(it.children[i])
            }
            walk(root0)
            out.sort((a, b) => Math.abs(a.y - b.y) > 8 ? a.y - b.y : a.x - b.x)
            return out.map(e => e.id).join(",")
        }
        function layoutHover(): string { return Composer.hoverShown.join(",") }
        function layoutTiles(): string { return Composer.tilesShown.map(t => t.id + ":" + t.size).join(",") }
        // --- end settings ---
    }
    // --- activity IPC ---
    IpcHandler {
        target: "activity"
        function timerStart(sec: int): void { Countdown.start(sec, "") }
        function timerStop(): void { Countdown.stop() }
        function timerRemaining(): int { return Countdown.remaining }
        function focusStart(): void { Countdown.focusStart("focus") }
        function focusPhase(): string { return Countdown.phaseLabel }
        function focusCycle(): int { return Countdown.cycle }
        function recording(): bool { return Recording.active }
        function micInUse(): bool { return Privacy.micInUse }
        function cameraInUse(): bool { return Privacy.cameraInUse }
        function justPlugged(): bool { return Battery.justPlugged }
        function caffeine(on: bool): void { Caffeine.on = on }
        function caffeineOn(): bool { return Caffeine.on }
    }
    IpcHandler {
        target: "shelf"
        function add(path: string): void { Shelf.add([path]) }
        function addAged(path: string, hoursAgo: int): void { Shelf.add([path], Shelf.now - hoursAgo * 3600000) }
        function remove(path: string): void { Shelf.remove(path) }
        function count(): int { return Shelf.count }
        // Stands in for a file drag entering (true) or leaving the pill.
        function drag(on: bool): void { if (root.island) on ? root.island.arbiter.raise("shelfDrop") : root.island.arbiter.lower("shelfDrop") }
        // "name | folder · N h left" per chip of the open strip, one per line.
        function rows(): string {
            const l = root.surface("shelf") ? root.findNamed(root.surface("shelf"), "shelfList") : null, out = []
            for (let i = 0; l && i < l.count; i++) { const c = l.itemAtIndex(i); if (c) out.push(c.summary) }
            return out.join("\n")
        }
    }
    // --- end activity IPC ---
    // The shown surface item of that name on the driven island, once loaded.
    function surface(name) { return root.island ? root.island.surfaceItem(name) : null }
    function findNamed(item, name) {
        if (item.objectName === name) return item
        for (let i = 0; i < item.children.length; i++) { const f = findNamed(item.children[i], name); if (f) return f }
        return null
    }
    // Runs `hyprctl gloview` when the GloView plugin is loaded; otherwise does nothing and logs once.
    property bool overviewWarned: false
    function overview() { if (!overviewProc.running) overviewProc.running = true }
    Process {
        id: overviewProc
        command: ["sh", "-c", "hyprctl plugin list 2>/dev/null | grep -q 'Plugin GloView' || exit 3; hyprctl gloview >/dev/null"]
        onExited: code => {
            if (code === 3 && !root.overviewWarned) { root.overviewWarned = true; console.log("hush: overview needs the GloView plugin (hyprpm); not loaded, ignoring") }
        }
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

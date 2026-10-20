import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import "modules/island/surfaces" as Surf

// Harness: the Settings surface alone at its declared size on a black pill.
// Run with: qs -p tests/harness/settings.qml   (IPC target "harness-settings")
ShellRoot {
    id: root
    property int wallRequests: 0
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Sizes.settings.width; implicitHeight: Sizes.settings.height
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            Surf.Settings { id: s; anchors.fill: parent; onOpenWallpapers: root.wallRequests++ }
        }
    }
    IpcHandler {
        target: "harness-settings"
        function size(): string { return s.size.width + "x" + s.size.height }
        function page(): string { return s.page }
        function setPage(p: string): void { s.page = p }
        function setWidth(v: int): void { s.commit("width", v) }
        function previewWidth(v: int): void { s.setPreview("width", v) }
        function shownWidth(): int { return s.value("width") }
        function dataWidth(): int { return Settings.data.island.width }
        function version(): string { return s.version }
        function wallRequests(): int { return root.wallRequests }
        // Row titles / switch + slider lookup (walks the surface; pages not shown are still in the tree).
        function walk(it, f) { if (!it) return; f(it); for (let i = 0; i < it.children.length; i++) walk(it.children[i], f) }
        // The hover chips the preview builds, in order ("workspaces,date,...").
        function previewChips(): string { const o = []; walk(s, it => { if (typeof it.objectName === "string" && it.objectName.startsWith("hoverChip_")) o.push(it.objectName.slice(10)) }); return o.join(",") }
        function titles(): string { const o = []; walk(s, it => { if (typeof it.title === "string" && it.title !== "" && it.slot === undefined) o.push(it.title) }); return o.join("|") }
        function rowItem(title: string, member: string): var { let r = null; walk(s, it => { if (r === null && it.title === title) walk(it, c => { if (r === null && c[member] !== undefined && c !== it) r = c }) }); return r }
        function hasSwitch(title: string): bool { return rowItem(title, "toggled") !== null }
        function hasSlider(title: string): bool { return rowItem(title, "cur") !== null }
        function flip(title: string): void { const w = rowItem(title, "toggled"); if (w) w.toggled(!w.on) }
        function slideTo(title: string, v: int): void { s.commit(rowItem(title, "cur").key, v) }
        function previewKey(k: string, v: int): void { s.setPreview(k, v) }
        function shown(k: string): int { return s.value(k) }
        function stepSlider(title: string, n: int): void { const w = rowItem(title, "cur"); walk(w, c => { if (typeof c.stepAdjust === "function") c.stepAdjust(n) }) }
        function dataOf(path: string): string { return String(path.split(".").reduce((o, k) => o[k], Settings.data)) }
        function unitOf(title: string): string { return rowItem(title, "unit").unit }
        // Scrolls the row into view first, as the wheel would.
        function dropOpen(title: string, o: bool): void {
            const d = rowItem(title, "listH"); let f = null; walk(s, it => { if (f === null && it.contentHeight !== undefined && it.flickableDirection !== undefined) f = it })
            if (o && f) f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, d.mapToItem(f.contentItem, 0, 0).y - 100))
            d.open = o
        }
        // Open list of a dropdown row: "top,bottom" in surface coordinates; "closed" when not open.
        function dropBox(title: string): string { const d = rowItem(title, "listH"); return d.open ? Math.round(d.at.y) + "," + Math.round(d.at.y + d.listH) : "closed" }
        function rowTop(title: string): int { let r = null; walk(s, it => { if (r === null && it.title === title && it.visible) r = it }); return Math.round(r.mapToItem(s, 0, 0).y) }
        // Rendered Shortcuts rows ("id,id,.."), in the order of the list.
        function shortcutRows(): string { const o = []; walk(s, it => { if (typeof it.objectName === "string" && it.objectName.indexOf("shortcut_") === 0) o.push(it.objectName.slice(9)) }); return o.join(",") }
        function record(id: string, key: int, mods: int): string { const c = s.comboFrom(key, mods, ""); s.setCombo(id, c); return c }
        function clearKey(id: string): void { s.setCombo(id, "") }
        function textOf(name: string): string { let r = ""; walk(s, it => { if (it.objectName === name) r = it.shown !== undefined ? it.shown : it.text }); return r }
        function pressEsc(): bool { return s.back() }
        function setSection(sec: string): void { s.modulesSection = sec }
        // Rendered composer rows of a section, top to bottom ("id,id,..").
        function rows(sec: string): string {
            const o = []; walk(s, it => { if (it.visible && typeof it.objectName === "string" && it.objectName.indexOf("layoutRow_" + sec + "_") === 0)
                o.push({ id: it.entry.id, y: it.mapToItem(s, 0, 0).y }) })
            return o.sort((a, b) => a.y - b.y).map(e => e.id).join(",")
        }
        function press(key: string): bool { const c = s.controlFor(key); if (!c || !c.enabled) return false; c.clicked(null); return true }
        function enabledOf(key: string): bool { const c = s.controlFor(key); return !!c && c.enabled }
        // The island navigator's Alt/Shift+Up/Down hook, as the island calls it.
        function reorder(key: string, dir: int): string { return s.reorder(s.controlFor(key), dir) }
        function pressNamed(name: string): void { walk(s, it => { if (it.objectName === name) it.clicked() }) }
        function layoutHover(): string { return Composer.hoverShown.join(",") }
        function layoutTiles(): string { return Composer.tilesShown.map(t => t.id + ":" + t.size).join(",") }
        function ccSection(k: string): bool { return Composer.section(k) }
        // Visible MouseAreas on the shown Modules section without an accessible name ("" = none).
        function unnamed(): string {
            const o = []; let page = null
            walk(s, it => { if (it.objectName === "modulesPage") page = it })
            const w = it => { if (!it.visible) return
                if (it.acceptedButtons !== undefined && it.pressAndHoldInterval !== undefined && !(it.Accessible.name)) o.push(String(it.parent))
                for (let i = 0; i < it.children.length; i++) w(it.children[i]) }
            if (page) w(page)
            return o.join("|")
        }
        function controls(): int {
            let n = 0, page = null
            walk(s, it => { if (it.objectName === "modulesPage") page = it })
            const w = it => { if (!it.visible) return; if (it.acceptedButtons !== undefined && it.pressAndHoldInterval !== undefined) n++
                for (let i = 0; i < it.children.length; i++) w(it.children[i]) }
            if (page) w(page)
            return n
        }
    }
}

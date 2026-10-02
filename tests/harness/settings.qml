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
    }
}

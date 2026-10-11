import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.modules.island.surfaces

// Harness: the Launcher surface alone on a black pill near the top. It may grab keyboard focus here
// (in the shell the island window owns the grab). The surface sits in a Loader so reopen() builds it
// fresh, as the island does on every open; HUSH_LAUNCHER_MODE picks the mode it is built in.
// Run with: qs -p tests/harness/launcher.qml   (IPC target "harness-launcher")
ShellRoot {
    id: root
    property string openMode: Quickshell.env("HUSH_LAUNCHER_MODE") || "apps"
    readonly property var lau: ld.item
    // Bring up the Hyprland IPC client first and build the surface 600 ms later: created while the
    // first Hyprland events are still being read, quickshell crashed in endPropertyUpdateGroup
    // (its event-socket handler) about every other start.
    Component.onCompleted: void Hyprland.toplevels
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: true
        margins.top: 60
        implicitWidth: Sizes.launcher.width; implicitHeight: Sizes.launcher.height
        exclusiveZone: 0
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            Loader {
                id: ld
                active: false
                Timer { running: true; interval: 600; onTriggered: ld.active = true }
                anchors.fill: parent
                sourceComponent: Launcher { mode: root.openMode; onClose: win.closed = true }
            }
        }
        property bool closed: false
    }
    function find(it, name) {
        if (!it) return null
        if (it.objectName === name) return it
        for (let i = 0; i < it.children.length; i++) { const r = find(it.children[i], name); if (r) return r }
        return null
    }
    // The visible delegate showing result i, or null.
    function rowAt(i) {
        const list = find(lau, "resultList")
        if (!list) return null
        const kids = list.contentItem.children
        for (let k = 0; k < kids.length; k++) if (kids[k].index === i && kids[k].entry) return kids[k]
        return null
    }
    IpcHandler {
        target: "harness-launcher"
        function setQuery(q: string): void { root.lau.setQuery(q) }
        function setMode(m: string): void { root.lau.mode = m }
        function reopen(m: string): void { root.openMode = m; ld.active = false; ld.active = true }
        function first(): string { return root.lau ? root.lau.firstName : "" }
        function count(): int { return root.lau ? root.lau.count : -1 }
        function mode(): string { return root.lau.effectiveMode }
        function size(): string { return !root.lau ? "" : root.lau.size.width + "x" + root.lau.size.height }
        function wantsKeyboard(): bool { return root.lau.wantsKeyboard }
        function closed(): bool { return win.closed }
        function select(i: int): void { root.lau.currentIndex = i }
        function current(): string { return root.lau.currentName }
        function emptyText(): string { const t = root.find(root.lau, "emptyText"); return t && t.visible ? t.text : "" }
    }
}

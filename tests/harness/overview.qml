import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.modules.island.surfaces

// Harness: the Overview surface alone on a black pill near the top, over the real Hyprland windows.
// HUSH_OVERVIEW_SCREEN names the monitor (default: the focused one).
// Run with: qs -p tests/harness/overview.qml   (IPC target "harness-overview")
ShellRoot {
    id: root
    readonly property var ov: ld.item
    // Same 600 ms delay as the launcher harness: building while the first Hyprland events are read crashed.
    Component.onCompleted: void Hyprland.toplevels
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-overview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.top: true
        margins.top: 60
        implicitWidth: Sizes.overview.width; implicitHeight: Sizes.overview.height
        exclusiveZone: 0
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            Loader {
                id: ld
                active: false
                Timer { running: true; interval: 600; onTriggered: ld.active = true }
                anchors.fill: parent
                sourceComponent: Overview { screenName: Quickshell.env("HUSH_OVERVIEW_SCREEN") || Hypr.focusedMonitorName; onClose: win.closed = true }
            }
        }
        property bool closed: false
    }
    IpcHandler {
        target: "harness-overview"
        function size(): string { return !root.ov ? "" : root.ov.size.width + "x" + root.ov.size.height }
        function shownWorkspace(): int { return root.ov.shownWorkspace }
        function cellCount(): int { return root.ov.cellCount }
        function cellIds(): string { return root.ov.cells.map(c => c.id).join(",") }
        function thumbCount(): int { return root.ov.thumbCount }
        function hoverCell(i: int): void { root.ov.hoverCell(i) }
        function stepShown(d: int): void { root.ov.stepShown(d) }
        function thumbRects(): string {
            const out = []
            for (let i = 0; i < root.ov.thumbCount; i++) { const r = root.ov.thumbRect(i); out.push([r.x, r.y, r.width, r.height].map(Math.round).join(",")) }
            return out.join(";")
        }
        function moveSame(): bool { return root.ov.moveThumb(0, root.ov.shownWorkspace) }
        function closed(): bool { return win.closed }
        function requestClose(): void { root.ov.close() }
    }
}

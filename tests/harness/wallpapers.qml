import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.modules.island.surfaces

// Harness: the Wallpapers surface alone at its declared size on a black pill, near the top.
// Run with: qs -p tests/harness/wallpapers.qml   (IPC target "harness-wallpapers": count, select(i), size, current, last)
ShellRoot {
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-wallpapers"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: true
        margins.top: 440
        implicitWidth: Sizes.wallpapers.width; implicitHeight: Sizes.wallpapers.height
        exclusiveZone: 0
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            Wallpapers { id: wp; anchors.fill: parent; hushBin: "hush"; origin: Qt.point(win.screen.x + (win.screen.width - win.width) / 2, win.screen.y + 440) }
        }
        HyprlandFocusGrab { windows: [win]; active: true }
    }
    IpcHandler {
        target: "harness-wallpapers"
        function count(): int { return wp.count }
        function select(i: int): string { const p = wp.files[i] || ""; wp.pickIndex(i); return p }
        function size(): string { return wp.size.width + "x" + wp.size.height }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.modules.island.surfaces

// Harness: the Launcher surface alone on a black pill near the top. It may grab keyboard focus here
// (in the shell the island window owns the grab).
// Run with: qs -p tests/harness/launcher.qml   (IPC target "harness-launcher")
ShellRoot {
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: lau.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors.top: true
        margins.top: 60
        implicitWidth: Sizes.launcher.width; implicitHeight: Sizes.launcher.height
        exclusiveZone: 0
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            Launcher { id: lau; anchors.fill: parent; onClose: win.closed = true }
        }
        property bool closed: false
    }
    IpcHandler {
        target: "harness-launcher"
        function setQuery(q: string): void { lau.setQuery(q) }
        function setMode(m: string): void { lau.mode = m }
        function first(): string { return lau.firstName }
        function count(): int { return lau.count }
        function mode(): string { return lau.effectiveMode }
        function size(): string { return lau.size.width + "x" + lau.size.height }
        function wantsKeyboard(): bool { return lau.wantsKeyboard }
        function closed(): bool { return win.closed }
    }
}

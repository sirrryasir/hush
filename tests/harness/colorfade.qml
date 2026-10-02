import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config

// Harness: a 120x120 swatch painted with Colors.primary. Run with HOME pointing at a scratch dir
// holding .config/hush/Colors.json. IPC target "harness-colorfade".
ShellRoot {
    id: root
    property double started: 0
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-colorfade"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 100
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 120; implicitHeight: 120
        color: "transparent"
        Rectangle { anchors.fill: parent; color: Colors.primary }
    }
    Connections {
        target: Colors
        function onPrimaryChanged() { if (Colors.loaded && root.started === 0) root.started = Date.now() }
    }
    IpcHandler {
        target: "harness-colorfade"
        function primary(): string { return Colors.primary.toString() }
        function loaded(): bool { return Colors.loaded }
        function fadeMs(): int { return Colors.fadeMs }
        function started(): string { return String(root.started) }
        function rearm(): void { root.started = 0 }
    }
}

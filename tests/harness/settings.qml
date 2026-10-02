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
    }
}

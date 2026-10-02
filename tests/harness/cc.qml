import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.services as Svc
import "modules/island/surfaces"

// Harness for the control-center surface: one top-anchored layer window with the surface on a black
// pill shape. Drive it with: qs -p tests/harness/cc.qml ipc call cc <fn>   (HUSH_ROOT must be set).
ShellRoot {
    id: root
    property int wallRequests: 0
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-cc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 560; implicitHeight: 320
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            ControlCenter { id: cc; anchors.fill: parent; onOpenWallpapers: root.wallRequests++ }
        }
    }
    IpcHandler {
        target: "cc"
        function page(): string { return cc.page }
        function openWifi(): void { cc.openWifi() }
        function openBluetooth(): void { cc.openBluetooth() }
        function back(): bool { return cc.back() }
        function networkCount(): int { return Svc.Net.networks.length }
        function scanning(): bool { return Svc.Net.scanning }
        function wallRequests(): int { return root.wallRequests }
        function pressWallpapers(): void { cc.openWallpapers() }
    }
}

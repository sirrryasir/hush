import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.services
import "modules/island"
import "modules/island/states"
import "modules/island/rest"

// Harness: Devices, DeviceRegistrar and DeviceState on a black pill, with a real Arbiter standing in for
// the island (Ipc.island points at it) and a fake udisksctl on PATH. Run: qs -p tests/harness/device.qml
ShellRoot {
    Item {
        id: isl
        property var arbiter: arb
        readonly property var payload: arb.payload
        property color fg: "#e6e6e6"
        function register(name, comp) {}
        Arbiter { id: arb; Component.onCompleted: declare("device", Priorities.notification, { holdMs: Theme.notificationHoldMs }) }
        DeviceRegistrar { island: isl }
        Component.onCompleted: Ipc.registerIsland("harness", isl)
    }
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-device"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Sizes.notification.width + 40; implicitHeight: Sizes.notificationTall.height + 24
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent; width: Sizes.notification.width; height: Sizes.notificationTall.height
            radius: height / 2; color: "#000000"; visible: arb.current === "device"
            DeviceState { id: card; island: isl }
        }
    }
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-device-ring"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 160
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 120; implicitHeight: 40
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent; width: 80; height: 36; radius: 18; color: "#000000"
            StatusRing { id: ring; anchors.centerIn: parent }
        }
    }
    IpcHandler {
        target: "harness-device"
        // The glyph is on screen: the ring is visible and has width (not just the model flag).
        function usb(): bool { return ring.usb && ring.visible && ring.width > 0 }
        function names(): string { return Devices.list.map(d => d.name).join("|") }
        function current(): string { return arb.current }
        function title(): string { return card.title }
        function sub(): string { return card.sub }
        function buttons(): string { return [card.mountBtn, card.openBtn, card.ejectBtn].filter(b => b.visible).map(b => b.text || b.glyph).join(",") }
        function press(which: string): void { card[which + "Btn"].clicked() }
    }
}

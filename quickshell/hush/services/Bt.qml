pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    readonly property bool enabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property string connectedName: ""
    readonly property string icon: !enabled ? "bluetooth_disabled" : connectedName !== "" ? "bluetooth_connected" : "bluetooth"

    function refresh() {
        let n = "";
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < devs.length; i++) if (devs[i].connected) { n = devs[i].name; break; }
        root.connectedName = n;
    }
    Component.onCompleted: refresh()
    Connections { target: Bluetooth.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

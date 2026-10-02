pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    readonly property bool enabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property string connectedName: ""
    readonly property string icon: !enabled ? "bluetooth_disabled" : connectedName !== "" ? "bluetooth_connected" : "bluetooth"

    // Paired and nearby devices for the control center: [{name, connected, paired, dev}], connected first.
    property var devices: []
    function list() {
        const out = [], devs = Bluetooth.devices ? Bluetooth.devices.values : []
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (!d.name) continue
            out.push({ name: d.name, connected: d.connected, paired: d.paired, dev: d })
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        root.devices = out
    }
    function scan() { const a = Bluetooth.defaultAdapter; if (a && a.enabled) a.discovering = true; list() }
    function stopScan() { const a = Bluetooth.defaultAdapter; if (a && a.discovering) a.discovering = false }
    function toggleDevice(d) { if (d.connected) d.disconnect(); else d.connect() }

    function refresh() {
        let n = "";
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < devs.length; i++) if (devs[i].connected) { n = devs[i].name; break; }
        root.connectedName = n; list();
    }
    Component.onCompleted: refresh()
    Connections { target: Bluetooth.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

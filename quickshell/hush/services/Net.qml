pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    property bool wifi: false
    property bool connected: false
    property string ssid: ""
    property real strength: 0
    readonly property string icon: {
        if (!connected) return "signal_wifi_off";
        if (!wifi) return "lan";
        return strength > 0.66 ? "wifi" : strength > 0.33 ? "wifi_2_bar" : "wifi_1_bar";
    }

    function refresh() {
        let conn = false, isWifi = false, name = "", str = 0;
        const devs = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i];
            if (!d.connected) continue;
            if (d.type === DeviceType.Wifi) {
                const nets = d.networks ? d.networks.values : [];
                for (let j = 0; j < nets.length; j++) {
                    if (nets[j].connected) { conn = true; isWifi = true; name = nets[j].name; str = nets[j].signalStrength; break; }
                }
                if (isWifi) break;
            } else if (d.type === DeviceType.Wired) {
                conn = true; isWifi = false; name = d.name;
            }
        }
        root.connected = conn; root.wifi = isWifi; root.ssid = name; root.strength = str;
    }

    Component.onCompleted: refresh()
    Connections { target: Networking.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

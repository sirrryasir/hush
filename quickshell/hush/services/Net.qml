pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

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

    // Wi-Fi list for the control center: [{ssid, signal 0..100, secure, active}], strongest first.
    property var networks: []
    property bool scanning: false
    property string lastError: ""
    function splitNmcli(line) {
        const out = []; let cur = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (c === ":") { out.push(cur); cur = ""; continue }
            cur += c
        }
        out.push(cur); return out
    }
    function scan() {
        if (scanning) return
        scanning = true
        lister.running = true
    }
    function connect(ssid) {
        lastError = ""
        connector.command = ["nmcli", "--wait", "15", "dev", "wifi", "connect", ssid]
        connector.running = true
    }
    Process {
        id: lister
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, list = []
                for (const line of text.split("\n")) {
                    if (!line) continue
                    const f = root.splitNmcli(line)
                    if (f.length < 4 || f[1] === "" || seen[f[1]]) continue
                    seen[f[1]] = true
                    list.push({ ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--", active: f[0] === "*" })
                }
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                root.networks = list; root.scanning = false
            }
        }
        onExited: root.scanning = false
    }
    Process {
        id: connector
        stderr: StdioCollector { onStreamFinished: root.lastError = text.trim() }
        onExited: { root.refresh(); root.scan() }
    }

    Component.onCompleted: refresh()
    Connections { target: Networking.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

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

    // Wi-Fi list for the control center: [{ssid, signal 0..100, secure, security ("WPA2"), band
    // ("5 GHz"), active}], strongest first.
    property var networks: []
    property bool scanning: false
    // Saved Wi-Fi profiles by name (NetworkManager names a profile after its SSID) -> profile uuid.
    property var saved: ({})
    // IPv4 address of the Wi-Fi device ("" when none).
    property string ip4: ""
    // The "Hotspot" profile nmcli creates is active.
    property bool hotspot: false
    // VPN and WireGuard profiles: [{name, uuid, active}]; vpnActive is the first active one's name.
    property var vpns: []
    readonly property string vpnActive: { const v = vpns.find(x => x.active); return v ? v.name : "" }
    // The SSID a connect() is running for, the SSID the last failure belongs to and its message
    // (shown inline under that network's row; Hush never raises a notification for it).
    property string connecting: ""
    property string errorSsid: ""
    property string lastError: ""
    property string lastAction: ""
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
        if (!profiles.running) profiles.running = true
        if (scanning) return
        scanning = true
        lister.running = true
        addr.running = true
    }
    // A secured network with no saved profile needs a password before it can join.
    function needsPassword(ssid) {
        const n = networks.find(x => x.ssid === ssid)
        return !!n && n.secure && !saved[ssid]
    }
    // Joins ssid (password only for a network without a saved profile; `hidden` for one that does not
    // broadcast). A failed first join with a password leaves no half-made profile behind: nmcli
    // creates one even when the key is wrong.
    function connect(ssid, password, hidden) {
        if (connector.running) return
        lastError = ""; errorSsid = ""; connecting = ssid
        const pw = password || ""
        const fresh = !saved[ssid]
        lastAction = pw ? "connect-password" : "connect"
        connector.command = ["sh", "-c",
            "if [ -n \"$2\" ]; then nmcli --wait 20 dev wifi connect \"$1\" password \"$2\" $4; else nmcli --wait 20 dev wifi connect \"$1\" $4; fi 2>&1; rc=$?; "
            + "if [ $rc -ne 0 ] && [ -n \"$2\" ] && [ \"$3\" = 1 ]; then nmcli connection delete id \"$1\" >/dev/null 2>&1; fi; echo \"::$rc\"",
            "sh", ssid, pw, fresh ? "1" : "0", hidden ? "hidden yes" : ""]
        connector.running = true
    }
    // Deletes the saved profile of ssid (NetworkManager drops the connection when it is active).
    function forget(ssid) {
        if (!saved[ssid] || acter.running) return
        acter.command = ["nmcli", "connection", "delete", "uuid", saved[ssid]]
        acter.running = true
    }
    // `nmcli dev wifi hotspot` makes (or reuses) the "Hotspot" profile with a generated key.
    function toggleHotspot() {
        if (acter.running) return
        acter.command = hotspot ? ["nmcli", "connection", "down", "Hotspot"] : ["nmcli", "dev", "wifi", "hotspot"]
        acter.running = true
    }
    function toggleVpn(v) {
        if (acter.running) return
        acter.command = ["nmcli", "connection", v.active ? "down" : "up", "uuid", v.uuid]
        acter.running = true
    }
    // Drops the active Wi-Fi connection (the profile stays saved).
    function disconnect() {
        lastError = ""; errorSsid = ""; lastAction = "disconnect"
        disconnector.running = true
    }
    // nmcli's message without the "Error: " prefix, on one line.
    function cleanError(t) {
        t = t.replace(/^Error:\s*/i, "").replace(/\s+/g, " ").trim()
        if (/secrets were required|802-1x|password/i.test(t)) return "Wrong password or the network refused it"
        return t || "Could not connect"
    }
    Process {
        id: lister
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,FREQ", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, list = []
                for (const line of text.split("\n")) {
                    if (!line) continue
                    const f = root.splitNmcli(line)
                    if (f.length < 4 || f[1] === "") continue
                    const mhz = parseInt(f[4]) || 0
                    const n = { ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--", security: f[3] === "--" ? "" : f[3],
                        band: mhz >= 5925 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : "2.4 GHz", active: f[0] === "*" }
                    const i = seen[f[1]]
                    // Same SSID on several access points: the joined one wins, else the strongest.
                    if (i !== undefined) {
                        if (n.active || (!list[i].active && n.signal > list[i].signal)) { list[i].signal = n.signal; list[i].band = n.band }
                        if (n.active) list[i].active = true
                        continue
                    }
                    seen[f[1]] = list.length
                    list.push(n)
                }
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                root.networks = list; root.scanning = false
            }
        }
        onExited: root.scanning = false
    }
    Process {
        id: profiles
        command: ["nmcli", "-t", "-f", "NAME,TYPE,UUID,DEVICE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}, v = []; let hs = false
                for (const line of text.split("\n")) {
                    const f = root.splitNmcli(line)
                    if (f.length < 4 || !f[0]) continue
                    if (f[1] === "802-11-wireless") { m[f[0]] = f[2]; if (f[0] === "Hotspot" && f[3] !== "") hs = true }
                    else if (f[1] === "vpn" || f[1] === "wireguard") v.push({ name: f[0], uuid: f[2], active: f[3] !== "" })
                }
                root.saved = m; root.hotspot = hs; root.vpns = v
            }
        }
    }
    Process {
        id: addr
        command: ["nmcli", "-t", "-f", "GENERAL.TYPE,IP4.ADDRESS", "dev", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let ip = "", wifi = false
                for (const line of text.split("\n")) {
                    const f = root.splitNmcli(line)
                    if (f[0] === "GENERAL.TYPE") wifi = f[1] === "wifi"
                    else if (wifi && !ip && f[0] === "IP4.ADDRESS[1]") ip = (f[1] || "").split("/")[0]
                }
                root.ip4 = ip
            }
        }
    }
    // One nmcli action at a time (forget, hotspot, VPN up or down); the lists refresh after it.
    Process {
        id: acter
        onExited: { root.refresh(); root.scan() }
    }
    Process {
        id: connector
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /::(\d+)\s*$/.exec(text)
                const rc = m ? parseInt(m[1]) : 1
                const ssid = root.connecting
                if (rc !== 0) { root.errorSsid = ssid; root.lastError = root.cleanError(text.replace(/::\d+\s*$/, "")) }
                root.connecting = ""
                root.refresh(); profiles.running = true; root.scan()
            }
        }
    }
    Process {
        id: disconnector
        command: ["sh", "-c", "nmcli -t -f UUID,TYPE connection show --active | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] && nmcli connection down uuid \"$u\"; done >/dev/null 2>&1; exit 0"]
        onExited: { root.refresh(); root.scan() }
    }

    // Re-reads the profiles (saved networks, hotspot, VPNs); the control center calls it when it opens.
    function poll() { if (!profiles.running) profiles.running = true }

    Component.onCompleted: { refresh(); poll() }
    Connections { target: Networking.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

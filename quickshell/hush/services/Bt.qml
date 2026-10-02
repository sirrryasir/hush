pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth state for the island. An rfkill soft block makes bluez drop the adapter (or report it
// Blocked), so toggle() lifts the block with `rfkill unblock bluetooth` and powers the adapter once
// it is back. Turning off only powers the adapter down; Hush never sets an rfkill block itself.
Singleton {
    id: root
    // Tests set HUSH_BT_NO_ADAPTER=1 to exercise the missing-adapter (rfkill) path.
    readonly property bool fakeMissing: Quickshell.env("HUSH_BT_NO_ADAPTER") === "1"
    readonly property var adapter: fakeMissing ? null : Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    // A bluetooth rfkill switch is soft or hard blocked (from `rfkill -J`).
    property bool rfkillBlocked: false
    readonly property bool blocked: rfkillBlocked || !adapter || adapter.state === BluetoothAdapterState.Blocked
    // toggle() asked for "on" and is waiting for the adapter to come back (5 s budget).
    property bool pending: false
    property string connectedName: ""
    readonly property string icon: !enabled ? "bluetooth_disabled" : connectedName !== "" ? "bluetooth_connected" : "bluetooth"
    readonly property string subtitle: pending ? "Turning on" : enabled ? (connectedName !== "" ? "On · " + connectedName : "On")
        : rfkillBlocked ? "Blocked by rfkill" : !adapter ? "No adapter" : "Off"

    function toggle() {
        if (enabled) { adapter.enabled = false; pending = false; return }
        if (adapter && !blocked) { adapter.enabled = true; return }
        pending = true; tries = 0
        unblock.running = true
        retry.restart()
    }
    // Powers the adapter once it is back and settled (bluez answers Busy to a write while the
    // adapter is still coming up, and may power it by itself); true when it is on.
    function finishOn() {
        const a = root.adapter
        if (!a) return false
        if (a.state === BluetoothAdapterState.Enabled) return true
        // One write ~0.5 s after the adapter returns, one retry ~2.5 s later.
        if (a.state === BluetoothAdapterState.Disabled && (root.tries === 2 || root.tries === 10)) a.enabled = true
        return false
    }
    property int tries: 0
    Timer {
        id: retry; interval: 250; repeat: true
        onTriggered: {
            if (root.finishOn() || ++root.tries >= 20) { root.pending = false; stop(); root.probe() }
        }
    }
    Process {
        id: unblock
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: code => { if (code !== 0) console.log("hush: rfkill unblock bluetooth exited " + code); root.probe() }
    }
    function probe() { if (!rfkillProc.running) rfkillProc.running = true }
    Process {
        id: rfkillProc
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                let b = false
                try {
                    const j = JSON.parse(text), devs = j[""] || j.rfkilldevices || []
                    for (const d of devs) if (d.type === "bluetooth" && (d.soft === "blocked" || d.hard === "blocked")) b = true
                } catch (e) { b = false }
                root.rfkillBlocked = b
            }
        }
    }
    onAdapterChanged: probe()

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
    function scan() { const a = root.adapter; if (a && a.enabled) a.discovering = true; list() }
    function stopScan() { const a = root.adapter; if (a && a.discovering) a.discovering = false }
    function toggleDevice(d) { if (d.connected) d.disconnect(); else d.connect() }

    function refresh() {
        let n = "";
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < devs.length; i++) if (devs[i].connected) { n = devs[i].name; break; }
        root.connectedName = n; list();
        // Re-read rfkill only while something looks blocked (an external `rfkill block` drops the adapter).
        if (root.blocked) probe()
    }
    Component.onCompleted: { refresh(); probe() }
    Connections { target: Bluetooth.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

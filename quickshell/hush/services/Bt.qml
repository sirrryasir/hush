pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "BtAudio.js" as BtAudio

// Bluetooth state for the island. An rfkill soft block makes bluez drop the adapter (or report it
// Blocked), so toggle() lifts the block with `rfkill unblock bluetooth` and powers the adapter once
// it is back. Turning off only powers the adapter down; Hush never sets an rfkill block itself.
Singleton {
    id: root
    // Tests set HUSH_BT_NO_ADAPTER=1 to exercise the missing-adapter (rfkill) path.
    readonly property bool fakeMissing: Quickshell.env("HUSH_BT_NO_ADAPTER") === "1"
    // Tests set HUSH_BT_FAKE=1: a powered fake radio with three stand-in devices whose actions only
    // log (fakeLog), so the device page can be driven without hardware.
    readonly property bool fake: Quickshell.env("HUSH_BT_FAKE") === "1"
    readonly property var adapter: fakeMissing || fake ? null : Bluetooth.defaultAdapter
    readonly property bool enabled: fake ? true : adapter ? adapter.enabled : false
    // Inquiry running (the device page shows a spinner and "Searching").
    property bool fakeDiscovering: false
    readonly property bool discovering: fake ? fakeDiscovering : !!(adapter && adapter.discovering)
    // A bluetooth rfkill switch is soft or hard blocked (Rfkill reads `rfkill -J`).
    readonly property bool rfkillBlocked: Rfkill.bluetooth
    readonly property bool blocked: fake ? false : rfkillBlocked || !adapter || adapter.state === BluetoothAdapterState.Blocked
    // toggle() asked for "on" and is waiting for the adapter to come back (5 s budget).
    property bool pending: false
    property string connectedName: ""
    readonly property string icon: !enabled ? "bluetooth_disabled" : connectedName !== "" ? "bluetooth_connected" : "bluetooth"
    readonly property string subtitle: pending ? "Turning on" : enabled ? (connectedName !== "" ? "On · " + connectedName : "On")
        : rfkillBlocked ? "Blocked by rfkill" : !adapter ? "No adapter" : "Off"

    function toggle() {
        if (fake) return
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
    function probe() { Rfkill.probe() }
    onAdapterChanged: probe()

    // Paired and nearby devices for the control center, connected first, then paired, then the rest:
    // [{name, address, connected, paired, busy, battery (0..100 or -1), dev}]. Unnamed nearby
    // devices (bare addresses) are left out; paired ones always show.
    property var devices: []
    // Addresses PipeWire has a bluez sink or source for ("bluez_output.F9_EB_...", "bluez_input.F9:EB:..").
    // Kernel 7.x skips the "device connected" event on a headset's own reconnect, so bluez keeps
    // Device1.Connected false while audio streams (bluez#2485, closed unfixed); PipeWire knows better.
    readonly property var audioAddrs: Pipewire.nodes.values.map(n => BtAudio.addr(n.name)).filter(a => a)
    function isConnected(d) { return !!d && (d.connected || audioAddrs.indexOf((d.address || "").toUpperCase()) >= 0) }
    function sourceDevices() { return fake ? fakeDevices : (Bluetooth.devices ? Bluetooth.devices.values : []) }
    function list() {
        const out = [], devs = sourceDevices()
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            const named = d.name && d.name.replace(/[-:]/g, "") !== (d.address || "").replace(/:/g, "")
            if (!named && !d.paired) continue
            out.push({
                name: d.name || d.address, address: d.address || "", connected: isConnected(d), paired: d.paired,
                busy: !!d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting,
                battery: isConnected(d) && d.batteryAvailable ? Math.round(d.battery * 100) : -1,
                dev: d
            })
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        root.devices = out
    }
    function scan() {
        if (fake) { fakeDiscovering = true; fakeScanEnd.restart(); list(); return }
        const a = root.adapter; if (a && a.enabled) a.discovering = true; list()
    }
    function stopScan() {
        if (fake) { fakeDiscovering = false; return }
        const a = root.adapter; if (a && a.discovering) a.discovering = false
    }
    // Row actions. Pairing trusts the device and connects it once bluez reports it paired.
    // Connect trusts too: without a trusted flag bluez asks an agent to authorise each profile,
    // and Hush runs none (Quickshell has no agent API), so an untrusted headset is rejected.
    function connectDevice(d) { if (!d) return; try { d.trusted = true } catch (e) {} d.connect(); later.restart() }
    function disconnectDevice(d) { if (d) d.disconnect(); later.restart() }
    function pairDevice(d) {
        if (!d) return
        try { d.trusted = true } catch (e) {}
        d.pair()
        pairWatch.dev = d; pairWatch.restart()
        later.restart()
    }
    function forgetDevice(d) { if (d) d.forget(); later.restart() }
    function toggleDevice(d) { if (isConnected(d)) disconnectDevice(d); else if (d.paired) connectDevice(d); else pairDevice(d) }
    Timer { id: later; interval: 300; onTriggered: root.list() }
    Timer {
        id: pairWatch; interval: 500; repeat: true
        property var dev: null
        property int n: 0
        onRunningChanged: if (running) n = 0
        onTriggered: {
            if (!dev || ++n > 60) { stop(); return }
            if (dev.paired && !dev.pairing) { stop(); if (!dev.connected) dev.connect(); root.list() }
        }
    }

    // --- fake radio (HUSH_BT_FAKE=1) ---
    property var fakeLog: []
    property var fakeDevices: []
    function fakeAct(dev, what) { fakeLog = fakeLog.concat([what + " " + dev.name]) }
    Timer { id: fakeScanEnd; interval: 4000; onTriggered: root.fakeDiscovering = false }
    Component {
        id: fakeComp
        QtObject {
            property string name
            property string address
            property bool connected
            property bool paired
            property bool pairing: false
            property bool trusted: false
            property bool batteryAvailable: false
            property real battery: 0
            property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected
            function connect() { root.fakeAct(this, "connect"); connected = true; root.refresh() }
            function disconnect() { root.fakeAct(this, "disconnect"); connected = false; root.refresh() }
            function pair() { root.fakeAct(this, "pair"); paired = true; root.refresh() }
            function forget() {
                root.fakeAct(this, "forget"); paired = false; connected = false
                root.fakeDevices = root.fakeDevices.filter(x => x !== this); root.refresh()
            }
        }
    }
    function makeFakes() {
        fakeDevices = [
            fakeComp.createObject(root, { name: "Fake Buds", address: "AA:00:00:00:00:01", connected: true, paired: true, batteryAvailable: true, battery: 0.8 }),
            fakeComp.createObject(root, { name: "Fake Keyboard", address: "AA:00:00:00:00:02", connected: false, paired: true }),
            fakeComp.createObject(root, { name: "Fake Speaker", address: "AA:00:00:00:00:03", connected: false, paired: false })
        ]
    }

    function refresh() {
        let n = "";
        const devs = sourceDevices();
        for (let i = 0; i < devs.length; i++) if (isConnected(devs[i])) { n = devs[i].name; break; }
        root.connectedName = n; list();
        // Re-read rfkill only while something looks blocked (an external `rfkill block` drops the adapter).
        if (root.blocked && !root.fake) probe()
    }
    Component.onCompleted: { if (fake) makeFakes(); refresh(); if (!fake) probe() }
    Connections { target: Bluetooth.devices; function onValuesChanged() { root.refresh() } }
    onAudioAddrsChanged: refresh()
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
}

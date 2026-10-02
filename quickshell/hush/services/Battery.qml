pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    readonly property var dev: UPower.displayDevice
    // UPowerDevice.percentage is a 0..1 fraction (energy / energyCapacity); verified live: 0.8 at 80%.
    readonly property bool present: dev && dev.ready && dev.isPresent && dev.isLaptopBattery ? true : false
    readonly property int percent: present ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: dev ? (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged) : false
    readonly property string icon: {
        if (charging) return "battery_charging_full";
        const bars = Math.max(0, Math.min(6, Math.round(percent / 100 * 6)));
        return bars >= 6 ? "battery_full" : "battery_" + bars + "_bar";
    }
    // Charging right now (the bolt); `charging` above also counts a full battery on the cable.
    readonly property bool chargingNow: dev ? dev.state === UPowerDeviceState.Charging : false
    // "Charging", "Fully charged", "Not charging" (held at a charge threshold) or "On battery".
    readonly property string stateText: {
        if (!present) return ""
        switch (dev.state) {
        case UPowerDeviceState.Charging: return "Charging"
        case UPowerDeviceState.FullyCharged: return "Fully charged"
        case UPowerDeviceState.PendingCharge: return "Not charging"
        default: return "On battery"
        }
    }
    // True for 2 s after the state changes to charging (the island shows the bolt).
    property bool justPlugged: false
    property int _state: dev ? dev.state : 0
    on_StateChanged: {
        if (_state === UPowerDeviceState.Charging && _prev !== 0) { justPlugged = true; plugTimer.restart() }
        else if (_state !== UPowerDeviceState.Charging) { justPlugged = false; plugTimer.stop() }
        _prev = _state
    }
    property int _prev: 0
    Timer { id: plugTimer; interval: 2000; onTriggered: root.justPlugged = false }
}

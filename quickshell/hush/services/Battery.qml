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
}

import QtQuick
import qs.services

// Registers the device state and raises it on the driven island: when a removable drive appears
// (5 s hold, paused while hovered; the arbiter queues it behind a surface) and, after an eject, the
// "Safe to remove" card.
Item {
    id: reg
    property var island: null
    readonly property bool driven: island !== null && island === Ipc.island

    Component { id: comp; DeviceState { island: reg.island } }
    onIslandChanged: if (island) island.register("device", comp)

    Connections {
        target: Devices
        function onArrived(d) { if (reg.driven) reg.island.arbiter.raise("device", { key: d.dev, dev: d.dev }) }
        function onEjected(name) { if (reg.driven) reg.island.arbiter.raise("device", { key: "safe", safe: name }) }
    }
}

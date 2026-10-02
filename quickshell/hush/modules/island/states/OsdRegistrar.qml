import QtQuick
import qs.config
import qs.services

// Registers the osd state and turns service change signals into arbiter raises on the driven island.
// Every kind shares one key, so a burst of changes (volume, then brightness) coalesces into one OSD
// whose 1100 ms hold re-times from the last change.
Item {
    id: reg
    property var island: null
    property string kind: "volume"
    function show(k) {
        if (!island || island !== Ipc.island) return
        kind = k
        island.arbiter.raise("osd", { key: "osd", kind: k })
    }

    Component { id: osdComp; Osd { kind: reg.kind; island: reg.island } }
    onIslandChanged: if (island) island.register("osd", osdComp)
    Connections { target: Audio; function onChanged(kind) { reg.show(kind) } }
    Connections { target: Brightness; function onChanged(kind) { reg.show(kind) } }
}

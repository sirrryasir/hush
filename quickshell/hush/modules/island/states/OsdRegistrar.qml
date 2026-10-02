import QtQuick
import qs.config
import qs.services

// Registers the osd state and turns service change signals into island requests.
// Repeated changes re-request osd, which restarts the hold timer.
Item {
    id: reg
    property var island: null
    property string kind: "volume"
    function show(k) { kind = k; if (island && island === Ipc.island) island.request("osd", 2, Theme.osdHoldMs) }

    Component { id: osdComp; Osd { kind: reg.kind; island: reg.island } }
    onIslandChanged: if (island) island.register("osd", osdComp)
    Connections { target: Audio; function onChanged(kind) { reg.show(kind) } }
    Connections { target: Brightness; function onChanged(kind) { reg.show(kind) } }
}

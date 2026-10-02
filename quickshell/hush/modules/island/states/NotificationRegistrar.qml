import QtQuick
import qs.services

// Registers the notification state and mirrors Notifs.current onto this island.
// The hold timer lives in Notifs, so the island request holds until released.
Item {
    id: reg
    property var island: null

    Component { id: notifComp; NotifState { island: reg.island } }

    function sync() {
        if (!island) return
        Notifs.current && island === Ipc.island ? island.request("notification", 3, 0) : island.release("notification")
    }
    onIslandChanged: if (island) { island.register("notification", notifComp); sync() }

    Connections { target: Ipc; function onIslandChanged() { reg.sync() } }
    Connections { target: Notifs; function onCurrentChanged() { reg.sync() } }
    // A higher state (the control center) replaces the card outright; re-show it on return.
    Connections {
        target: reg.island
        function onStateChanged() { if (reg.island.state === "rest" && Notifs.current && reg.island === Ipc.island) reg.sync() }
    }
}

import QtQuick
import Quickshell.Services.Notifications
import qs.services

// Registers the notification state and feeds Notifs' toasts to the driven island's arbiter, one
// keyed entry per notification (key = id): "critical" (sticky) for critical urgency, else
// "notification" (5 s hold, paused while hovered). The arbiter queues them; when one ends for good
// (timed out, acted on, lowered) Notifs drops it from its toasts. Only the island on the focused
// monitor shows toasts: when that role moves, the old island lowers them and the new one raises them.
Item {
    id: reg
    property var island: null
    readonly property bool driven: island !== null && island === Ipc.island
    property bool moving: false

    Component { id: notifComp; NotifState { island: reg.island } }

    function nameOf(n) { return n.urgency === NotificationUrgency.Critical ? "critical" : "notification" }
    function raise(n) { if (driven && n) island.arbiter.raise(nameOf(n), { key: n.id, n: n }) }
    function lowerAll() {
        if (!island) return
        moving = true
        island.arbiter.lower("notification"); island.arbiter.lower("critical")
        moving = false
    }
    function sync() { if (driven) for (const n of Notifs.toasts) raise(n); else lowerAll() }

    onIslandChanged: if (island) { island.register("notification", notifComp); sync() }
    onDrivenChanged: sync()

    Connections {
        target: Notifs
        function onToast(n) { reg.raise(n) }
        function onUntoast(id) { if (reg.island) { reg.moving = true; reg.island.arbiter.lower("notification", id); reg.island.arbiter.lower("critical", id); reg.moving = false } }
        function onToastsCleared() { reg.lowerAll() }
    }
    Connections {
        target: reg.island ? reg.island.arbiter : null
        function onEnded(name, payload) {
            if (reg.moving || (name !== "notification" && name !== "critical") || !payload || !payload.n) return
            Notifs.toastDone(payload.n)
        }
    }
}

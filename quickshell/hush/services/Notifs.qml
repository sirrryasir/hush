pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// The notification daemon. Incoming notifications land in `list` (newest first, what the
// drawer shows) and in `queue`; `pump()` moves one at a time into `current`, which every
// island's NotificationRegistrar mirrors as the "notification" state. A storm therefore
// queues here and the island only ever shows one card.
Singleton {
    id: root
    property var list: []
    property var queue: []
    property var current: null
    property int unread: 0
    property bool dnd: false
    readonly property int count: list.length

    NotificationServer {
        id: server
        bodySupported: true; actionsSupported: true; imageSupported: true
        persistenceSupported: true; keepOnReload: true
        onNotification: n => {
            n.tracked = true
            if (root.list.indexOf(n) < 0 && !n.transient) {
                root.list = [n].concat(root.list)
                n.closed.connect(() => root.forget(n))
            } else if (n.transient) {
                n.closed.connect(() => root.forget(n))
            }
            // Carried over from before a reload: keep it in the drawer, do not pop it again.
            if (n.lastGeneration) return
            if (!(Ipc.drawer && Ipc.drawer.open)) root.unread++
            if (root.dnd) { if (n.transient) n.expire(); return }
            if (n === root.current) { holdTimer.restart(); return }
            if (root.queue.indexOf(n) < 0) root.queue = root.queue.concat([n])
            root.pump()
        }
    }

    // Show the next queued notification if nothing is showing.
    function pump() {
        if (current || dnd || !queue.length) return
        const q = queue.slice(); const n = q.shift(); queue = q
        current = n
        holdTimer.restart()
    }
    // The hold ran out (or the card was acted on): clear the island, then show the next.
    function next() {
        const n = current
        holdTimer.stop()
        current = null
        if (n && n.transient) n.expire()
        pump()
    }
    // Hovering the island card pauses the hold; leaving restarts it.
    function hold(paused) { if (!current) return; paused ? holdTimer.stop() : holdTimer.restart() }
    function dismiss(n) { if (n) n.dismiss() }
    function clearAll() {
        queue = []
        const all = list.slice()
        if (current && all.indexOf(current) < 0) all.push(current)
        next()
        for (const n of all) n.dismiss()
        list = []
        unread = 0
    }
    function markSeen() { unread = 0 }
    // Called from a notification's closed signal, before the object is destroyed.
    function forget(n) {
        list = list.filter(x => x !== n)
        queue = queue.filter(x => x !== n)
        if (current === n) { holdTimer.stop(); current = null; pump() }
    }
    function invokeDefault(n) {
        if (!n) return false
        const a = n.actions.find(x => x.identifier === "default")
        if (!a) return false
        a.invoke()
        return true
    }
    function iconSource(n) {
        if (!n) return ""
        const i = n.appIcon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.startsWith("file://") || i.startsWith("image://")) return i
        if (i) { const p = Quickshell.iconPath(i, true); if (p) return p }
        if (n.image) return n.image
        // No icon sent (plain notify-send): try the app name as an icon theme name.
        return n.appName ? Quickshell.iconPath(n.appName.toLowerCase(), true) : ""
    }

    onDndChanged: if (!dnd) pump()

    Timer { id: holdTimer; interval: Theme.notificationHoldMs; onTriggered: root.next() }

    IpcHandler {
        target: "notifs"
        function islandHeight(): int { return Ipc.island ? Math.round(Ipc.island.height) : 0 }
        function islandWidth(): int { return Ipc.island ? Math.round(Ipc.island.width) : 0 }
        function queued(): int { return root.queue.length }
        function count(): int { return root.list.length }
        function current(): string { return root.current ? root.current.summary : "" }
        function toggleDnd(): bool { root.dnd = !root.dnd; return root.dnd }
        function dndOn(): bool { return root.dnd }
    }
}

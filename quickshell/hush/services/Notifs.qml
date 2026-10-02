pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// The notification daemon. Incoming notifications land in `list` (newest first, what the
// notification center shows) and in `toasts` (waiting for, or showing on, the island). Each toast
// is raised on the driven island's Arbiter by NotificationRegistrar, which queues them one at a time
// (5 s hold, paused on hover; critical ones sticky) and calls toastDone() when one ends.
//
// Ownership: org.freedesktop.Notifications is probed first; when another daemon holds it, Hush stays
// `passive` (no server, the settings surface says so) and re-probes every 15 s to take over once free.
Singleton {
    id: root
    property var list: []
    property var toasts: []
    property int unread: 0
    property bool dnd: false
    // True while another process owns the notifications bus name.
    property bool passive: false
    property bool probed: false
    readonly property int count: list.length
    // The toast on the driven island right now, or null.
    readonly property var current: {
        const isl = Ipc.island
        if (!isl || (isl.arbiter.current !== "notification" && isl.arbiter.current !== "critical")) return null
        return isl.arbiter.payload.n || null
    }

    signal toast(var n)
    signal untoast(int id)
    signal toastsCleared()

    // Owner pid of the bus name (if any) and our own pid (the shell is the probe's parent).
    Process {
        id: probe
        command: ["sh", "-c", "echo \"$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^PID=//p') $PPID\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                const owner = p.length > 1 ? p[0] : ""
                const me = p[p.length - 1]
                root.passive = owner !== "" && owner !== me
                if (root.passive && !root.probed) console.log("hush: org.freedesktop.Notifications is owned by pid " + owner + "; notifications passive")
                root.probed = true
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: root.passive; onTriggered: probe.running = true }

    Instantiator {
        active: root.probed && !root.passive
        delegate: NotificationServer {
            bodySupported: true; actionsSupported: true; imageSupported: true
            persistenceSupported: true; keepOnReload: true
            onNotification: n => root.arrived(n)
        }
    }

    function arrived(n) {
        n.tracked = true
        if (root.list.indexOf(n) < 0 && !n.transient) root.list = [n].concat(root.list)
        n.closed.connect(() => root.forget(n))
        // Carried over from before a reload: keep it in the center, do not pop it again.
        if (n.lastGeneration) return
        const centerOpen = Ipc.island && Ipc.island.state === "notifCenter"
        if (!centerOpen) root.unread++
        if (root.dnd || centerOpen) { if (n.transient) n.expire(); return }
        // A replacement (same id) updates the toast in place; the arbiter dedupes on the key.
        if (root.toasts.indexOf(n) < 0) root.toasts = root.toasts.concat([n])
        root.toast(n)
    }
    // The island finished showing a toast (hold ran out, acted on, lowered).
    function toastDone(n) {
        root.toasts = root.toasts.filter(x => x !== n)
        if (n && n.transient) n.expire()
    }
    // The notification center opened: every pending toast counts as seen.
    function seenAll() {
        const t = root.toasts
        root.toasts = []
        root.toastsCleared()
        for (const n of t) if (n.transient) n.expire()
    }
    function dismiss(n) { if (n) n.dismiss() }
    function clearAll() {
        const all = list.slice()
        for (const n of toasts) if (all.indexOf(n) < 0) all.push(n)
        toasts = []
        toastsCleared()
        for (const n of all) n.dismiss()
        list = []
        unread = 0
    }
    function markSeen() { unread = 0 }
    // Called from a notification's closed signal, before the object is destroyed.
    function forget(n) {
        list = list.filter(x => x !== n)
        if (toasts.indexOf(n) >= 0) { toasts = toasts.filter(x => x !== n); untoast(n.id) }
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

    IpcHandler {
        target: "notifs"
        function islandHeight(): int { return Ipc.island ? Math.round(Ipc.island.height) : 0 }
        function islandWidth(): int { return Ipc.island ? Math.round(Ipc.island.width) : 0 }
        // Toasts waiting behind the one shown (or behind a surface).
        function queued(): int { return Math.max(0, root.toasts.length - (root.current ? 1 : 0)) }
        function count(): int { return root.list.length }
        function current(): string { return root.current ? root.current.summary : "" }
        function toggleDnd(): bool { root.dnd = !root.dnd; return root.dnd }
        function dndOn(): bool { return root.dnd }
        function passive(): bool { return root.passive }
    }
}

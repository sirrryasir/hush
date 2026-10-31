pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Event sounds: short strikes in sounds/ (rendered by bin/hush-soundgen), played with pw-play.
// Settings `sounds`: enabled, volume 0..100, dnd ("critical": critical and battery sounds get through do
// not disturb, "none": silence), burstMs (routine sounds at most once per window), events {name: false
// turns one off}, apps {appName: "off" or an event name to play instead}.
Singleton {
    id: root
    readonly property var cfg: Settings.data.sounds || ({})
    readonly property var events: ["notification", "message", "critical", "battery-low", "battery-critical",
        "plug-in", "plug-out", "device-added", "device-removed", "screenshot", "timer-done", "focus-start", "focus-end"]
    property real last: 0

    function urgent(e) { return e === "critical" || e.indexOf("battery") === 0 }
    function file(e) { return Quickshell.shellDir + "/sounds/" + e + ".wav" }
    // Plays event `e` unless settings, do not disturb or the burst window say no; preview skips them.
    function play(e, preview) {
        if (root.events.indexOf(e) < 0) return
        if (!preview) {
            if (root.cfg.enabled === false || (root.cfg.events && root.cfg.events[e] === false)) return
            if (Notifs.dnd && !(root.cfg.dnd !== "none" && root.urgent(e))) return
            const now = Date.now()
            if (!root.urgent(e) && now - root.last < (root.cfg.burstMs ?? 1500)) return
            root.last = now
        }
        Quickshell.execDetached(["pw-play", "--volume", String((root.cfg.volume ?? 60) / 100), root.file(e)])
    }
    // The event a notification sounds as: Hush's own kinds first, then urgency, then a chat category.
    function eventFor(n) {
        const kind = n.hints ? n.hints["x-hush-kind"] : ""
        const crit = n.urgency === NotificationUrgency.Critical
        if (kind === "battery") return crit ? "battery-critical" : "battery-low"
        if (kind === "focus-start" || kind === "focus-end" || kind === "screenshot") return kind
        if (crit) return "critical"
        const cat = n.hints ? String(n.hints["category"] || "") : ""
        return cat.indexOf("im.") === 0 ? "message" : "notification"
    }
    function notify(n) {
        const o = root.cfg.apps ? root.cfg.apps[n.appName] : undefined
        if (o === "off") return
        root.play(o && root.events.indexOf(o) >= 0 ? o : root.eventFor(n))
    }
}

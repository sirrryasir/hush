pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Reminders: a time and a text, kept in ~/.config/hush/reminders.json as [{id, at (epoch ms), text}].
// add(at, text) / remove(id); when one is due it goes out through notify-send as app "hush" (so it shows
// through do not disturb, like the focus timer's notices) and is dropped. `pill` is the rest-pill text
// ("Standup in 12 min") for the next reminder within the hour, "" otherwise.
// shortcut: a reminder missed while the shell was off fires once at the next start; no snooze.
Singleton {
    id: root
    property var items: []
    property real now: Date.now()
    property int seq: 0
    readonly property var next: items.find(r => r.at - now <= 3600000) || null
    readonly property string pill: {
        if (!next) return ""
        const t = next.text.length > 18 ? next.text.slice(0, 17) + "…" : next.text
        return t + " in " + Math.max(1, Math.ceil((next.at - now) / 60000)) + " min"
    }

    readonly property string file: Quickshell.env("HOME") + "/.config/hush/reminders.json"

    function sameDay(ms, d) {
        const a = new Date(ms)
        return a.getFullYear() === d.getFullYear() && a.getMonth() === d.getMonth() && a.getDate() === d.getDate()
    }
    function onDay(d) { return items.filter(r => sameDay(r.at, d)) }
    function add(at, text) {
        text = String(text).trim()
        if (text === "" || !(at > Date.now())) return false
        items = items.concat([{ id: Date.now() + "-" + (seq++), at: at, text: text }]).sort((a, b) => a.at - b.at)
        now = Date.now(); save(); return true
    }
    function remove(id) { items = items.filter(r => r.id !== id); save() }
    function save() { store.setText(JSON.stringify(items)) }
    function tick() {
        now = Date.now()
        const due = items.filter(r => r.at <= now)
        if (due.length === 0) return
        items = items.filter(r => r.at > now); save()
        for (const r of due) Quickshell.execDetached(["notify-send", "-a", "hush", "-i", "alarm", r.text, "Reminder"])
    }

    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try { root.items = JSON.parse(text()).filter(r => r.at > 0 && r.text).sort((a, b) => a.at - b.at); root.tick() } catch (e) {}
        }
    }
    Timer { interval: 1000; running: root.items.length > 0; repeat: true; onTriggered: root.tick() }
}

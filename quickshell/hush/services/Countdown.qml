pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Timer activity (named Countdown: a singleton called Timer would shadow QtQuick's Timer in this module).
// start(seconds, label) / stop(); `remaining` in whole seconds. State lives in ~/.cache/hush/timer.json
// as {endsAt (epoch ms), label} so a shell restart keeps the countdown.
Singleton {
    id: root
    property bool running: false
    property int remaining: 0
    property string label: ""
    property real endsAt: 0
    signal finished(string label)

    readonly property string file: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hush/timer.json"

    function start(seconds, lbl) {
        if (!(seconds > 0)) return
        label = lbl || ""
        endsAt = Date.now() + seconds * 1000
        running = true
        tick(); save()
    }
    function stop() { running = false; remaining = 0; endsAt = 0; label = ""; save() }
    function tick() {
        if (!running) return
        const left = Math.ceil((endsAt - Date.now()) / 1000)
        if (left <= 0) { const l = label; stop(); finished(l) } else remaining = left
    }
    function save() {
        store.setText(JSON.stringify(running ? { endsAt: endsAt, label: label } : {}))
    }
    function load(text) {
        try {
            const d = JSON.parse(text)
            if (d.endsAt && d.endsAt > Date.now()) { label = d.label || ""; endsAt = d.endsAt; running = true; tick() }
            else if (d.endsAt) stop()
        } catch (e) {}
    }

    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: root.load(text())
    }
    Timer { interval: 500; running: root.running; repeat: true; onTriggered: root.tick() }
}

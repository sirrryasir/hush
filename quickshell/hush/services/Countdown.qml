pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Timer activity (named Countdown: a singleton called Timer would shadow QtQuick's Timer in this module).
// start(seconds, label) / stop(); `remaining` in whole seconds. State lives in ~/.cache/hush/timer.json
// as {endsAt (epoch ms), label, phase, cycle, dndWas} so a shell restart keeps the countdown.
// Focus session: focusStart(phase) runs focus 25 / break 5 / long break 15 (minutes), the long break
// after the fourth focus, each phase change announced with notify-send; DND is on from the first focus
// to the end of the session (focusDnd), then back to what it was. stop() ends either kind.
Singleton {
    id: root
    property bool running: false
    property int remaining: 0
    property string label: ""
    property real endsAt: 0
    // "" plain timer, else "focus" | "break" | "long"; cycle counts the focus blocks (1..4).
    property string phase: ""
    property int cycle: 0
    property bool dndWas: false
    // shortcut: session only, resets to on with the shell; make it a setting when someone asks.
    property bool focusDnd: true
    readonly property int phaseMins: phase === "focus" ? 25 : phase === "break" ? 5 : 15
    readonly property string phaseLabel: ({ focus: "Focus", break: "Break", long: "Long break" })[phase] || ""
    signal finished(string label)

    readonly property string file: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hush/timer.json"

    function start(seconds, lbl) {
        if (!(seconds > 0)) return
        if (phase !== "") stop()
        label = lbl || ""
        arm(seconds)
    }
    function focusStart(p) {
        if (phase === "") { cycle = 1; dndWas = Notifs.dnd; if (focusDnd) Notifs.dnd = true }
        phase = p || "focus"
        arm(phaseMins * 60)
    }
    function arm(seconds) { endsAt = Date.now() + seconds * 1000; running = true; tick(); save() }
    function stop() {
        if (phase !== "") { if (focusDnd) Notifs.dnd = dndWas; phase = "" }
        running = false; remaining = 0; endsAt = 0; label = ""; cycle = 0; save()
    }
    function tick() {
        if (!running) return
        const left = Math.ceil((endsAt - Date.now()) / 1000)
        if (left > 0) { remaining = left; return }
        if (phase !== "") { next(); return }
        const l = label; stop(); finished(l)
    }
    function next() {
        if (phase === "long") { stop(); return }
        if (phase === "break") cycle++
        focusStart(phase === "focus" ? (cycle < 4 ? "break" : "long") : "focus")
        Quickshell.execDetached(["notify-send", "-a", "hush", "-i", "timer", phaseLabel, phaseMins + " min"])
    }
    function save() {
        store.setText(JSON.stringify(running ? { endsAt: endsAt, label: label, phase: phase, cycle: cycle, dndWas: dndWas } : {}))
    }
    function load(text) {
        try {
            const d = JSON.parse(text)
            if (!d.endsAt) return
            label = d.label || ""; phase = d.phase || ""; cycle = d.cycle || 0; dndWas = !!d.dndWas; endsAt = d.endsAt
            if (phase !== "" && focusDnd) Notifs.dnd = true
            running = true; tick()
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

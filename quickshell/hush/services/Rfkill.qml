pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The rfkill switches from `rfkill -J`: which radio types are soft or hard blocked, and airplane
// mode (every switch blocked). Bt lifts a bluetooth block; the airplane tile blocks or unblocks all.
Singleton {
    id: root
    // type ("wlan", "bluetooth", ...) -> true while blocked.
    property var blocked: ({})
    // Switches seen (0: no rfkill or no radio; the airplane tile hides).
    property int count: 0
    property int blockedCount: 0
    readonly property bool bluetooth: !!blocked.bluetooth
    readonly property bool airplane: count > 0 && blockedCount === count

    function probe() { if (!reader.running) reader.running = true }
    function setAirplane(on) {
        if (toggler.running) return
        toggler.command = ["rfkill", on ? "block" : "unblock", "all"]
        toggler.running = true
    }
    Process {
        id: reader
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = {}; let n = 0, nb = 0
                try {
                    const j = JSON.parse(text), devs = j[""] || j.rfkilldevices || []
                    for (const d of devs) {
                        n++
                        if (d.soft === "blocked" || d.hard === "blocked") { nb++; b[d.type] = true }
                    }
                } catch (e) {}
                root.blocked = b; root.count = n; root.blockedCount = nb
            }
        }
    }
    Process {
        id: toggler
        onExited: code => { if (code !== 0) console.log("hush: rfkill exited " + code); root.probe() }
    }
    Component.onCompleted: probe()
}

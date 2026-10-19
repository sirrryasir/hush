pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// power-profiles-daemon through powerprofilesctl: the profiles it lists, the active one, set(name).
// `profiles` stays empty without the command, and the battery chip then has no tap.
Singleton {
    id: root
    property var profiles: []
    property string active: ""
    readonly property bool available: profiles.length > 0

    function probe() { if (!reader.running) reader.running = true }
    function set(name) {
        if (setter.running) return
        setter.command = ["powerprofilesctl", "set", name]
        setter.running = true
    }
    Process {
        id: reader
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl list && echo \"active: $(powerprofilesctl get)\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // list: "* balanced:" (active) / "  power-saver:" per profile, properties indented under each.
                const names = [], ls = text.split("\n")
                for (const l of ls) { const m = /^\*?\s*([a-z-]+):$/.exec(l); if (m) names.push(m[1]) }
                const a = /^active: (\S+)/m.exec(text)
                root.profiles = names; root.active = a ? a[1] : ""
            }
        }
    }
    Process {
        id: setter
        onExited: code => { if (code !== 0) console.log("hush: powerprofilesctl exited " + code); root.probe() }
    }
}

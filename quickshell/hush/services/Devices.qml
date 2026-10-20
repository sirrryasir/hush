pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Removable drives with a filesystem, from `udisksctl dump`. `udisksctl monitor` only says that
// something changed: each event line re-runs the dump (300 ms debounce), so a plug, a mount and an
// unplug all go through one parser. `list` entries: { dev, drive, name, size, fs, mount }.
// shortcut: a monitor that dies (no udisks2) is not restarted, restart the shell after installing it.
Singleton {
    id: root
    property var list: []
    readonly property bool present: list.length > 0
    // A drive that was not in the previous dump (none at the first dump, so no card at shell start).
    signal arrived(var d)
    // Eject finished: unmounted and powered off.
    signal ejected(string name)
    property bool seeded: false

    function find(dev) { return list.find(d => d.dev === dev) || null }
    function mount(d) { if (d) Quickshell.execDetached(["udisksctl", "mount", "-b", d.dev]) }
    function open(d) { if (d && d.mount) Quickshell.execDetached(["xdg-open", d.mount]) }
    function eject(d) {
        if (!d || ejector.running) return
        ejector.name = d.name
        ejector.command = ["sh", "-c", "udisksctl unmount -b \"$1\"; udisksctl power-off -b \"$1\"", "sh", d.dev]
        ejector.running = true
    }
    function size(n) { return n >= 1e9 ? (n / 1e9).toFixed(1) + " GB" : Math.round(n / 1e6) + " MB" }
    function parse(text) {
        const objs = {}
        let cur = null
        for (const l of text.split("\n")) {
            if (l[0] === "/") { cur = objs[l.replace(/:\s*$/, "")] = {}; continue }
            const m = cur && l.match(/^\s+(\w+):\s*(.*)$/)
            if (m) cur[m[1]] = m[2].replace(/^'|'$/g, "")
        }
        const out = []
        for (const o of Object.values(objs)) {
            const drive = objs[o.Drive || ""]
            if (o.MountPoints === undefined || !o.Device || o.HintIgnore === "true" || !drive || drive.Removable !== "true") continue
            out.push({ dev: o.Device, drive: o.Drive, fs: o.IdType || "", mount: (o.MountPoints || "").trim(),
                       name: o.IdLabel || ((drive.Vendor || "") + " " + (drive.Model || "")).trim() || o.Device,
                       size: root.size(Number(o.Size) || 0) })
        }
        return out
    }

    Process {
        id: dump
        command: ["udisksctl", "dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                const old = root.list, next = root.parse(text)
                root.list = next
                const was = root.seeded; root.seeded = true
                if (was) for (const d of next) if (!old.some(o => o.dev === d.dev)) root.arrived(d)
            }
        }
    }
    Timer { id: refresh; interval: 300; onTriggered: if (dump.running) refresh.restart(); else dump.running = true }
    Process {
        command: ["udisksctl", "monitor"]
        running: true
        stdout: SplitParser { onRead: l => { if (/^\d\d:\d\d:\d\d/.test(l)) refresh.restart() } }
    }
    Component.onCompleted: dump.running = true
    Process {
        id: ejector
        property string name: ""
        onExited: code => { if (code === 0) root.ejected(name); refresh.restart() }
    }
}

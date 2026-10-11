//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "modules/island"

// One island surface per screen; every panel and modal (control center, notifications, launcher,
// wallpapers, settings) grows out of it, so hush maps no other layer.
ShellRoot {
    id: root
    Component.onCompleted: { void Ipc.island; void Notifs.count; console.log("hush shell up, mode=" + Colors.mode) }
    Variants { model: Quickshell.screens; delegate: IslandWindow {} }

    // One shell per session. A second `qs -c hush` (a restart that never stopped the old one) maps a
    // second island under the first one's exclusive zone, so every surface it opens draws as a box
    // under the old rest pill. The newest instance wins: it ends every older one (ties: higher pid).
    function retireOlder(out) {
        const nl = out.indexOf("\n"), me = parseInt(out.slice(0, nl))
        let list = []
        try { list = JSON.parse(out.slice(nl + 1)) } catch (e) { return }
        const mine = list.find(i => i.pid === me)
        if (!mine) return
        for (const i of list) {
            if (i.pid === me) continue
            if (i.launch_time < mine.launch_time || (i.launch_time === mine.launch_time && i.pid < me)) {
                console.log("hush: ending older shell instance " + i.pid)
                Quickshell.execDetached(["kill", String(i.pid)])
            }
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "echo $PPID; qs list -c hush -j 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.retireOlder(text) }
    }
}

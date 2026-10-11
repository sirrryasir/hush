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
        const blank = out.indexOf("\n\n", nl)
        const skip = out.slice(nl + 1, blank).split("\n").filter(l => l.startsWith("skip ")).map(l => parseInt(l.slice(5)))
        let list = []
        try { list = JSON.parse(out.slice(blank + 2)) } catch (e) { return }
        list = list.filter(i => skip.indexOf(i.pid) < 0)
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
        // Only instances on this compositor count: a nested Hyprland (tests) may run its own shell.
        command: ["sh", "-c", "echo $PPID; mine=$(tr '\\0' '\\n' </proc/$PPID/environ | grep -E '^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE)='); "
            + "qs list -c hush -j 2>/dev/null | grep -o '\"pid\": *[0-9]*' | grep -o '[0-9]*$' | while read -r p; do "
            + "[ \"$(tr '\\0' '\\n' </proc/$p/environ 2>/dev/null | grep -E '^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE)=')\" = \"$mine\" ] || echo \"skip $p\"; done; "
            + "echo; qs list -c hush -j 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.retireOlder(text) }
    }
}

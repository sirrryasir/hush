pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keyboard layouts as Hyprland reports them: `count`, the active layout's two-letter `short` name
// and the main keyboard's `device`. Re-read at start and on every activelayout event.
Singleton {
    id: root
    property int count: 0
    property string short: ""
    property string device: ""

    function next() { if (root.device !== "") Quickshell.execDetached(["hyprctl", "switchxkblayout", root.device, "next"]) }
    function refresh() { if (!proc.running) proc.running = true }
    Component.onCompleted: refresh()

    // active_keymap is a description ("German"), the layout list holds xkb codes ("us,de"): the code
    // is found through evdev.lst. shortcut: a variant's description may match the wrong sibling, then
    // the first layout is shown; fix by tracking the index from activelayout events.
    Process {
        id: proc
        command: ["sh", "-c", "hyprctl -j devices | python3 -c '" + [
            "import json,sys",
            "ks=json.load(sys.stdin).get(\"keyboards\",[])",
            "k=next((k for k in ks if k.get(\"main\")),ks[0] if ks else None)",
            "if k is None: print(0); sys.exit()",
            "ls=[l for l in k[\"layout\"].split(\",\") if l]",
            "d={}",
            "on=False",
            "for l in open(\"/usr/share/X11/xkb/rules/evdev.lst\",errors=\"replace\"):",
            " if l.startswith(\"!\"): on=l.split()[1:]==[\"layout\"]",
            " elif on and l.strip(): c,_,n=l.strip().partition(\" \"); d[c]=n.strip()",
            "a=k.get(\"active_keymap\",\"\")",
            "i=next((i for i,c in enumerate(ls) if d.get(c)==a),next((i for i,c in enumerate(ls) if a.startswith(d.get(c,\"\\0\").split(\" (\")[0])),0))",
            "print(len(ls),ls[i][:2].lower() if ls else \"\",k[\"name\"])"
        ].join("\n") + "'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                root.count = parseInt(p[0]) || 0
                root.short = p[1] || ""
                root.device = p[2] || ""
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "activelayout") root.refresh() }
    }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Open Hyprland windows. With the Lua config, dispatch takes a Lua expression.
QtObject {
    function items() {
        const out = []
        for (const t of Hyprland.toplevels.values) {
            if (!t.address) continue
            const ipc = t.lastIpcObject || {}
            const cls = ipc.class || ""
            const entry = cls ? DesktopEntries.heuristicLookup(cls) : null
            const addr = t.address.startsWith("0x") ? t.address : "0x" + t.address
            out.push({
                kind: "window", remember: false,
                icon: entry ? entry.icon : cls,
                name: t.title || cls,
                hint: (entry ? entry.name : cls) + (t.workspace ? "  ·  " + t.workspace.name : ""),
                keywords: cls,
                run: () => Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })")
            })
        }
        return out
    }
}

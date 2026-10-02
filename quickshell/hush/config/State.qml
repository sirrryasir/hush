pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string theme: "harbor"
    property string wallpaper: ""
    property string mode: "dark"
    property string appliedAt: ""
    FileView {
        id: f
        path: Quickshell.env("HOME") + "/.config/hush/state.json"
        watchChanges: true
        onFileChanged: t.restart()
        onLoaded: {
            try {
                const s = JSON.parse(f.text())
                root.theme = s.theme || ""
                root.wallpaper = s.wallpaper || ""
                root.mode = s.mode || ""
                root.appliedAt = s.applied_at || ""
            } catch (e) { console.warn("state.json parse failed: " + e) }
        }
    }
    Timer { id: t; interval: 100; onTriggered: f.reload() }
}

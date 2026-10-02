import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Controller + one window per screen; only the focused monitor shows it.
Scope {
    id: ctl
    property bool visible: false
    property string monitorName: ""
    property var files: []
    readonly property int count: files.length

    function show() {
        ctl.monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
        lister.running = false
        lister.found = []
        lister.running = true
        ctl.visible = true
    }
    function hide() { ctl.visible = false }
    function toggle() { ctl.visible ? ctl.hide() : ctl.show() }
    function select(path) {
        applyProc.command = [Paths.hush, "wall", path]
        applyProc.running = true
        ctl.hide()
    }

    Component.onCompleted: Ipc.wallpapers = ctl

    Process {
        id: lister
        property var found: []
        command: ["bash", "-c",
            // Theme wallpapers plus every directory in HUSH_WALL_DIRS (colon-separated), like `hush wall random`.
            "IFS=: read -ra d <<<\"${HUSH_WALL_DIRS:-}\"; find \"${d[@]}\" \"$1\" -maxdepth 2 -type f " +
            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) 2>/dev/null | sort", "hush-wallpapers", Paths.themes]
        stdout: SplitParser { onRead: line => { if (line.length) lister.found.push(line) } }
        onExited: ctl.files = lister.found.slice()
    }
    Process { id: applyProc; stderr: StdioCollector { onStreamFinished: if (text.length) console.log("wall err: " + text) } }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: ctl.visible && ctl.monitorName === modelData.name
            implicitWidth: 760
            implicitHeight: 480
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "hush-wallpapers"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [win]
                active: win.visible
                onCleared: ctl.hide()
            }

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Colors.alpha(Colors.surface_container, 0.85)
                border.width: 1
                border.color: Colors.outline_variant

                Wallpapers {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: 16
                    files: ctl.files
                    onPick: path => ctl.select(path)
                    onDismiss: ctl.hide()
                }
            }
            onVisibleChanged: { if (visible) focusTimer.restart() }
            Timer { id: focusTimer; interval: 100; onTriggered: grid.focusCurrent() }
            Connections { target: ctl; function onFilesChanged() { if (win.visible) grid.focusCurrent() } }
        }
    }
}

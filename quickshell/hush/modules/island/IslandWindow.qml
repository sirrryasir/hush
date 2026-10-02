import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// One island per screen. The island on the focused monitor is the one IPC, OSD and notifications drive (see Ipc.pick).
PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData

    anchors.top: true
    margins.top: Theme.topMargin
    // Reserves the top band so tiled windows start below the island (Waybar is gone).
    exclusiveZone: Theme.exclusiveTop
    implicitWidth: Theme.islandExpanded.width + 40
    implicitHeight: Theme.islandExpanded.height + 20
    color: "transparent"
    WlrLayershell.namespace: "hush-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: island.state === "expanded" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: island }

    Island { id: island; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top }

    // Click outside the expanded island collapses it.
    HyprlandFocusGrab {
        windows: [win]
        active: island.state === "expanded"
        onCleared: island.release("expanded")
    }

    Component.onCompleted: Ipc.registerIsland(modelData.name, island)
    Component.onDestruction: Ipc.unregisterIsland(modelData.name)
    // When the driven island collapses, hand the role to whichever island is on the focused monitor.
    Connections { target: island; function onStateChanged() { Ipc.pick() } }
}

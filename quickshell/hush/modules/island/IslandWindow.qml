import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// One island surface per screen (design 2.4): full width, fixed height, never resized. Only the
// input mask follows the pill, so no configure round-trip ever paints a stretched frame and
// transparent pixels never take clicks. The island on the focused monitor is the one IPC, OSD and
// notifications drive (Ipc.pick); an expanded island keeps that role until it collapses.
Scope {
    id: scope
    required property ShellScreen modelData

    readonly property string mode: Settings.island.mode || "reserve"
    readonly property bool autohide: mode === "autohide"
    readonly property int topGap: Settings.island.topGap !== undefined ? Settings.island.topGap : 6
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    // A fullscreen window on this monitor's active workspace retracts the pill.
    readonly property bool fullscreen: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    // Auto-hide: shown while the reveal strip or the pill is hovered (plus a grace period), briefly
    // after a workspace change, and whenever the island shows something at priority >= OSD.
    property bool held: false
    property bool peeking: false
    readonly property bool raised: island.priority >= Priorities.osd
    readonly property bool revealed: !autohide || held || peeking || raised
    readonly property bool hidden: !island.surfaceOpen && (fullscreen || !revealed)
    readonly property bool modalOpen: island.priority >= Priorities.modal

    function hoverChanged() {
        if (strip.hovered || pillHover.hovered) { grace.stop(); held = true }
        else if (held) grace.restart()
    }
    Timer { id: grace; interval: Settings.motion.leaveGraceMs || 300; onTriggered: scope.held = false }
    Timer { id: peek; interval: 1500; onTriggered: scope.peeking = false }
    readonly property int activeWs: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : 0
    onActiveWsChanged: if (autohide) { peeking = true; peek.restart() }

    PanelWindow {
        id: win
        screen: scope.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 360
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: scope.mode === "reserve" ? (Settings.island.reserve !== undefined ? Settings.island.reserve : 40) : 0
        color: "transparent"
        WlrLayershell.namespace: "hush-island"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: island.surfaceOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // The pill's rect, empty while retracted; the full surface only while a modal surface is open.
        mask: Region {
            item: scope.hidden ? null : island
            Region { item: scope.modalOpen ? catcher : null }
        }

        Item { id: catcher; anchors.fill: parent }

        Island {
            id: island
            hidden: scope.hidden
            screenName: scope.modelData.name
            anchors.horizontalCenter: parent.horizontalCenter
            y: scope.hidden ? -height - 2 : scope.topGap
            Behavior on y { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
            HoverHandler { id: pillHover; onHoveredChanged: scope.hoverChanged() }
        }

        // A click outside an open surface closes it.
        HyprlandFocusGrab {
            windows: [win]
            active: island.surfaceOpen
            onCleared: { island.mark("@grab"); island.closeSurface() }
        }
    }

    // Auto-hide reveal strip: 1 px along the top edge, only in auto-hide mode.
    PanelWindow {
        id: stripWin
        visible: scope.autohide
        screen: scope.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hush-island-reveal"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Item { anchors.fill: parent; HoverHandler { id: strip; onHoveredChanged: scope.hoverChanged() } }
    }

    Component.onCompleted: Ipc.registerIsland(modelData.name, island)
    Component.onDestruction: Ipc.unregisterIsland(modelData.name)
    // When the driven island collapses, hand the role to whichever island is on the focused monitor.
    Connections { target: island; function onStateChanged() { Ipc.pick() } }
}

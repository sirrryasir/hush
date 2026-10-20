import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import "states"

// One island surface per screen: full width, fixed height, never resized. Only the
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
    // Auto-hide: shown while the reveal strip or the pill is hovered (plus the leave grace), for
    // motion.revealMs after a workspace change, and while the island shows something at priority
    // >= OSD (then for the leave grace after it ends, so the pill does not snap away mid-fade).
    property bool held: false
    property bool peeking: false
    readonly property bool raised: island.priority >= Priorities.osd
    readonly property bool revealed: !autohide || held || peeking || raised
    // Fullscreen: the pill retracts, but the top-edge strip stays live (island.fullscreenReveal):
    // the pointer at y = 0 reveals the pill over the fullscreen window until the leave grace runs out.
    // OSDs then show on the separate OsdOverlay layer instead (1.1 s), never the whole island.
    readonly property bool fullscreenReveal: Settings.island.fullscreenReveal !== false
    readonly property bool hidden: !island.surfaceOpen && (fullscreen ? !(fullscreenReveal && held) : !revealed)
    readonly property bool stripActive: autohide || (fullscreen && fullscreenReveal)
    readonly property bool modalOpen: island.modalOpen
    readonly property int graceMs: Settings.motion.leaveGraceMs || 300
    readonly property bool osdOverlay: fullscreen && hidden && island.state === "osd" && Settings.island.fullscreenOsd !== false

    function hoverChanged() {
        if (strip.hovered || pillHover.hovered) { grace.stop(); held = true }
        else if (held) grace.restart()
    }
    Timer { id: grace; interval: scope.graceMs; onTriggered: scope.held = false }
    Timer { id: peek; interval: Settings.motion.revealMs || 1500; onTriggered: scope.peeking = false }
    readonly property int activeWs: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : 0
    function peekFor(ms) { if (!autohide) return; peeking = true; peek.interval = ms; peek.restart() }
    onActiveWsChanged: peekFor(Settings.motion.revealMs || 1500)
    onRaisedChanged: if (!raised) peekFor(graceMs)
    // A mode switch shows the pill once, so the change is visible where it happened.
    onModeChanged: peekFor(Settings.motion.revealMs || 1500)

    PanelWindow {
        id: win
        screen: scope.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: Sizes.windowHeight
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: scope.mode === "reserve" ? (Settings.island.reserve !== undefined ? Settings.island.reserve : 40) : 0
        color: "transparent"
        WlrLayershell.namespace: "hush-island"
        // Above a fullscreen window only while one is up (the Top layer sits under it).
        WlrLayershell.layer: scope.fullscreen ? WlrLayer.Overlay : WlrLayer.Top
        // On demand while a surface is open: the focus grab below hands it the keyboard (typing reaches
        // the launcher at once). Exclusive would make Hyprland clear the grab as soon as it starts.
        WlrLayershell.keyboardFocus: island.surfaceOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // The pill's rect, empty while retracted; the full surface only while a modal surface is open.
        mask: Region {
            item: scope.hidden ? null : island
            Region { item: scope.modalOpen ? catcher : null }
        }

        // Stay awake (the control center's caffeine tile): idle-inhibit-unstable-v1, which hypridle honours.
        IdleInhibitor { window: win; enabled: Caffeine.on }

        // Under a modal surface the whole island surface takes input; a click off the pill closes it.
        MouseArea {
            id: catcher
            anchors.fill: parent
            enabled: scope.modalOpen
            acceptedButtons: Qt.AllButtons
            // Same arming as the pill's buttons: a click in the first armMs after the surface opened
            // (one meant for the old shape) does not dismiss it.
            onPressed: { if (!island.armed) { island.mark("@catch-unarmed"); return } island.mark("@catch"); island.closeSurface() }
        }

        Island {
            id: island
            hidden: scope.hidden
            overlayOsd: scope.osdOverlay
            screenName: scope.modelData.name
            screenOrigin: Qt.point(scope.modelData.x, scope.modelData.y)
            anchors.horizontalCenter: parent.horizontalCenter
            y: scope.hidden ? -height - 2 : scope.topGap
            Behavior on y { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
            HoverHandler { id: pillHover; onHoveredChanged: scope.hoverChanged() }
        }

        // A click outside an open surface closes it.
        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: island.surfaceOpen
            // While still arming, the clear is ignored and the grab re-taken (the compositor set
            // active false; restoring the binding asks for a new grab).
            onCleared: {
                if (!island.armed && island.surfaceOpen) { island.mark("@grab-unarmed"); Qt.callLater(scope.regrab); return }
                island.mark("@grab"); island.closeSurface()
            }
        }
    }

    readonly property Item islandRef: island
    function regrab() { grab.active = Qt.binding(() => island.surfaceOpen) }

    // Reveal strip: 1 px along the top edge in auto-hide mode, and over a fullscreen window (the
    // Overlay layer, so a fullscreen client never covers it).
    PanelWindow {
        visible: scope.stripActive
        screen: scope.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hush-island-reveal"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Item { anchors.fill: parent; HoverHandler { id: strip; onHoveredChanged: scope.hoverChanged() } }
    }

    // Fullscreen OSD overlay: the retracted island's OSD (volume, brightness, mic) as a lone pill on
    // the Overlay layer, mapped only while it shows (the arbiter's 1.1 s hold); input passes through.
    PanelWindow {
        visible: scope.osdOverlay
        screen: scope.modelData
        anchors { top: true }
        implicitWidth: Sizes.osd.width; implicitHeight: Sizes.osd.height + scope.topGap
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hush-island-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Rectangle {
            y: scope.topGap; width: Sizes.osd.width; height: Sizes.osd.height; radius: height / 2
            color: "#000000"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
            Accessible.role: Accessible.Indicator
            Accessible.name: "On-screen display"
            Osd {
                island: scope.islandRef
                kind: scope.islandRef.payload && scope.islandRef.payload.kind ? scope.islandRef.payload.kind : "volume"
            }
        }
    }

    Component.onCompleted: Ipc.registerIsland(modelData.name, island)
    Component.onDestruction: Ipc.unregisterIsland(modelData.name)
    // When the driven island collapses, hand the role to whichever island is on the focused monitor.
    Connections { target: island; function onStateChanged() { Ipc.pick() } }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services

// Workspace overview, 672x474 inside the island (the 640x360 stage is a 16:9 box, so a 1080p desktop fills it): a strip with one cell per workspace of this monitor
// (windows drawn as plain rectangles) over a stage with the shown workspace's windows as live captures
// at their real positions. Hovering or stepping changes the shown workspace only; a click on a cell
// switches, a click on a thumbnail focuses, a thumbnail dropped on a cell moves that window there.
// Left/Right step, Tab/Shift+Tab pick a thumbnail, Enter focuses it, Esc emits close(). Everything here
// is rebuilt on every open, so capture stops when the island unloads it.
FocusScope {
    id: root
    property size size: Sizes.overview
    property bool wantsKeyboard: true
    property string screenName: ""
    signal close()

    readonly property var cells: Hypr.workspacesFor(screenName)
    readonly property int cellCount: cells.length
    property int shownIndex: 0
    readonly property int shownWorkspace: cellCount ? cells[Math.min(shownIndex, cellCount - 1)].id : -1
    // Windows with an address, mapped, on a regular workspace; lastIpcObject is null until the first refresh.
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.address && t.lastIpcObject
        && t.lastIpcObject.mapped && t.workspace && t.workspace.id > 0)
    readonly property var thumbs: windows.filter(t => t.workspace.id === shownWorkspace)
    readonly property int thumbCount: thumbs.length
    property int hoverIndex: -1
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) || Hyprland.focusedMonitor

    // A window's rect inside a w x h box that the monitor's usable logical area is fitted into.
    // shortcut: monitor transforms are ignored, rotated monitors draw wrong; upgrade when one exists.
    function fit(ipc, w, h) {
        const m = monitor
        if (!m || !ipc || !ipc.at || !ipc.size || !m.scale) return Qt.rect(0, 0, 0, 0)
        const r = (m.lastIpcObject && m.lastIpcObject.reserved) || [0, 0, 0, 0]
        const lw = m.width / m.scale - r[0] - r[2], lh = m.height / m.scale - r[1] - r[3]
        const k = Math.min(w / lw, h / lh)
        return Qt.rect((w - lw * k) / 2 + (ipc.at[0] - m.x - r[0]) * k, (h - lh * k) / 2 + (ipc.at[1] - m.y - r[1]) * k,
            ipc.size[0] * k, ipc.size[1] * k)
    }
    function thumbRect(i) { return fit(thumbs[i] ? thumbs[i].lastIpcObject : null, stage.width, stage.height) }
    function addr(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address }
    function hoverCell(i) { shownIndex = i; hoverIndex = -1 }
    function stepShown(d) { if (cellCount) hoverCell((shownIndex + d + cellCount) % cellCount) }
    function focusThumb(i) {
        const t = thumbs[i]
        if (!t) return
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr(t) + "\" })")
        root.close()
    }
    function moveThumb(i, wsId) {
        const t = thumbs[i]
        if (!t || t.workspace.id === wsId) return false
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + wsId + ", window = \"address:" + addr(t) + "\", follow = false })")
        Hyprland.refreshToplevels()
        return true
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels(); Hyprland.refreshMonitors()
        shownIndex = Math.max(0, cells.findIndex(c => c.active))
        forceActiveFocus()
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (/^(openwindow|closewindow|movewindow|fullscreen)/.test(ev.name)) Hyprland.refreshToplevels() }
    }
    Keys.onPressed: event => {
        const n = root.thumbCount
        if (event.key === Qt.Key_Escape) root.close()
        else if (event.key === Qt.Key_Left) root.stepShown(-1)
        else if (event.key === Qt.Key_Right) root.stepShown(1)
        else if (event.key === Qt.Key_Tab && n) root.hoverIndex = (root.hoverIndex + 1) % n
        else if (event.key === Qt.Key_Backtab && n) root.hoverIndex = (root.hoverIndex - 1 + n) % n
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.focusThumb(root.hoverIndex)
        else return
        event.accepted = true
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.stepShown(event.angleDelta.y > 0 ? -1 : 1)
    }

    Column {
        anchors.fill: parent; anchors.margins: 16
        spacing: 14

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Accessible.role: Accessible.Grouping; Accessible.name: "Workspaces"
            Repeater {
                model: root.cells
                Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property var wins: root.windows.filter(t => t.workspace.id === modelData.id)
                    width: 120; height: 68; radius: 10
                    color: drop.containsDrag ? Qt.rgba(1, 1, 1, 0.16) : index === root.shownIndex ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: modelData.active ? 1 : 0; border.color: Colors.islandPrimary
                    Accessible.role: Accessible.Button
                    Accessible.name: "Workspace " + modelData.name + (modelData.active ? ", current" : "")
                    Text {
                        anchors.centerIn: parent; visible: cell.wins.length === 0
                        text: cell.modelData.name
                        font.family: Theme.fontUi; font.pixelSize: 24; font.weight: Font.DemiBold
                        color: Qt.rgba(1, 1, 1, 0.22)
                    }
                    Repeater {
                        model: ScriptModel { values: cell.wins }
                        Rectangle {
                            required property var modelData
                            readonly property rect r: root.fit(modelData.lastIpcObject, cell.width - 8, cell.height - 8)
                            x: 4 + r.x; y: 4 + r.y; width: r.width; height: r.height
                            radius: 3; color: Qt.rgba(1, 1, 1, 0.18); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)
                        }
                    }
                    HoverHandler { onHoveredChanged: if (hovered) root.hoverCell(cell.index) }
                    TapHandler { onTapped: { Hypr.go(cell.modelData.id); root.close() } }
                    DropArea { id: drop; anchors.fill: parent; onDropped: drag => root.moveThumb(drag.source.index, cell.modelData.id) }
                }
            }
        }

        Item {
            id: stage
            width: parent.width; height: parent.height - 68 - parent.spacing
            Repeater {
                objectName: "stageThumbs"
                // ScriptModel keeps delegates (and their running captures) when the array is rebuilt.
                model: ScriptModel { values: root.thumbs }
                Item {
                    id: thumb
                    required property var modelData
                    required property int index
                    readonly property rect r: root.thumbRect(index)
                    readonly property bool hot: root.hoverIndex === index
                    readonly property var entry: modelData.lastIpcObject && modelData.lastIpcObject["class"]
                        ? DesktopEntries.heuristicLookup(modelData.lastIpcObject["class"]) : null
                    x: r.x; y: r.y; width: r.width; height: r.height
                    z: dragger.active ? 2 : hot ? 1 : 0
                    scale: hot && !dragger.active ? 1.02 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.durationShort } }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.title
                    Drag.source: thumb
                    Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                    ClippingRectangle {
                        anchors.fill: parent; radius: 8
                        color: Qt.rgba(1, 1, 1, 0.08)
                        IconImage {
                            anchors.centerIn: parent; implicitSize: 48
                            visible: !view.hasContent
                            source: Quickshell.iconPath(thumb.entry ? thumb.entry.icon : "", "application-x-executable")
                        }
                        ScreencopyView {
                            id: view
                            anchors.fill: parent
                            captureSource: thumb.modelData.wayland
                            live: true
                            opacity: hasContent ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 40; visible: thumb.hot
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.75) }
                            }
                            Text {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 36; rightMargin: 8; bottomMargin: 8 }
                                text: thumb.modelData.title; elide: Text.ElideRight; textFormat: Text.PlainText
                                font.family: Theme.fontUi; font.pixelSize: 12; color: "white"
                            }
                        }
                        IconImage {
                            anchors { left: parent.left; bottom: parent.bottom; margins: 6 }
                            implicitSize: 22
                            source: Quickshell.iconPath(thumb.entry ? thumb.entry.icon : "", "application-x-executable")
                        }
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 8; color: "transparent"
                        border.width: 1; border.color: thumb.hot ? Colors.islandPrimary : Qt.rgba(1, 1, 1, 0.08)
                    }
                    HoverHandler { onHoveredChanged: root.hoverIndex = hovered ? thumb.index : root.hoverIndex === thumb.index ? -1 : root.hoverIndex }
                    TapHandler { onTapped: root.focusThumb(thumb.index) }
                    DragHandler {
                        id: dragger
                        // Drop on a cell, then snap back to the window's place (it leaves the stage if the move took).
                        // Drag.active is set here, not bound: drop() must run while the drag is still active.
                        onActiveChanged: if (active) thumb.Drag.active = true; else {
                            thumb.Drag.drop(); thumb.Drag.active = false
                            thumb.x = Qt.binding(() => thumb.r.x); thumb.y = Qt.binding(() => thumb.r.y)
                        }
                    }
                }
            }
        }
    }
}

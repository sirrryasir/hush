import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import "." as L

// One launcher surface. Centered because no anchors are set.
PanelWindow {
    id: win
    property var controller
    property bool shown: false

    visible: shown
    color: "transparent"
    implicitWidth: 640
    implicitHeight: 420
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "hush-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: if (shown) input.forceActiveFocus()

    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (win.shown) win.controller.hide()
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.alpha(Colors.surface_container, 0.85)
        border.width: 1
        border.color: Colors.outline_variant

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Item {
                id: field
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 36
                Text {
                    id: glyph
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    text: "search"
                    font.family: Theme.fontIcon
                    font.pixelSize: 20
                    color: Colors.on_surface_variant
                }
                TextInput {
                    id: input
                    anchors { left: glyph.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textLauncher
                    color: Colors.on_surface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.on_primary
                    clip: true
                    text: win.controller.query
                    onTextEdited: win.controller.setQuery(text)
                    Keys.onPressed: event => {
                        const ctl = win.controller
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (event.key === Qt.Key_Escape) ctl.hide()
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) ctl.activate()
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) ctl.move(1)
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) ctl.move(-1)
                        else return
                        event.accepted = true
                    }
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text.length === 0
                        text: win.controller.mode === "windows" ? "Switch to a window"
                            : win.controller.mode === "apps" ? "Search apps"
                            : "Search apps, windows, = calc, ; clipboard"
                        font: input.font
                        color: Colors.on_surface_variant
                    }
                }
            }

            Rectangle {
                id: rule
                anchors { left: parent.left; right: parent.right; top: field.bottom; topMargin: 10 }
                height: 1
                color: Colors.outline_variant
            }

            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: rule.bottom; topMargin: 8; bottom: parent.bottom }
                clip: true
                model: win.shown ? win.controller.results : []
                currentIndex: win.controller.currentIndex
                highlightMoveDuration: Theme.durationShort
                boundsBehavior: Flickable.StopAtBounds
                delegate: L.Row {
                    required property var modelData
                    required property int index
                    width: list.width
                    entry: modelData
                    selected: index === win.controller.currentIndex
                    onClicked: win.controller.activate(index)
                    onHovered: win.controller.currentIndex = index
                }
                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: win.controller.clipMode ? (win.controller.clipAvailable ? "Clipboard is empty" : "cliphist not installed") : "No matches"
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textLauncher
                    color: Colors.on_surface_variant
                }
            }
        }
    }
}

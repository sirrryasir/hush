import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: win
    WlrLayershell.namespace: "hush-corner-left"
    anchors { top: true; left: true }
    margins { top: Theme.topMargin + 4; left: 16 }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: row.implicitWidth + 4
    implicitHeight: 24
    mask: Region { item: row }

    readonly property var wss: Hypr.workspacesFor(screen ? screen.name : "")
    readonly property string appName: {
        const c = Hypr.activeClass;
        return c === "" ? "" : c.charAt(0).toUpperCase() + c.slice(1);
    }
    readonly property color textColor: Colors.on_surface
    readonly property color shadowColor: Colors.isDark ? Colors.alpha(Colors.shadow, 0.5) : Colors.alpha(Colors.surface_bright, 0.6)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Repeater {
            model: ScriptModel { values: win.wss; objectProp: "id" }
            Item {
                id: dot
                required property var modelData
                width: pill.width
                height: 24
                Rectangle {
                    id: pill
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    width: dot.modelData.active ? 14 : 6
                    color: dot.modelData.active ? Colors.primary
                         : dot.modelData.occupied ? Colors.on_surface_variant
                         : Colors.alpha(Colors.on_surface, 0.35)
                    Behavior on width { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: Theme.durationShort } }
                }
                MouseArea {
                    anchors { fill: parent; leftMargin: -3; rightMargin: -3 }
                    onClicked: Hypr.go(dot.modelData.id)
                }
            }
        }
        Item { width: 6; height: 1; visible: win.appName !== "" }
        Item {
            visible: win.appName !== ""
            width: label.implicitWidth + 1
            height: 24
            Text {
                x: 1; y: label.y + 1
                text: label.text; font: label.font
                color: win.shadowColor; opacity: 0.7
                anchors.verticalCenter: undefined
            }
            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: win.appName
                color: win.textColor
                opacity: 0.7
                font.family: Theme.fontUi
                font.pixelSize: Theme.textCorner
            }
        }
    }
    WheelHandler {
        target: null
        onWheel: event => Hypr.step(event.angleDelta.y > 0 ? -1 : 1)
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: win
    WlrLayershell.namespace: "hush-corner-right"
    anchors { top: true; right: true }
    margins { top: Theme.topMargin + 4; right: 16 }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: row.implicitWidth + 4
    implicitHeight: 24
    mask: Region { item: row }

    readonly property color textColor: Colors.on_surface
    readonly property color shadowColor: Colors.isDark ? Colors.alpha(Colors.shadow, 0.5) : Colors.alpha(Colors.surface_bright, 0.6)
    readonly property int unread: Ipc.drawer ? Ipc.drawer.unread : 0

    component Glyph: Item {
        id: g
        property string name
        width: 16; height: 24
        Text {
            x: gt.x + 1; y: gt.y + 1
            text: gt.text; font: gt.font; color: win.shadowColor
        }
        Text {
            id: gt
            anchors.centerIn: parent
            text: g.name
            color: win.textColor
            font.family: Theme.fontIcon
            font.pixelSize: 14
            font.variableAxes: ({ "FILL": 1, "wght": 500, "opsz": 20 })
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Glyph { name: Net.icon }
        Glyph { name: Bt.icon; visible: Bt.connectedName !== "" }
        Row {
            visible: Battery.present
            spacing: 2
            Glyph { name: Battery.icon }
            Item {
                width: pct.implicitWidth + 1; height: 24
                Text { x: pct.x + 1; y: pct.y + 1; text: pct.text; font: pct.font; color: win.shadowColor }
                Text {
                    id: pct
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.percent + "%"
                    color: win.textColor
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textCorner
                }
            }
        }
        Rectangle {
            visible: win.unread > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: Colors.primary
        }
    }
    MouseArea {
        anchors.fill: row
        onClicked: if (Ipc.island) Ipc.island.toggleExpanded()
    }
}

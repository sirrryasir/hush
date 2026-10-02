import QtQuick
import qs.config

// A control-center tile: glyph, label, optional subtitle. On = primary, off = a raised surface.
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool checked: false
    signal clicked()

    implicitHeight: 56
    radius: 14
    color: checked ? Colors.primary : Colors.surface_container_high
    Behavior on color { ColorAnimation { duration: Theme.durationShort } }
    readonly property color ink: checked ? Colors.on_primary : Colors.on_surface

    Row {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tile.icon; color: tile.ink
            font.family: Theme.fontIcon; font.pixelSize: 22
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - 12
            Text {
                width: parent.width; text: tile.label; elide: Text.ElideRight; color: tile.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
            }
            Text {
                width: parent.width; visible: tile.subtitle !== ""; text: tile.subtitle
                elide: Text.ElideRight; color: tile.ink; opacity: 0.75
                font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
}

import QtQuick
import qs.config

// A control-center tile: glyph, label, optional subtitle. On = primary, off = a raised surface.
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool checked: false
    property bool chevron: false
    signal clicked()
    signal chevronClicked()

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
            width: parent.width - 22 - 12 - (tile.chevron ? 22 : 0)
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
    // Opens the tile's sub-page; sits above the tile's own click area.
    Item {
        visible: tile.chevron
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 40
        Text {
            anchors.centerIn: parent; text: "chevron_right"; color: tile.ink
            font.family: Theme.fontIcon; font.pixelSize: 22
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tile.chevronClicked() }
    }
}

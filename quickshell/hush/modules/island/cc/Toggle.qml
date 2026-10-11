import QtQuick
import qs.config

// A control-center tile: glyph, label, optional subtitle. On = primary, off = a raised surface.
// `compact` (a 1x1 tile, or a short row) drops the chevron (a long press then opens the sub-page) and
// tightens the type; the subtitle shows whenever the tile is at least 48 px tall. A tile with
// `toggle: false` is a plain button (Lock, Theme, Wallpapers, Settings).
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool checked: false
    property bool chevron: false
    property bool compact: false
    property bool toggle: true
    signal clicked()
    signal chevronClicked()

    readonly property bool showSub: subtitle !== "" && height >= 48
    readonly property bool showChevron: chevron && !compact
    implicitHeight: 56
    radius: Math.min(14, height / 2)
    color: checked ? Colors.islandPrimary : Colors.islandSurfaceHigh
    Behavior on color { ColorAnimation { duration: Theme.durationShort } }
    readonly property color ink: checked ? Colors.islandOnPrimary : Colors.islandFg

    Row {
        anchors.fill: parent; anchors.leftMargin: tile.compact ? 12 : 14; anchors.rightMargin: tile.compact ? 8 : 12
        spacing: tile.compact ? 8 : 12
        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: tile.icon; color: tile.ink
            font.family: Theme.fontIcon; font.pixelSize: tile.compact ? 20 : 22
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - glyph.width - parent.spacing - (tile.showChevron ? 22 : 0)
            Text {
                width: parent.width; text: tile.label; elide: Text.ElideRight; color: tile.ink
                font.family: Theme.fontUi; font.pixelSize: tile.compact ? 12 : Theme.textControl; font.weight: Font.Medium
            }
            Text {
                width: parent.width; visible: tile.showSub; text: tile.subtitle
                elide: Text.ElideRight; color: tile.ink; opacity: 0.75
                font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked()
        onPressAndHold: if (tile.chevron && tile.compact) tile.chevronClicked()
        Accessible.role: tile.toggle ? Accessible.CheckBox : Accessible.Button; Accessible.name: tile.label
        Accessible.checked: tile.checked
        Accessible.description: tile.subtitle + (tile.chevron && tile.compact ? ". Long press for the " + tile.label + " page" : "") }
    // Opens the tile's sub-page; sits above the tile's own click area.
    Item {
        visible: tile.showChevron
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 40
        Text {
            anchors.centerIn: parent; text: "chevron_right"; color: tile.ink
            font.family: Theme.fontIcon; font.pixelSize: 22
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tile.chevronClicked()
            Accessible.role: Accessible.Button; Accessible.name: "Open " + tile.label + " page" }
    }
}

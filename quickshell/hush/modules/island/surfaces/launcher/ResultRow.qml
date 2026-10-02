import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config

// One launcher result: icon, name, right-aligned hint.
Item {
    id: row
    property var entry
    property bool selected: false
    signal clicked()
    signal hovered()
    height: 44

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: row.selected ? Colors.alpha(Colors.primary, 0.16) : "transparent"
    }
    IconImage {
        id: icon
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        implicitSize: 28
        asynchronous: true
        source: Quickshell.iconPath(row.entry ? row.entry.icon : "", "application-x-executable")
    }
    Text {
        id: hint
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, parent.width * 0.4)
        elide: Text.ElideRight
        text: row.entry ? row.entry.hint : ""
        font.family: Theme.fontUi
        font.pixelSize: 12
        color: Colors.on_surface_variant
    }
    Text {
        anchors { left: icon.right; leftMargin: 12; right: hint.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: row.entry ? row.entry.name : ""
        font.family: Theme.fontUi
        font.pixelSize: Theme.textLauncher
        color: row.selected ? Colors.primary : Colors.on_surface
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: row.hovered()
        onClicked: row.clicked()
    }
}

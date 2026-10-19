import QtQuick
import qs.config

// One row on the tray page: an app (modelData.item, a SystemTrayItem: its icon, or the title's first
// letter in a circle until the image loads, and title) or an entry of the open menu (modelData.entry,
// a QsMenuEntry). A tap activates the app; a right click, the trailing glyph, or a tap on a menu-only
// app lists its menu (host.openTrayMenu). An entry triggers on tap; one with children opens them.
Rectangle {
    id: row
    required property var modelData
    property var host
    readonly property var item: modelData.item || null
    readonly property var entry: modelData.entry || null
    readonly property string glyph: item ? (item.hasMenu ? "more_vert" : "")
        : entry.hasChildren ? "chevron_right" : entry.checkState === Qt.Checked ? "check" : ""
    function tap(menu) {
        if (item) { if (menu || item.onlyMenu) host.openTrayMenu(item); else item.activate() }
        else if (entry.hasChildren) host.trayMenu = entry
        else { entry.triggered(); host.back() }
    }

    width: ListView.view ? ListView.view.width : 0
    height: 40; radius: 12; color: Colors.islandSurfaceHigh

    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => row.tap(mouse.button === Qt.RightButton)
        Accessible.role: Accessible.Button; Accessible.name: row.modelData.label
    }
    Image {
        id: icon
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 20; height: 20; sourceSize: Qt.size(40, 40)
        source: (row.item || row.entry).icon; asynchronous: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: icon; radius: 10; visible: !icon.visible && row.item; color: Colors.islandSurfaceHighest
        Text {
            anchors.centerIn: parent; text: row.modelData.label.charAt(0).toUpperCase(); color: Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold
        }
    }
    Text {
        anchors { left: icon.right; leftMargin: 12; right: trail.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: row.modelData.label; elide: Text.ElideRight; color: Colors.islandFg
        font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
    }
    Item {
        id: trail
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: visible ? 40 : 14; visible: row.glyph !== ""
        Text {
            anchors.centerIn: parent; text: row.glyph; color: Colors.islandFg; opacity: 0.8
            font.family: Theme.fontIcon; font.pixelSize: 18
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.tap(true)
            Accessible.role: Accessible.Button; Accessible.name: row.modelData.label + (row.item ? " menu" : "") }
    }
}

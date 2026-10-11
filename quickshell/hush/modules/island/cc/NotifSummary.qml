import QtQuick
import qs.config
import qs.services as Svc

// The control center's top row when nothing is playing: notification count and the newest one,
// with Clear and Open (the notification center). Same 44 px footprint as the media row.
Item {
    id: row
    signal openCenter()
    implicitHeight: 44
    readonly property int count: Svc.Notifs.count
    readonly property var latest: count > 0 ? Svc.Notifs.list[0] : null

    Rectangle {
        id: box
        width: 44; height: 44; radius: 10; color: Colors.islandSurfaceHigh
        Text {
            anchors.centerIn: parent
            text: Svc.Notifs.dnd ? "notifications_off" : row.count > 0 ? "notifications_unread" : "notifications"
            color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 22
        }
    }
    Column {
        anchors { left: box.right; leftMargin: 12; right: buttons.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        Text {
            objectName: "notifSummaryTitle"
            width: parent.width; elide: Text.ElideRight; color: Colors.islandFg
            text: row.count === 0 ? "No notifications" : row.count === 1 ? "1 notification" : row.count + " notifications"
            font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
        }
        Text {
            width: parent.width; elide: Text.ElideRight; color: Colors.islandFg; opacity: 0.7
            text: row.latest ? (row.latest.appName ? row.latest.appName + ": " : "") + row.latest.summary
                : Svc.Notifs.dnd ? "Do not disturb is on" : "All caught up"
            textFormat: Text.PlainText
            font.family: Theme.fontUi; font.pixelSize: 12
        }
    }
    Row {
        id: buttons
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 6
        PillButton { objectName: "notifClear"; visible: row.count > 0; text: "Clear"; onClicked: Svc.Notifs.clearAll() }
        PillButton { objectName: "notifOpen"; text: "Open"; onClicked: row.openCenter() }
    }
}

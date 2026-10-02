import QtQuick
import qs.config
import qs.modules.island.notif

// Notification center surface (design 2.6): notifications grouped by app (each group collapsible),
// inline actions, per-notification dismiss, Clear all, a Do-not-disturb toggle, and a scrolling list.
// `host` is the notification service (Notifs: list, dnd, dismiss, clearAll, invokeDefault, iconSource);
// the shell wiring sets `host: Notifs`, the harness passes a fake so it never owns the D-Bus server.
Item {
    id: center
    property size size: Sizes.notifCenter
    property var host: null
    property var collapsed: ({})
    readonly property var notifs: host ? host.list : []
    // Insertion-ordered groups by app name: [{ app, items }], newest group first (list is newest first).
    readonly property var groups: {
        const order = [], map = {}
        for (const n of notifs) {
            const k = n.appName || "Notifications"
            if (!map[k]) { map[k] = { app: k, items: [] }; order.push(map[k]) }
            map[k].items.push(n)
        }
        return order
    }
    readonly property int groupCount: groups.length
    readonly property int count: notifs.length
    readonly property bool dnd: host ? host.dnd : false

    function toggleGroup(app) {
        const c = Object.assign({}, collapsed); c[app] = !c[app]; collapsed = c
    }

    Item {
        anchors.fill: parent; anchors.margins: 16

        Row {
            id: head
            width: parent.width; height: 28; spacing: 8
            Text {
                width: parent.width - dndChip.width - clearChip.width - 16; height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: "Notifications"; color: Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Rectangle {
                id: dndChip
                width: dndRow.implicitWidth + 20; height: 28; radius: 14
                color: center.dnd ? Colors.islandPrimary : (dndHit.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh)
                Row {
                    id: dndRow; anchors.centerIn: parent; spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: center.dnd ? "notifications_off" : "notifications_paused"
                        color: center.dnd ? Colors.islandOnPrimary : Colors.islandFgVar
                        font.family: Theme.fontIcon; font.pixelSize: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Do not disturb"; color: center.dnd ? Colors.islandOnPrimary : Colors.islandFg
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                    }
                }
                MouseArea { id: dndHit; anchors.fill: parent; hoverEnabled: true; onClicked: center.host.dnd = !center.host.dnd }
            }
            Rectangle {
                id: clearChip
                width: clearText.implicitWidth + 20; height: 28; radius: 14
                opacity: center.count > 0 ? 1 : 0.4
                color: clearHit.containsMouse && center.count > 0 ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                Text {
                    id: clearText; anchors.centerIn: parent; text: "Clear all"; color: Colors.islandFg
                    font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                }
                MouseArea { id: clearHit; anchors.fill: parent; hoverEnabled: true; enabled: center.count > 0; onClicked: center.host.clearAll() }
            }
        }

        Flickable {
            id: flick
            anchors { top: head.bottom; topMargin: 10; bottom: parent.bottom; left: parent.left; right: parent.right }
            clip: true; boundsBehavior: Flickable.StopAtBounds
            contentWidth: width; contentHeight: list.implicitHeight
            visible: center.count > 0

            Column {
                id: list
                width: flick.width; spacing: 10
                Repeater {
                    model: center.groups
                    delegate: Column {
                        id: grp
                        required property var modelData
                        readonly property bool open: !center.collapsed[modelData.app]
                        width: list.width; spacing: 6
                        Item {
                            width: parent.width; height: 22
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: grp.open ? "expand_more" : "chevron_right"; color: Colors.islandFgVar
                                font.family: Theme.fontIcon; font.pixelSize: 18
                            }
                            Text {
                                x: 22; anchors.verticalCenter: parent.verticalCenter
                                text: grp.modelData.app + "  ·  " + grp.modelData.items.length
                                color: Colors.islandFgVar
                                font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                            }
                            MouseArea { anchors.fill: parent; onClicked: center.toggleGroup(grp.modelData.app) }
                        }
                        Repeater {
                            model: grp.open ? grp.modelData.items : []
                            delegate: NotifRow {
                                required property var modelData
                                width: grp.width - (list.height > flick.height ? 10 : 0)
                                host: center.host; notif: modelData
                            }
                        }
                    }
                }
            }
        }

        Column {
            x: (parent.width - width) / 2; y: head.height + 10 + (parent.height - head.height - 10 - height) / 2
            spacing: 6; visible: center.count === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "notifications"; color: Colors.islandFgVar; opacity: 0.5
                font.family: Theme.fontIcon; font.pixelSize: 36
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"; color: Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 13
            }
        }
    }
}

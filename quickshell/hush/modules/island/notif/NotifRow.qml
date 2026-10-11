import QtQuick
import Quickshell.Widgets
import qs.config

// One notification in the center: icon, summary, body, inline actions, dismiss. Talks to
// `host` (the notification service, or a fake in the harness).
Rectangle {
    id: card
    property var host: null
    property var notif: null
    readonly property var extraActions: notif && notif.actions ? notif.actions.filter(a => a.identifier !== "default") : []
    implicitHeight: content.implicitHeight + 20
    radius: 14
    color: area.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh

    MouseArea {
        id: area
        anchors.fill: parent; hoverEnabled: true
        onClicked: if (card.host.invokeDefault(card.notif) && card.notif && !card.notif.resident) card.host.dismiss(card.notif)
        Accessible.role: Accessible.Button; Accessible.name: "Open notification: " + (card.notif ? card.notif.summary : "")
    }

    Item {
        x: 12; y: 10; width: 24; height: 24
        IconImage {
            id: icon
            anchors.fill: parent; asynchronous: true; implicitSize: 48
            source: card.host.iconSource(card.notif)
            visible: source != "" && status === Image.Ready
        }
        Text {
            anchors.centerIn: parent; visible: !icon.visible
            text: "notifications"; color: Colors.islandFgVar
            font.family: Theme.fontIcon; font.pixelSize: 20
        }
    }

    Column {
        id: content
        x: 46; y: 10
        width: card.width - 46 - 40
        spacing: 2
        Text {
            width: parent.width
            text: card.notif ? card.notif.summary : ""
            elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
            color: Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: card.notif ? card.notif.body : ""
            wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 3; textFormat: Text.PlainText
            color: Colors.islandFgVar
            font.family: Theme.fontUi; font.pixelSize: 12
        }
        Flow {
            width: parent.width
            visible: card.extraActions.length > 0
            spacing: 6; topPadding: 4
            Repeater {
                model: card.extraActions
                delegate: Rectangle {
                    required property var modelData
                    width: actText.implicitWidth + 20; height: 26; radius: 13
                    color: actArea.containsMouse ? Colors.islandSecondaryContainer : Colors.islandSurface
                    Text {
                        id: actText
                        anchors.centerIn: parent; text: modelData.text
                        color: Colors.islandOnSecondaryContainer
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    MouseArea { id: actArea; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.invoke(); Accessible.role: Accessible.Button; Accessible.name: modelData.text }
                }
            }
        }
    }

    Text {
        anchors { right: parent.right; top: parent.top; rightMargin: 12; topMargin: 10 }
        text: "close"; color: closeArea.containsMouse ? Colors.islandFg : Colors.islandFgVar
        font.family: Theme.fontIcon; font.pixelSize: 18
        MouseArea { id: closeArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: card.host.dismiss(card.notif); Accessible.role: Accessible.Button; Accessible.name: "Dismiss notification" }
    }
}

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// One notification in the drawer: icon, summary, body, actions, dismiss.
Rectangle {
    id: card
    property var notif: null
    readonly property var extraActions: notif ? notif.actions.filter(a => a.identifier !== "default") : []
    implicitHeight: content.implicitHeight + 24
    radius: 14
    color: area.containsMouse ? Colors.surface_container_highest : Colors.surface_container_high

    MouseArea {
        id: area
        anchors.fill: parent; hoverEnabled: true
        onClicked: if (Notifs.invokeDefault(card.notif) && card.notif && !card.notif.resident) Notifs.dismiss(card.notif)
    }

    Item {
        id: iconBox
        x: 12; y: 12; width: 24; height: 24
        IconImage {
            id: icon
            anchors.fill: parent; asynchronous: true; implicitSize: 48
            source: Notifs.iconSource(card.notif)
            visible: source != "" && status === Image.Ready
        }
        Text {
            anchors.centerIn: parent; visible: !icon.visible
            text: "notifications"; color: Colors.on_surface_variant
            font.family: Theme.fontIcon; font.pixelSize: 20
        }
    }

    Column {
        id: content
        x: 46; y: 12
        width: card.width - 46 - 40
        spacing: 2
        Text {
            width: parent.width
            text: card.notif ? card.notif.summary : ""
            elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
            color: Colors.on_surface
            font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: card.notif ? card.notif.body : ""
            wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 4; textFormat: Text.PlainText
            color: Colors.on_surface_variant
            font.family: Theme.fontUi; font.pixelSize: 12
        }
        Flow {
            width: parent.width
            visible: card.extraActions.length > 0
            spacing: 6; topPadding: 6
            Repeater {
                model: card.extraActions
                delegate: Rectangle {
                    required property var modelData
                    width: actText.implicitWidth + 20; height: 26; radius: 13
                    color: actArea.containsMouse ? Colors.secondary_container : Colors.surface_container
                    Text {
                        id: actText
                        anchors.centerIn: parent; text: modelData.text
                        color: Colors.on_secondary_container
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    MouseArea { id: actArea; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.invoke() }
                }
            }
        }
    }

    Text {
        anchors { right: parent.right; top: parent.top; rightMargin: 12; topMargin: 12 }
        text: "close"; color: closeArea.containsMouse ? Colors.on_surface : Colors.on_surface_variant
        font.family: Theme.fontIcon; font.pixelSize: 18
        MouseArea { id: closeArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: Notifs.dismiss(card.notif) }
    }
}

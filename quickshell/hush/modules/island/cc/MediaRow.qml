import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services as Svc

// Now playing inside the control center. Collapses to nothing when no player exists.
Item {
    id: row
    readonly property bool shown: Svc.Media.player !== null
    visible: shown
    implicitHeight: shown ? 44 : 0

    ClippingRectangle {
        id: artBox
        width: 44; height: 44; radius: 10; color: Colors.surface_container_high
        Image {
            id: art
            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
            source: Svc.Media.artUrl; sourceSize: Qt.size(88, 88); asynchronous: true
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent; visible: art.status !== Image.Ready
            text: "music_note"; color: Colors.on_surface
            font.family: Theme.fontIcon; font.pixelSize: 22
        }
    }
    Column {
        anchors.left: artBox.right; anchors.leftMargin: 12; anchors.right: controls.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        Text {
            width: parent.width; text: Svc.Media.title; elide: Text.ElideRight; color: Colors.darkOnSurface
            font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
        }
        Text {
            width: parent.width; text: Svc.Media.artist; visible: text !== ""; elide: Text.ElideRight
            color: Colors.darkOnSurface; opacity: 0.7
            font.family: Theme.fontUi; font.pixelSize: 12
        }
    }
    Row {
        id: controls
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
        Repeater {
            model: [
                { g: "skip_previous", f: "previous" },
                { g: Svc.Media.playing ? "pause" : "play_arrow", f: "toggle" },
                { g: "skip_next", f: "next" }
            ]
            delegate: Text {
                required property var modelData
                width: 32; height: 32; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: modelData.g; color: Colors.darkOnSurface
                font.family: Theme.fontIcon; font.pixelSize: 24
                MouseArea { anchors.fill: parent; onClicked: Svc.Media[modelData.f]() }
            }
        }
    }
}

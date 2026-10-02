import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services as Svc

// Now playing: art, "title · artist", play/pause, and a 2 px progress line.
StateBase {
    id: media
    name: "media"; size: Qt.size(420, 36); priority: 1

    Row {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 14; spacing: 10
        ClippingRectangle {
            width: 24; height: 24; radius: 6; color: Colors.alpha(media.island ? media.island.fg : Colors.darkOnSurface, 0.08)
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: art
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                source: Svc.Media.artUrl; sourceSize: Qt.size(48, 48); asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent; visible: art.status !== Image.Ready
                text: "music_note"; color: Colors.darkOnSurface
                font.family: Theme.fontIcon; font.pixelSize: 16
            }
        }
        Text {
            width: parent.width - 24 - 20 - 20 - 20
            anchors.verticalCenter: parent.verticalCenter
            text: Svc.Media.artist ? Svc.Media.title + " · " + Svc.Media.artist : Svc.Media.title
            elide: Text.ElideMiddle; color: Colors.darkOnSurface
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        }
        Text {
            width: 20; horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: Svc.Media.playing ? "pause" : "play_arrow"; color: Colors.darkOnSurface
            font.family: Theme.fontIcon; font.pixelSize: 20
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Svc.Media.toggle() }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        height: 2; color: Colors.primary
        width: Svc.Media.length > 0 ? Math.min(1, Svc.Media.position / Svc.Media.length) * parent.width : 0
    }
}

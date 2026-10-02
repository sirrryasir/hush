import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services as Svc

// The 1.1 s "now playing" card raised on a track change: art, "title · artist", play/pause and a
// 2 px progress line. A click on the card opens the media surface.
StateBase {
    id: media
    name: "media"; size: Sizes.media; priority: 1
    readonly property color fg: island ? island.fg : Colors.darkOnSurface

    MouseArea {
        anchors.fill: parent
        Accessible.role: Accessible.Button
        Accessible.name: "Now playing: " + Svc.Media.title + ". Open media"
        onClicked: if (media.island) media.island.openSurface("mediaSurface")
    }
    Row {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 14; spacing: 10
        ClippingRectangle {
            width: 24; height: 24; radius: 12; color: Colors.alpha(media.fg, 0.08)
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: art
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                source: Svc.Media.artUrl; sourceSize: Qt.size(48, 48); asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent; visible: art.status !== Image.Ready
                text: "music_note"; color: media.fg
                font.family: Theme.fontIcon; font.pixelSize: 16
            }
        }
        Text {
            width: parent.width - 24 - 20 - 20 - 20
            anchors.verticalCenter: parent.verticalCenter
            text: Svc.Media.artist ? Svc.Media.title + " · " + Svc.Media.artist : Svc.Media.title
            elide: Text.ElideMiddle; color: media.fg
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        }
        Text {
            width: 20; horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: Svc.Media.playing ? "pause" : "play_arrow"; color: media.fg
            font.family: Theme.fontIcon; font.pixelSize: 20
            MouseArea {
                anchors.fill: parent; anchors.margins: -6; onClicked: Svc.Media.toggle()
                Accessible.role: Accessible.Button; Accessible.name: Svc.Media.playing ? "Pause" : "Play"
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.leftMargin: 18
        height: 2; radius: 1; color: Colors.darkPrimary
        width: Svc.Media.length > 0 ? Math.min(1, Svc.Media.position / Svc.Media.length) * (parent.width - 36) : 0
    }
}

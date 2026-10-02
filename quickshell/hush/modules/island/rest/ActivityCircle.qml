import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// Left slot of the rest pill (design 2.1): album art in a circle with a thin progress ring while a
// media player exists, a music-note glyph when it has no art. `shown` is false when there is nothing
// to show; the parent then collapses the slot so the pill narrows.
Item {
    id: root
    readonly property bool shown: Media.player !== null && Media.playing
    readonly property real progress: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
    readonly property bool hasArt: Media.artUrl !== "" && art.status === Image.Ready
    implicitWidth: 24; implicitHeight: 24
    width: implicitWidth; height: implicitHeight

    Item {
        id: disc
        anchors.centerIn: parent; width: 18; height: 18
        Image {
            id: art
            anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop
            sourceSize.width: 48; sourceSize.height: 48; asynchronous: true
            visible: false; layer.enabled: true
        }
        // A visible copy through the mask; the plain Image above only feeds it.
        MultiEffect { anchors.fill: parent; source: art; visible: root.hasArt; maskEnabled: true; maskSource: maskItem
            maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Item { id: maskItem; anchors.fill: parent; visible: false; layer.enabled: true
            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
        Rectangle { anchors.fill: parent; radius: width / 2; visible: !root.hasArt; color: Qt.rgba(1, 1, 1, 0.10)
            Text { anchors.centerIn: parent; text: "music_note"; font.family: Theme.fontIcon; font.pixelSize: 12; color: Colors.darkOnSurface } }
    }
    Canvas {
        id: ring
        anchors.fill: parent
        property real p: root.progress
        property color track: Qt.rgba(1, 1, 1, 0.16)
        property color fill: Colors.darkPrimary
        onPChanged: requestPaint(); onFillChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.lineWidth = 1.5; c.lineCap = "round"
            const cx = width / 2, cy = height / 2, r = width / 2 - 1.25
            c.strokeStyle = track; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (p > 0.005) { c.strokeStyle = fill; c.beginPath(); c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
        }
    }
}

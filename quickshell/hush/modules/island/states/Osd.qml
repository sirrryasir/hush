import QtQuick
import qs.config
import qs.services

// Volume / mic / brightness readout: glyph and a thin level track.
StateBase {
    id: osd
    name: "osd"; size: Qt.size(300, 36); priority: 2
    property string kind: "volume"
    readonly property real level: kind === "brightness" ? Brightness.level
        : kind === "mic" ? (Audio.micMuted ? 0 : 1) : (Audio.muted ? 0 : Audio.volume)
    readonly property string glyph: kind === "brightness" ? "brightness_6"
        : kind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
        : (Audio.muted || Audio.volume <= 0 ? "volume_off" : "volume_up")

    Row {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
        Text {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            text: osd.glyph; color: osd.island ? osd.island.fg : Colors.on_surface
            font.family: Theme.fontIcon; font.pixelSize: 20
        }
        Rectangle {
            width: parent.width - icon.width - 12; height: 4; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.alpha(osd.island ? osd.island.fg : Colors.on_surface, 0.2)
            Rectangle {
                height: parent.height; radius: 2
                color: osd.island ? osd.island.fg : Colors.on_surface
                width: parent.width * Math.max(0, Math.min(1, osd.level))
                Behavior on width { NumberAnimation { duration: Theme.durationShort } }
            }
        }
    }
}

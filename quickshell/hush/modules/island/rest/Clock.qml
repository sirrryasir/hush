import QtQuick
import Quickshell
import qs.config

// Centre slot: Inter 13, tabular digits. Its width is fixed from a wide sample ("00:00" in tabular
// figures), so a minute tick never changes the pill width and the morph is never retriggered.
Item {
    id: root
    SystemClock { id: src; precision: SystemClock.Minutes }
    readonly property string text: Qt.formatTime(src.date, "hh:mm")
    implicitWidth: Math.ceil(metrics.width); implicitHeight: 16
    width: implicitWidth; height: implicitHeight
    TextMetrics { id: metrics; text: "00:00"; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        font.features: ({ "tnum": 1 }) }
    Text {
        anchors.centerIn: parent; text: root.text; color: Colors.darkOnSurface
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
    }
}

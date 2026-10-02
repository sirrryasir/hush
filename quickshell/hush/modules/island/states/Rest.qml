import QtQuick
import Quickshell
import qs.config

// The island at rest: theme dot, date (or a media title once B3 provides one), clock.
StateBase {
    id: rest
    name: "rest"; size: Theme.islandRest; priority: 0

    SystemClock { id: clockSrc; precision: SystemClock.Minutes }

    Row {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
        Rectangle {
            width: 8; height: 8; radius: 4; color: Colors.darkPrimary
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
        }
        Text {
            id: center
            width: parent.width - 8 - 10 - clock.width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: rest.island ? rest.island.restCenterText : ""
            elide: Text.ElideRight; color: Colors.darkOnSurface
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        }
        Text {
            id: clock
            anchors.verticalCenter: parent.verticalCenter; color: Colors.darkOnSurface
            text: Qt.formatTime(clockSrc.date, "hh:mm")
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }
}

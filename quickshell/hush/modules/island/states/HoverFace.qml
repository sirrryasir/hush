import QtQuick
import Quickshell
import qs.config
import qs.services as Svc

// The hover face (design 2.2), 320x44: this monitor's workspaces as dots with the active one drawn
// as a pill, the date, and the media title while something plays. A dot goes to its workspace and
// the date opens the calendar; any other left click falls through to the pill's click mapping.
StateBase {
    id: face
    name: "hover"; size: Sizes.hover; priority: 1
    readonly property color fg: island ? island.fg : Colors.darkOnSurface
    readonly property var workspaces: Svc.Hypr.workspacesFor(island ? island.screenName : Svc.Hypr.focusedMonitorName)
    readonly property string title: Svc.Media.playing ? (Svc.Media.title || "") : ""

    Row {
        id: dots
        anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Repeater {
            model: face.workspaces
            delegate: Rectangle {
                required property var modelData
                width: modelData.active ? 18 : 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.alpha(face.fg, modelData.active ? 1 : (modelData.occupied ? 0.55 : 0.22))
                Behavior on width { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    onClicked: Svc.Hypr.go(parent.modelData.id)
                }
            }
        }
    }
    Text {
        id: date
        anchors.left: dots.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDate(clock.date, "ddd d MMM")
        color: face.fg
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        MouseArea {
            anchors.fill: parent; anchors.margins: -6
            onClicked: if (face.island) face.island.openSurface("calendar")
        }
    }
    Text {
        anchors.left: date.right; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        visible: face.title !== ""
        text: face.title; elide: Text.ElideRight; maximumLineCount: 1
        color: Colors.alpha(face.fg, 0.7)
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland
    }
    SystemClock { id: clock; precision: SystemClock.Hours }
}

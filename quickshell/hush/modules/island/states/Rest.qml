import QtQuick
import Quickshell
import qs.config
import "../rest"

// The island at rest (design 2.1): activity circle (collapses when empty), clock, status ring.
// A playing player shows here as the circle (art + progress ring); there is no media capsule state.
// The pill's width is this row's width on the 8 px grid, so an empty activity slot narrows it.
StateBase {
    id: rest
    name: "rest"; priority: 0
    readonly property int pad: 14
    readonly property int gap: 10
    size: Qt.size(Sizes.snap(pad * 2 + (activity.shown ? activity.width + gap : 0) + clock.width + gap + ring.width), 36)

    Binding { target: rest.island; property: "restClock"; value: clock.text; when: rest.island !== null }
    Binding { target: rest.island; property: "restWidth"; value: rest.size.width; when: rest.island !== null }

    Row {
        anchors.centerIn: parent; spacing: rest.gap
        ActivityCircle {
            id: activity; objectName: "activityCircle"
            visible: shown; anchors.verticalCenter: parent.verticalCenter
            // Media at rest: a click on the circle opens the media surface (middle click anywhere does too).
            MouseArea {
                anchors.fill: parent; anchors.margins: -5
                enabled: activity.mode === "media"
                Accessible.role: Accessible.Button; Accessible.name: "Now playing. Open media"
                onClicked: if (rest.island) rest.island.openSurface("mediaSurface")
            }
        }
        Clock { id: clock; anchors.verticalCenter: parent.verticalCenter }
        StatusRing { id: ring; anchors.verticalCenter: parent.verticalCenter }
    }
}

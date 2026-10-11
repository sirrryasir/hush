import QtQuick
import Quickshell
import qs.config
import "../rest"

// The island at rest: activity circle (collapses when empty), clock, status ring.
// layout.rest (Composer) picks the sides: left "activity" | "none", right "status" | "none"; the
// clock is always the centre.
// A playing player shows here as the circle (art + progress ring); there is no media capsule state.
// The pill's width is this row's width on the 8 px grid, so an empty activity slot narrows it.
StateBase {
    id: rest
    name: "rest"; priority: 0
    readonly property int pad: 14
    readonly property int gap: 10
    readonly property bool activityOn: activity.shown && Composer.restLeft === "activity"
    size: Qt.size(Sizes.snap(pad * 2 + (rest.activityOn ? activity.width + gap : 0) + clock.width + (ring.visible ? gap + ring.width : 0)), 36)

    Binding { target: rest.island; property: "restClock"; value: clock.text; when: rest.island !== null }
    Binding { target: rest.island; property: "restWidth"; value: rest.size.width; when: rest.island !== null }

    Row {
        anchors.centerIn: parent; spacing: rest.gap
        ActivityCircle {
            id: activity; objectName: "activityCircle"
            visible: rest.activityOn; anchors.verticalCenter: parent.verticalCenter
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

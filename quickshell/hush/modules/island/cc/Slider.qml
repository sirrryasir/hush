import QtQuick
import qs.config

// A glyph plus a 6 px track with a 16 px knob. `value` is 0..1 from the outside; dragging
// emits moved(v) and shows the dragged value until released.
Item {
    id: root
    property string icon: ""
    property real value: 0
    signal moved(real v)
    property real dragValue: 0
    readonly property real shown: area.pressed ? dragValue : value

    implicitHeight: 24

    Text {
        id: glyph
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        width: 20; horizontalAlignment: Text.AlignHCenter
        text: root.icon; color: Colors.darkOnSurface
        font.family: Theme.fontIcon; font.pixelSize: 18
    }
    Item {
        id: track
        anchors.left: glyph.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter; height: 16
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3
            color: Colors.surface_container_highest
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter; height: 6; radius: 3
            width: root.shown * (track.width - 16) + 8
            color: Colors.primary
        }
        Rectangle {
            width: 16; height: 16; radius: 8; color: Colors.primary
            anchors.verticalCenter: parent.verticalCenter
            x: root.shown * (track.width - 16)
        }
        MouseArea {
            id: area
            anchors.fill: parent; anchors.margins: -4
            function setFrom(mx) {
                const v = Math.max(0, Math.min(1, (mx - 4 - 8) / (track.width - 16)))
                root.dragValue = v; root.moved(v)
            }
            onPressed: mouse => setFrom(mouse.x)
            onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
        }
    }
}

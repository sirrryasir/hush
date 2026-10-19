import QtQuick
import qs.config

// A glyph plus a 6 px track with a 16 px knob. `value` is 0..1 from the outside; dragging
// emits moved(v) and shows the dragged value until released. `chevron` adds an end glyph that
// opens a sub-page (chevronClicked), as on a tile.
Item {
    id: root
    property string icon: ""
    property string label: ""
    property bool chevron: false
    signal chevronClicked()
    property real step: 0.05
    property real value: 0
    signal moved(real v)
    property real dragValue: 0
    readonly property real shown: area.pressed ? dragValue : value

    implicitHeight: 24

    Text {
        id: glyph
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        width: root.icon !== "" ? 20 : 0; horizontalAlignment: Text.AlignHCenter
        text: root.icon; color: Colors.islandFg
        font.family: Theme.fontIcon; font.pixelSize: 18
    }
    Item {
        id: tail
        visible: root.chevron; width: visible ? 20 : 0
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        Text { anchors.centerIn: parent; text: "chevron_right"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 18 }
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.chevronClicked()
            Accessible.role: Accessible.Button; Accessible.name: "Open " + root.label + " page" }
    }
    Item {
        id: track
        anchors.left: glyph.right; anchors.leftMargin: root.icon !== "" ? 8 : 0; anchors.right: tail.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter; height: 16
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3
            color: Colors.islandSurfaceHighest
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter; height: 6; radius: 3
            width: root.shown * (track.width - 16) + 8
            color: Colors.islandPrimary
        }
        Rectangle {
            width: 16; height: 16; radius: 8; color: Colors.islandPrimary
            anchors.verticalCenter: parent.verticalCenter
            x: root.shown * (track.width - 16)
        }
        MouseArea {
            id: area
            Accessible.role: Accessible.Slider; Accessible.name: root.label || root.icon
            Accessible.description: Math.round(root.value * 100) + " percent"
            // Keyboard (the island's navigator calls this on Left/Right): n steps, clamped, committed.
            function stepAdjust(n) { const v = Math.max(0, Math.min(1, root.value + n * root.step)); root.dragValue = v; root.moved(v) }
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

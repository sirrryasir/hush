import QtQuick
import qs.config

// A small capsule button for list rows and the summary row: text, or a lone glyph when `glyph` is set
// and `text` is empty. `primary` fills it with the primary colour.
Rectangle {
    id: btn
    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool enabledLook: true
    signal clicked()
    implicitHeight: 28
    implicitWidth: text !== "" ? label.implicitWidth + (glyph !== "" ? 22 : 0) + 24 : 28
    radius: height / 2
    color: primary ? Colors.islandPrimary : Colors.islandSurfaceHighest
    opacity: enabledLook ? 1 : 0.5
    readonly property color ink: primary ? Colors.islandOnPrimary : Colors.islandFg
    Row {
        anchors.centerIn: parent; spacing: 4
        Text {
            visible: btn.glyph !== ""; anchors.verticalCenter: parent.verticalCenter
            text: btn.glyph; color: btn.ink; font.family: Theme.fontIcon; font.pixelSize: 18
        }
        Text {
            id: label
            visible: btn.text !== ""; anchors.verticalCenter: parent.verticalCenter
            text: btn.text; color: btn.ink
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
        }
    }
    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: if (btn.enabledLook) btn.clicked()
        Accessible.role: Accessible.Button; Accessible.name: btn.text || btn.glyph
    }
}

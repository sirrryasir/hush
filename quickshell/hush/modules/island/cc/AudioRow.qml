import QtQuick
import qs.config
import qs.services as Svc

// One row on the sound page: an output device (tap makes it the default, which is marked), or the
// microphone / a playing application with a level slider and a mute button.
Rectangle {
    id: row
    required property var modelData
    readonly property var node: modelData.node
    readonly property bool device: modelData.kind === "sink"
    readonly property bool active: device && node === Svc.Audio.sink
    readonly property bool muted: !!node && !!node.audio && node.audio.muted
    readonly property color ink: active ? Colors.islandOnPrimaryContainer : Colors.islandFg

    width: ListView.view ? ListView.view.width : 0
    height: 44; radius: 12
    color: active ? Colors.islandPrimaryContainer : Colors.islandSurfaceHigh

    MouseArea {
        anchors.fill: parent; visible: row.device; cursorShape: Qt.PointingHandCursor
        onClicked: Svc.Audio.setSink(row.node)
        Accessible.role: Accessible.Button; Accessible.name: row.modelData.name
    }
    Text {
        id: lead
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        text: row.modelData.icon; color: row.ink; font.family: Theme.fontIcon; font.pixelSize: 20
    }
    Text {
        id: name
        anchors { left: lead.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: row.device ? parent.width - x - 44 : 150
        text: row.modelData.name; elide: Text.ElideRight; color: row.ink
        font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
    }
    Text {
        objectName: "audioDefault"
        visible: row.active
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        text: "check"; color: row.ink; opacity: 0.8; font.family: Theme.fontIcon; font.pixelSize: 18
    }
    Slider {
        objectName: "audioLevel"
        visible: !row.device
        anchors { left: name.right; leftMargin: 12; right: mute.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
        label: row.modelData.name; value: row.node && row.node.audio ? Math.min(1, row.node.audio.volume) : 0
        onMoved: v => { if (row.node && row.node.audio) row.node.audio.volume = v }
    }
    PillButton {
        id: mute
        objectName: "audioMute"
        visible: !row.device
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        glyph: row.modelData.kind === "source" ? (row.muted ? "mic_off" : "mic") : (row.muted ? "volume_off" : "volume_up")
        primary: row.muted; Accessible.name: (row.muted ? "Unmute " : "Mute ") + row.modelData.name
        onClicked: if (row.node && row.node.audio) row.node.audio.muted = !row.node.audio.muted
    }
}

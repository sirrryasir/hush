import QtQuick
import qs.config
import qs.services

// Right slot: a battery arc with one glyph inside it. The glyph is the bolt while charging, else
// Wi-Fi off, Bluetooth connected, or the Wi-Fi bars. Muted theme colours; red only when critical.
Item {
    id: root
    property bool mic: Privacy.micInUse
    property bool camera: Privacy.cameraInUse
    property bool plugged: Battery.justPlugged
    property bool charging: Battery.charging
    readonly property bool critical: Battery.present && !charging && Battery.percent <= 15
    readonly property bool privacy: camera || mic
    readonly property string glyph: camera ? "videocam" : mic ? "mic" : charging ? "bolt"
        : !Net.connected ? "signal_wifi_off" : Bt.connectedName !== "" ? "bluetooth_connected" : Net.icon
    readonly property color glyphColor: privacy ? (Colors.dark.tertiary || Colors.tertiary) : critical ? Colors.darkError : Qt.rgba(Colors.darkOnSurface.r, Colors.darkOnSurface.g, Colors.darkOnSurface.b, 0.78)
    implicitWidth: 24; implicitHeight: 24
    width: implicitWidth; height: implicitHeight

    Canvas {
        id: arc
        anchors.fill: parent
        property real p: Battery.present ? Battery.percent / 100 : 0
        property color fill: root.critical ? Colors.darkError : Colors.darkOnSurface
        onPChanged: requestPaint(); onFillChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.lineWidth = 1.5; c.lineCap = "round"
            const cx = width / 2, cy = height / 2, r = width / 2 - 1.25
            c.strokeStyle = Qt.rgba(1, 1, 1, 0.16); c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (p > 0.005) { c.strokeStyle = Qt.rgba(fill.r, fill.g, fill.b, 0.85); c.beginPath()
                c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
        }
    }
    Text {
        id: glyphText
        anchors.centerIn: parent; text: root.glyph; color: root.glyphColor
        font.family: Theme.fontIcon; font.pixelSize: 13
        objectName: "glyph"
        // Charging bolt pulses for the 2 s after the cable goes in.
        SequentialAnimation on opacity {
            running: root.plugged && !root.privacy; loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) glyphText.opacity = 1
        }
    }
}

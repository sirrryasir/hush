import QtQuick
import qs.config
import qs.services

// Right slot: a battery arc with one glyph inside it. The glyph is the bolt while charging, else
// Wi-Fi off, Bluetooth connected, or the Wi-Fi bars. Muted theme colours; red only when critical.
Item {
    id: root
    readonly property bool critical: Battery.present && !Battery.charging && Battery.percent <= 15
    readonly property string glyph: Battery.charging ? "bolt"
        : !Net.connected ? "signal_wifi_off" : Bt.connectedName !== "" ? "bluetooth_connected" : Net.icon
    readonly property color glyphColor: critical ? Colors.darkError : Qt.rgba(Colors.darkOnSurface.r, Colors.darkOnSurface.g, Colors.darkOnSurface.b, 0.78)
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
        anchors.centerIn: parent; text: root.glyph; color: root.glyphColor
        font.family: Theme.fontIcon; font.pixelSize: 13
    }
}

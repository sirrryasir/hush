import QtQuick
import qs.config
import qs.services

// Right slot: the battery as a gauge (18 % track, 2.5 px fill) with the percentage inside it.
// A glyph replaces the number only while it applies: camera or mic in use, or the bolt while
// charging (pulsing for 2 s after the cable goes in). island.statusCenter picks the resting centre:
// "percent" (default), "wifi" (Wi-Fi off, Bluetooth connected or the Wi-Fi bars) or "none".
// Without a battery the centre falls back to the Wi-Fi glyph. Red only when critical.
Item {
    id: root
    objectName: "statusRing"
    property bool mic: Privacy.micInUse
    property bool camera: Privacy.cameraInUse
    property bool plugged: Battery.justPlugged
    property bool charging: Battery.charging
    readonly property bool critical: Battery.present && !charging && Battery.percent <= 15
    readonly property bool privacy: camera || mic
    readonly property string centerMode: {
        const m = String(Settings.island.statusCenter || "percent")
        return m === "wifi" || m === "none" ? m : "percent"
    }
    readonly property string netGlyph: !Net.connected ? "signal_wifi_off" : Bt.connectedName !== "" ? "bluetooth_connected" : Net.icon
    // The glyph that overrides the centre right now ("" = none applies).
    readonly property string override: camera ? "videocam" : mic ? "mic" : charging ? "bolt" : ""
    readonly property bool showPercent: override === "" && centerMode === "percent" && Battery.present
    readonly property string glyph: override !== "" ? override
        : centerMode === "wifi" || (centerMode === "percent" && !Battery.present) ? netGlyph : ""
    // What the centre shows, for tests: "percent:80", "glyph:<name>" or "none".
    readonly property string center: showPercent ? "percent:" + Battery.percent : glyph !== "" ? "glyph:" + glyph : "none"
    readonly property color fg: Colors.islandFg
    readonly property color glyphColor: privacy ? (Colors.dark.tertiary || Colors.tertiary) : critical ? Colors.islandError : Colors.alpha(fg, 0.78)
    implicitWidth: 24; implicitHeight: 24
    width: implicitWidth; height: implicitHeight

    Canvas {
        id: arc
        anchors.fill: parent
        property real p: Battery.present ? Battery.percent / 100 : 0
        property color fill: root.critical ? Colors.islandError : root.fg
        property color track: Colors.alpha(root.fg, 0.18)
        onPChanged: requestPaint(); onFillChanged: requestPaint(); onTrackChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.lineWidth = 2.5; c.lineCap = "round"
            const cx = width / 2, cy = height / 2, r = width / 2 - 1.5
            c.strokeStyle = track; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (p > 0.005) { c.strokeStyle = fill; c.beginPath()
                c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
        }
    }
    Text {
        id: percentText
        objectName: "percent"
        anchors.centerIn: parent; anchors.verticalCenterOffset: 0.5
        visible: root.showPercent
        text: Battery.percent
        color: root.critical ? Colors.islandError : root.fg
        font.family: Theme.fontUi; font.pixelSize: Battery.percent >= 100 ? 8 : 10
        font.weight: Font.DemiBold; font.features: { "tnum": 1 }
    }
    Text {
        id: glyphText
        anchors.centerIn: parent; text: root.glyph; color: root.glyphColor
        visible: root.glyph !== ""
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

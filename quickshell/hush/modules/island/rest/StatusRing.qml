import QtQuick
import qs.config
import qs.services

// Right slot at rest. island.statusCenter picks what it shows:
//   "none" (default): nothing, so the resting pill is the clock (and the activity circle); the
//     battery lives on the hover face and in the control center. Exceptions: a critical battery
//     (<=15 %, not charging) shows the red battery glyph, and the glyph with its bolt shows for the
//     2 s after the cable goes in;
//   "battery": an iOS-style battery glyph with the percent inside (BatteryGlyph) all the time;
//   "wifi": a thin battery arc with the Wi-Fi glyph (bolt while charging) inside.
// layout.rest.right "none" (Composer) turns the slot off: no statusCenter content and no plug-in
// bolt; a critical battery and the privacy glyphs still show (warnings, not decoration).
// A machine without a battery shows the "wifi" ring in battery mode. Mic and camera in use show as
<<<<<<< HEAD
// small glyphs in every mode (privacy), and a cup while Caffeine (stay awake) is on.
||||||| parent of c9f1f4b (feat(devices): USB glyph on the rest pill)
// small glyphs in every mode (privacy).
=======
// small glyphs in every mode (privacy). A USB glyph shows while a removable drive is plugged in.
>>>>>>> c9f1f4b (feat(devices): USB glyph on the rest pill)
Item {
    id: root
    objectName: "statusRing"
    property bool mic: Privacy.micInUse
    property bool camera: Privacy.cameraInUse
    property bool caffeine: Caffeine.on
    property bool plugged: Battery.justPlugged
    property bool charging: Battery.charging
    readonly property bool critical: Battery.present && !charging && Battery.percent <= 15
    readonly property bool privacy: camera || mic
    // A removable drive is plugged in (the USB glyph, shown while the slot is on).
    readonly property bool usb: Devices.present && slotOn
    readonly property string centerMode: {
        const m = String(Settings.island.statusCenter || "none")
        return m === "wifi" || m === "battery" ? m : "none"
    }
    readonly property bool slotOn: Composer.restRight === "status"
    readonly property bool batteryShown: Battery.present && (critical || slotOn && (centerMode === "battery" || plugged))
    readonly property bool ringShown: slotOn && (centerMode === "wifi" || (centerMode === "battery" && !Battery.present))
    readonly property string netGlyph: !Net.connected ? "signal_wifi_off" : Bt.connectedName !== "" ? "bluetooth_connected" : Net.icon
    readonly property string ringGlyph: charging ? "bolt" : netGlyph
    // The indicator that applies right now (tests): camera, mic, the charging bolt, else the ring glyph.
    readonly property string glyph: camera ? "videocam" : mic ? "mic" : caffeine ? "coffee" : charging && (batteryShown || ringShown || slotOn && plugged) ? "bolt" : ringShown ? netGlyph : ""
    // What the slot shows, for tests: "battery:80", "glyph:<ring glyph>" or "none".
    readonly property string center: batteryShown ? "battery:" + Battery.percent : ringShown ? "glyph:" + ringGlyph : "none"
    readonly property color fg: Colors.islandFg
    readonly property color privacyColor: Colors.dark.tertiary || Colors.tertiary
    implicitWidth: row.implicitWidth; implicitHeight: 24
    width: implicitWidth; height: implicitHeight
    // From the model, not from implicitWidth: a Row skips children that are not effectively visible, so
    // a hidden ring could never get wide enough to show.
    visible: privacy || usb || batteryShown || ringShown

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text {
            objectName: "privacyCamera"
            visible: root.camera; anchors.verticalCenter: parent.verticalCenter
            text: "videocam"; color: root.privacyColor; font.family: Theme.fontIcon; font.pixelSize: 14
        }
        Text {
            objectName: "privacyMic"
            visible: root.mic; anchors.verticalCenter: parent.verticalCenter
            text: "mic"; color: root.privacyColor; font.family: Theme.fontIcon; font.pixelSize: 14
        }
        Text {
<<<<<<< HEAD
            objectName: "caffeineGlyph"
            visible: root.caffeine; anchors.verticalCenter: parent.verticalCenter
            text: "coffee"; color: Colors.darkPrimary; font.family: Theme.fontIcon; font.pixelSize: 14
||||||| parent of c9f1f4b (feat(devices): USB glyph on the rest pill)
=======
            id: usbGlyph
            objectName: "deviceGlyph"
            visible: root.usb; anchors.verticalCenter: parent.verticalCenter
            text: "usb"; color: Colors.alpha(root.fg, 0.78); font.family: Theme.fontIcon; font.pixelSize: 14
>>>>>>> c9f1f4b (feat(devices): USB glyph on the rest pill)
        }
        BatteryGlyph {
            id: battery
            objectName: "batteryGlyph"
            visible: root.batteryShown; anchors.verticalCenter: parent.verticalCenter
            charging: root.charging && (Battery.chargingNow || !Battery.present || root.plugged)
            critical: root.critical; pulse: root.plugged
        }
        Item {
            id: ring
            visible: root.ringShown; width: 24; height: 24
            Canvas {
                id: arc
                anchors.fill: parent
                property real p: Battery.present ? Battery.percent / 100 : 0
                property color fill: root.critical ? Colors.islandError : root.fg
                onPChanged: requestPaint(); onFillChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset(); c.lineWidth = 1.5; c.lineCap = "round"
                    const cx = width / 2, cy = height / 2, r = width / 2 - 1.25
                    c.strokeStyle = Colors.alpha(root.fg, 0.16); c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
                    if (p > 0.005) { c.strokeStyle = Colors.alpha(fill, 0.85); c.beginPath()
                        c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
                }
            }
            Text {
                id: glyphText
                objectName: "glyph"
                anchors.centerIn: parent; text: root.ringGlyph
                color: root.critical ? Colors.islandError : Colors.alpha(root.fg, 0.78)
                font.family: Theme.fontIcon; font.pixelSize: 13
                // Charging bolt pulses for the 2 s after the cable goes in.
                SequentialAnimation on opacity {
                    running: root.plugged; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) glyphText.opacity = 1
                }
            }
        }
    }
}

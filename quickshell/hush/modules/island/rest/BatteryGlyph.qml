import QtQuick
import qs.config
import qs.services

// An iOS-style battery: rounded body with a 1 px islandFgVar outline, a nub on the right, a fill
// that tracks the percent (green, islandError at <=15 % when not charging) and the percentage in
// bold inside the body. The number is knocked out (pill black) where it sits over the fill and
// islandFg over the empty part. While charging a white bolt sits on the nub end, outlined in black.
// Values default to the Battery service; harnesses set them directly.
Item {
    id: root
    property int percent: Battery.percent
    property bool charging: Battery.chargingNow
    property bool critical: Battery.present && !Battery.charging && Battery.percent <= 15
    property bool showNumber: true
    // Pulse the bolt (the 2 s after the cable goes in).
    property bool pulse: false
    // Body size (the nub adds nubW + 1 px); 24x12 at rest.
    property real bodyW: 24
    property real bodyH: 12
    readonly property real nubW: Math.max(1.5, bodyH / 6)
    readonly property real inset: bodyH >= 14 ? 2 : 1.5
    readonly property color fillColor: critical ? Colors.islandError : Colors.islandBatteryGood
    implicitWidth: bodyW + 1 + nubW
    implicitHeight: bodyH

    Rectangle {
        id: body
        width: root.bodyW; height: root.bodyH; radius: root.bodyH * 0.3
        color: "transparent"; border.width: 1; border.color: Colors.islandFgVar
        Item {
            id: inner
            x: root.inset; y: root.inset; width: parent.width - 2 * root.inset; height: parent.height - 2 * root.inset
            Rectangle {
                id: fill
                width: Math.max(0, Math.min(1, root.percent / 100)) * inner.width; height: inner.height
                radius: Math.max(1, body.radius - root.inset); color: root.fillColor
                Behavior on width { NumberAnimation { duration: Theme.durationShort } }
            }
            // The number twice: islandFg everywhere, then a knocked-out copy clipped to the fill.
            Text {
                id: num
                visible: root.showNumber
                x: Math.round((inner.width - (root.charging ? bolt.width * 0.6 : 0) - width) / 2); y: Math.round((inner.height - height) / 2)
                text: root.percent; color: Colors.islandFg
                font.family: Theme.fontUi; font.weight: Font.Bold; font.features: { "tnum": 1 }
                font.pixelSize: Math.round(root.bodyH * (root.percent >= 100 ? 0.62 : 0.72))
            }
            Item {
                visible: root.showNumber
                width: fill.width; height: inner.height; clip: true
                Text {
                    x: num.x; y: num.y; text: num.text; font: num.font
                    color: Colors.islandShadow
                }
            }
        }
    }
    Rectangle {
        x: root.bodyW + 1; anchors.verticalCenter: body.verticalCenter
        width: root.nubW; height: Math.round(root.bodyH * 0.42); radius: width / 2
        color: Colors.islandFgVar
    }
    Text {
        id: bolt
        objectName: "batteryBolt"
        visible: root.charging
        anchors.verticalCenter: body.verticalCenter
        x: root.bodyW - width * 0.55
        text: "bolt"; color: Colors.islandBatteryBolt
        style: Text.Outline; styleColor: Colors.islandShadow
        font.family: Theme.fontIcon; font.pixelSize: Math.round(root.bodyH * 1.05)
        SequentialAnimation on opacity {
            running: root.pulse && root.charging; loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) bolt.opacity = 1
        }
    }
}

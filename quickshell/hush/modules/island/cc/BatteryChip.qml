import QtQuick
import qs.config
import qs.services as Svc

// Control-center battery readout beside the power row: glyph, "80 %" and the state or time
// ("3 h 10 m left", "Charging", "Not charging"). Not shown without a battery.
Row {
    id: chip
    objectName: "ccBattery"
    visible: Svc.Battery.present
    spacing: 6
    readonly property bool critical: !Svc.Battery.charging && Svc.Battery.percent <= 15
    readonly property string detail: Svc.Battery.timeText || Svc.Battery.stateText
    Accessible.role: Accessible.StaticText
    Accessible.name: "Battery " + Svc.Battery.percent + " percent, " + detail
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Svc.Battery.icon; rotation: 90
        color: chip.critical ? Colors.islandError : Colors.islandFg
        font.family: Theme.fontIcon; font.pixelSize: 18
    }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        Text {
            text: Svc.Battery.percent + " %"; color: chip.critical ? Colors.islandError : Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 }
        }
        Text {
            text: chip.detail; color: Colors.islandFgVar
            font.family: Theme.fontUi; font.pixelSize: 10; font.features: { "tnum": 1 }
        }
    }
}

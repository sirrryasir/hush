import QtQuick
import qs.config
import qs.services as Svc
import "../rest"

// Control-center battery readout beside the power row: the battery glyph, "80 %" and the state
// ("Charging", "Not charging", "On battery", "Fully charged"). Not shown without a battery.
Row {
    id: chip
    objectName: "ccBattery"
    visible: Svc.Battery.present
    spacing: 8
    Accessible.role: Accessible.StaticText
    Accessible.name: "Battery " + Svc.Battery.percent + " percent, " + Svc.Battery.stateText
    BatteryGlyph { anchors.verticalCenter: parent.verticalCenter; bodyW: 26; bodyH: 13; showNumber: false }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        Text {
            text: Svc.Battery.percent + " %"
            color: Svc.Battery.present && !Svc.Battery.charging && Svc.Battery.percent <= 15 ? Colors.islandError : Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 }
        }
        Text {
            text: Svc.Battery.stateText; color: Colors.islandFgVar
            font.family: Theme.fontUi; font.pixelSize: 10
        }
    }
}

import QtQuick
import qs.config
import qs.services as Svc
import "../rest"

// Control-center battery readout beside the power row: the battery glyph, "80 %" and the state
// ("Charging", "Not charging", "On battery", "Fully charged"), plus "power-saver" while that profile
// is active. A tap opens the power-profile page when powerprofilesctl is installed. Not shown without a battery.
Item {
    id: chip
    objectName: "ccBattery"
    visible: Svc.Battery.present
    implicitWidth: row.implicitWidth; implicitHeight: row.implicitHeight
    signal clicked()
    readonly property bool saver: Svc.PowerProfile.active === "power-saver"
    Accessible.role: Accessible.StaticText
    Accessible.name: "Battery " + Svc.Battery.percent + " percent, " + Svc.Battery.stateText
    MouseArea {
        anchors.fill: parent; enabled: Svc.PowerProfile.available; cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
    Row {
        id: row; spacing: 8
        BatteryGlyph { anchors.verticalCenter: parent.verticalCenter; bodyW: 26; bodyH: 13; showNumber: false }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: Svc.Battery.percent + " %"
                color: Svc.Battery.present && !Svc.Battery.charging && Svc.Battery.percent <= 15 ? Colors.islandError : Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 }
            }
            Text {
                objectName: "ccBatteryState"
                text: Svc.Battery.stateText + (chip.saver ? " \u00b7 power-saver" : ""); color: Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 10
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import "modules/island/rest"

// Harness for the battery glyph with faked values: one column per case (100 %, 80 %, 15 %,
// charging at 60 %), each a rest pill (24x12 glyph), the hover-face size (30x15) and the control
// center row (26x13 + "NN %" + state). Columns are 200 px wide from x = 0.
// qs -p tests/harness/battery.qml ipc call battery cases
ShellRoot {
    id: root
    readonly property var cases: [
        { name: "100", p: 100, ch: false, st: "Fully charged" },
        { name: "80", p: 80, ch: false, st: "On battery" },
        { name: "15", p: 15, ch: false, st: "On battery" },
        { name: "charging", p: 60, ch: true, st: "Charging" }]
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-battery"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 800; implicitHeight: 180
        color: "transparent"
        Row {
            Repeater {
                model: root.cases
                delegate: Item {
                    required property var modelData
                    width: 200; height: 180
                    Column {
                        anchors.centerIn: parent; spacing: 12
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 36; width: restRow.width + 28; radius: 18; color: "#000000"
                            Row {
                                id: restRow; anchors.centerIn: parent; spacing: 10
                                Text { text: "16:20"; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                BatteryGlyph { anchors.verticalCenter: parent.verticalCenter
                                    percent: modelData.p; charging: modelData.ch; critical: !modelData.ch && modelData.p <= 15 }
                            }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 44; width: 160; radius: 22; color: "#000000"
                            Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Fri 2 Oct"; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium }
                            BatteryGlyph { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                                bodyW: 30; bodyH: 15; percent: modelData.p; charging: modelData.ch; critical: !modelData.ch && modelData.p <= 15 }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 48; width: 160; radius: 14; color: "#000000"
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                BatteryGlyph { anchors.verticalCenter: parent.verticalCenter; bodyW: 26; bodyH: 13; showNumber: false
                                    percent: modelData.p; charging: modelData.ch; critical: !modelData.ch && modelData.p <= 15 }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: modelData.p + " %"; color: !modelData.ch && modelData.p <= 15 ? Colors.islandError : Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                                    Text { text: modelData.st; color: Colors.islandFgVar; font.family: Theme.fontUi; font.pixelSize: 10 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "battery"
        function cases(): string { return root.cases.map(c => c.name).join(" ") }
    }
}

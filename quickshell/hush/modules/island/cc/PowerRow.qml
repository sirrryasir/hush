import QtQuick
import Quickshell
import qs.config

// lock / logout / sleep / reboot / power off. Lock goes through `hush lock`; the rest need a second click within 2 s.
Row {
    id: row
    spacing: 6
    property string armed: ""
    readonly property var actions: [
        { id: "lock", glyph: "lock", cmd: [Paths.hush, "lock"], confirm: false },
        { id: "logout", glyph: "logout", cmd: ["hyprctl", "dispatch", "exit"], confirm: true },
        { id: "sleep", glyph: "bedtime", cmd: ["systemctl", "suspend"], confirm: true },
        { id: "reboot", glyph: "restart_alt", cmd: ["systemctl", "reboot"], confirm: true },
        { id: "poweroff", glyph: "power_settings_new", cmd: ["systemctl", "poweroff"], confirm: true }
    ]
    function press(a) {
        if (a.confirm && armed !== a.id) { armed = a.id; disarm.restart(); return }
        armed = ""; disarm.stop()
        Quickshell.execDetached(a.cmd)
    }
    Timer { id: disarm; interval: 2000; onTriggered: row.armed = "" }

    Repeater {
        model: row.actions
        delegate: Rectangle {
            id: btn
            required property var modelData
            readonly property bool isArmed: row.armed === modelData.id
            width: 32; height: 32; radius: 16
            color: isArmed ? Colors.islandErrorContainer : Colors.islandSurfaceHigh
            // hint floats above the armed button so the row keeps its width
            Text {
                visible: btn.isArmed
                anchors.right: parent.right; anchors.bottom: parent.top; anchors.bottomMargin: 2
                text: "again to confirm"; color: Colors.islandError
                font.family: Theme.fontUi; font.pixelSize: 11
            }
            Text {
                anchors.centerIn: parent; text: btn.modelData.glyph
                color: btn.isArmed ? Colors.islandError : Colors.islandFg
                font.family: Theme.fontIcon; font.pixelSize: 18
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.press(btn.modelData)
                Accessible.role: Accessible.Button; Accessible.name: btn.isArmed ? "Confirm " + btn.modelData.id : ({ lock: "Lock", logout: "Log out", sleep: "Sleep", reboot: "Reboot", poweroff: "Power off" })[btn.modelData.id] }
        }
    }
}

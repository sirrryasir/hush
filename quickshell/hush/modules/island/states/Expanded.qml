import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.config
import qs.services as Svc
import "../cc"

// The control center: media, four toggles, volume and brightness, themes, power. 560x320.
StateBase {
    id: cc
    name: "expanded"; size: Sizes.expanded; priority: 4

    // Which fourth toggle exists: "sunset" when hyprsunset is installed, else "idle" (hypridle).
    property string extra: ""
    property bool extraOn: false

    Process {
        id: probe
        command: ["sh", "-c", "if command -v hyprsunset >/dev/null; then pgrep -x hyprsunset >/dev/null && echo sunset-on || echo sunset-off; else pgrep -x hypridle >/dev/null && echo idle-on || echo idle-off; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { const t = text.trim().split("-"); cc.extra = t[0]; cc.extraOn = t[1] === "on" }
        }
    }
    Timer { id: reprobe; interval: 400; onTriggered: probe.running = true }
    function toggleExtra() {
        if (extra === "sunset") Quickshell.execDetached(extraOn ? ["pkill", "-x", "hyprsunset"] : ["hyprsunset", "-t", "4000"])
        else if (extra === "idle") Quickshell.execDetached(extraOn ? ["pkill", "-x", "hypridle"] : ["hypridle"])
        else return
        reprobe.restart()
    }

    property real pendingBrightness: -1
    Timer {
        id: briDebounce; interval: 50
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", Math.max(1, Math.round(cc.pendingBrightness * 100)) + "%"])
    }

    // Swallow clicks on empty space so they do not collapse the island.
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10

        MediaRow { Layout.fillWidth: true; Layout.preferredHeight: implicitHeight }

        GridLayout {
            Layout.fillWidth: true; columns: 2; rowSpacing: 10; columnSpacing: 10
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Networking.wifiEnabled ? "wifi" : "wifi_off"; label: "Wi-Fi"
                subtitle: Svc.Net.wifi ? Svc.Net.ssid : (Networking.wifiEnabled ? "Not connected" : "Off")
                checked: Networking.wifiEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Svc.Bt.icon; label: "Bluetooth"
                subtitle: Svc.Bt.subtitle
                checked: Svc.Bt.enabled
                onClicked: Svc.Bt.toggle()
            }
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Svc.Notifs.dnd ? "notifications_off" : "notifications"; label: "Do not disturb"
                subtitle: Svc.Notifs.dnd ? "On" : "Off"
                checked: Svc.Notifs.dnd
                onClicked: Svc.Notifs.dnd = !Svc.Notifs.dnd
            }
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                visible: cc.extra !== ""
                icon: cc.extra === "sunset" ? "nightlight" : "lock_clock"
                label: cc.extra === "sunset" ? "Night light" : "Idle lock"
                subtitle: cc.extraOn ? "On" : "Off"
                checked: cc.extraOn
                onClicked: cc.toggleExtra()
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 12
            Slider {
                Layout.preferredWidth: 130; Layout.alignment: Qt.AlignVCenter
                icon: Svc.Audio.muted ? "volume_off" : "volume_up"; value: Svc.Audio.volume
                onMoved: v => Svc.Audio.setVolume(v)
            }
            Slider {
                Layout.preferredWidth: 130; Layout.alignment: Qt.AlignVCenter
                icon: "brightness_6"; value: Svc.Brightness.level
                onMoved: v => { cc.pendingBrightness = v; briDebounce.restart() }
            }
            Item { Layout.fillWidth: true }
            PowerRow { Layout.alignment: Qt.AlignVCenter | Qt.AlignRight }
        }

        ThemeStrip { Layout.fillWidth: true; Layout.preferredHeight: 44 }
        Item { Layout.fillHeight: true }
    }
}

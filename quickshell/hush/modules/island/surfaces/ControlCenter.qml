import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.config
import qs.services as Svc
import "../cc"

// Control center surface (design 2.6), 560x320: four toggles with in-place sub-pages (Wi-Fi networks,
// Bluetooth devices), volume and brightness, the media mini-card, theme strip plus a Wallpapers button,
// and the power row. `page` is "main" | "wifi" | "bluetooth"; back() steps out of a sub-page and
// Esc does the same, or asks the host to close (closeRequested) from the main page.
FocusScope {
    id: cc
    readonly property size size: Sizes.expanded
    property string page: "main"
    signal openWallpapers()
    signal closeRequested()

    function openWifi() { page = "wifi"; Svc.Net.scan() }
    function openBluetooth() { page = "bluetooth"; Svc.Bt.scan() }
    function back() {
        if (page === "main") return false
        if (page === "bluetooth") Svc.Bt.stopScan()
        page = "main"; return true
    }
    focus: true
    Keys.onEscapePressed: if (!back()) closeRequested()

    // Night light needs hyprsunset; without it the tile falls back to the idle daemon.
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
        id: mainPage
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        visible: opacity > 0; opacity: cc.page === "main" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }

        MediaRow { Layout.fillWidth: true; Layout.preferredHeight: implicitHeight }

        GridLayout {
            Layout.fillWidth: true; columns: 2; rowSpacing: 10; columnSpacing: 10
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Networking.wifiEnabled ? "wifi" : "wifi_off"; label: "Wi-Fi"; chevron: true
                subtitle: Svc.Net.wifi ? Svc.Net.ssid : (Networking.wifiEnabled ? "Not connected" : "Off")
                checked: Networking.wifiEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                onChevronClicked: cc.openWifi()
            }
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Svc.Bt.icon; label: "Bluetooth"; chevron: true
                subtitle: Svc.Bt.connectedName !== "" ? Svc.Bt.connectedName : (Svc.Bt.enabled ? "On" : "Off")
                checked: Svc.Bt.enabled
                onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                onChevronClicked: cc.openBluetooth()
            }
            Toggle {
                objectName: "dndToggle"
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
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                icon: Svc.Audio.muted ? "volume_off" : "volume_up"; value: Svc.Audio.volume
                onMoved: v => Svc.Audio.setVolume(v)
            }
            Slider {
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                icon: "brightness_6"; value: Svc.Brightness.level
                onMoved: v => { cc.pendingBrightness = v; briDebounce.restart() }
            }
            PowerRow { Layout.alignment: Qt.AlignVCenter | Qt.AlignRight }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 10
            ThemeStrip { Layout.fillWidth: true; Layout.preferredHeight: 44 }
            Rectangle {
                Layout.preferredWidth: 112; Layout.preferredHeight: 44; radius: 12; color: Colors.surface_container_high
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "wallpaper"; color: Colors.on_surface; font.family: Theme.fontIcon; font.pixelSize: 18 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Wallpapers"; color: Colors.on_surface; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.openWallpapers() }
            }
        }
        Item { Layout.fillHeight: true }
    }

    SubPage {
        anchors.fill: parent; anchors.margins: 16
        visible: opacity > 0; opacity: cc.page === "wifi" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        title: "Wi-Fi"; busy: Svc.Net.scanning; emptyText: Networking.wifiEnabled ? "No networks found" : "Wi-Fi is off"
        switchable: true; switchOn: Networking.wifiEnabled
        onSwitched: { Networking.wifiEnabled = !Networking.wifiEnabled; if (Networking.wifiEnabled) scanLater.restart() }
        Timer { id: scanLater; interval: 1500; onTriggered: Svc.Net.scan() }
        onBack: cc.back(); onRefresh: Svc.Net.scan()
        onRowClicked: row => { if (!row.active) Svc.Net.connect(row.ssid) }
        model: Svc.Net.networks.map(n => ({
            ssid: n.ssid, label: n.ssid, active: n.active,
            icon: n.signal > 66 ? "wifi" : n.signal > 33 ? "wifi_2_bar" : "wifi_1_bar",
            trail: n.active ? "check" : (n.secure ? "lock" : ""), trailIcon: true
        }))
    }

    SubPage {
        anchors.fill: parent; anchors.margins: 16
        visible: opacity > 0; opacity: cc.page === "bluetooth" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        title: "Bluetooth"; busy: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
        emptyText: Svc.Bt.enabled ? "No devices found" : "Bluetooth is off"
        switchable: true; switchOn: Svc.Bt.enabled
        onSwitched: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
        onBack: cc.back(); onRefresh: Svc.Bt.scan()
        onRowClicked: row => Svc.Bt.toggleDevice(row.dev)
        model: Svc.Bt.devices.map(d => ({
            dev: d.dev, label: d.name, active: d.connected, icon: d.connected ? "bluetooth_connected" : "bluetooth",
            trail: d.connected ? "Connected" : (d.paired ? "Paired" : ""), trailIcon: false
        }))
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.config
import qs.services as Svc
import "../cc"

// Control center surface (design 2.6), 560x304 on a 12 px grid: the media mini-card (or, with nothing
// playing, the notifications summary in the same 44 px row), four toggles with in-place sub-pages
// (Wi-Fi networks with an in-place password field, Bluetooth devices with pair / connect / forget),
// volume and brightness, battery and the power row, theme strip plus a Wallpapers button. `page` is "main" | "wifi" | "bluetooth"; back() steps out of a sub-page and
// Esc does the same, or asks the host to close (closeRequested) from the main page.
FocusScope {
    id: cc
    readonly property size size: Sizes.expanded
    property string page: "main"
    signal openWallpapers()
    signal openNotifications()
    signal closeRequested()
    // The network whose password field is open on the Wi-Fi page ("" none).
    property string askSsid: ""

    function openWifi() { page = "wifi"; askSsid = ""; Svc.Net.scan() }
    function openBluetooth() { page = "bluetooth"; Svc.Bt.scan() }
    function back() {
        if (page === "main") return false
        if (askSsid !== "") { askSsid = ""; return true }
        if (page === "bluetooth") Svc.Bt.stopScan()
        page = "main"; return true
    }
    // A row on the Wi-Fi page: secured and never joined asks for the password in place; anything
    // else joins at once (a saved profile whose key no longer works asks for a new one).
    function wifiClicked(n) {
        if (n.active || Svc.Net.connecting !== "") return
        if (Svc.Net.needsPassword(n.ssid)) { askSsid = askSsid === n.ssid ? "" : n.ssid; return }
        askSsid = ""
        Svc.Net.connect(n.ssid)
    }
    Connections {
        target: Svc.Net
        function onConnectingChanged() {
            if (Svc.Net.connecting !== "") return
            if (Svc.Net.errorSsid === "") { cc.askSsid = ""; return }
            // Key refused for a network that has one: ask (again) in place.
            const n = Svc.Net.networks.find(x => x.ssid === Svc.Net.errorSsid)
            if (n && n.secure && /password/i.test(Svc.Net.lastError)) cc.askSsid = n.ssid
        }
    }
    Component.onDestruction: Svc.Bt.stopScan()
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
        objectName: "mainPage"
        anchors.fill: parent; anchors.margins: 12; spacing: 12
        visible: opacity > 0; opacity: cc.page === "main" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }

        // Media when a player exists, else the notifications summary: the row is always there, so
        // the panel has no empty band at the bottom.
        MediaRow { id: media; Layout.fillWidth: true; Layout.preferredHeight: 44; visible: shown }
        NotifSummary {
            objectName: "notifSummary"
            Layout.fillWidth: true; Layout.preferredHeight: 44; visible: !media.shown
            onOpenCenter: cc.openNotifications()
        }

        GridLayout {
            Layout.fillWidth: true; columns: 2; rowSpacing: 12; columnSpacing: 12
            Toggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Networking.wifiEnabled ? "wifi" : "wifi_off"; label: "Wi-Fi"; chevron: true
                subtitle: Svc.Net.wifi ? Svc.Net.ssid : (Networking.wifiEnabled ? "Not connected" : "Off")
                checked: Networking.wifiEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                onChevronClicked: cc.openWifi()
            }
            Toggle {
                objectName: "btToggle"
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: Svc.Bt.icon; label: "Bluetooth"; chevron: true
                subtitle: Svc.Bt.subtitle
                checked: Svc.Bt.enabled
                onClicked: Svc.Bt.toggle()
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
                objectName: "volumeSlider"; label: "Volume"; icon: Svc.Audio.muted ? "volume_off" : "volume_up"; value: Svc.Audio.volume
                onMoved: v => Svc.Audio.setVolume(v)
            }
            Slider {
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                label: "Brightness"; icon: "brightness_6"; value: Svc.Brightness.level
                onMoved: v => { cc.pendingBrightness = v; briDebounce.restart() }
            }
            BatteryChip { Layout.alignment: Qt.AlignVCenter }
            PowerRow { Layout.alignment: Qt.AlignVCenter | Qt.AlignRight }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 12
            ThemeStrip { Layout.fillWidth: true; Layout.preferredHeight: 44 }
            Rectangle {
                Layout.preferredWidth: 112; Layout.preferredHeight: 44; radius: 12; color: Colors.islandSurfaceHigh
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "wallpaper"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Wallpapers"; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.openWallpapers(); Accessible.role: Accessible.Button; Accessible.name: "Wallpapers" }
            }
        }
    }

    SubPage {
        id: wifiPage
        objectName: "wifiPage"
        anchors.fill: parent; anchors.margins: 12
        visible: opacity > 0; opacity: cc.page === "wifi" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        title: "Wi-Fi"; busy: Svc.Net.scanning || Svc.Net.connecting !== ""
        subtitle: Svc.Net.connecting !== "" ? "Connecting to " + Svc.Net.connecting : Svc.Net.wifi ? "Connected to " + Svc.Net.ssid : ""
        emptyText: Networking.wifiEnabled ? "No networks found" : "Wi-Fi is off"
        switchable: true; switchOn: Networking.wifiEnabled
        onSwitched: { Networking.wifiEnabled = !Networking.wifiEnabled; if (Networking.wifiEnabled) scanLater.restart() }
        Timer { id: scanLater; interval: 1500; onTriggered: Svc.Net.scan() }
        onBack: cc.back(); onRefresh: Svc.Net.scan()
        model: Svc.Net.networks
        delegate: Component { WifiRow { host: cc } }
    }

    SubPage {
        objectName: "btPage"
        anchors.fill: parent; anchors.margins: 12
        visible: opacity > 0; opacity: cc.page === "bluetooth" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        title: "Bluetooth"; subtitle: Svc.Bt.discovering ? Svc.Bt.subtitle + " · Searching" : Svc.Bt.subtitle
        busy: Svc.Bt.pending || Svc.Bt.discovering
        emptyText: Svc.Bt.enabled ? "No devices found" : Svc.Bt.subtitle === "Off" ? "Bluetooth is off" : Svc.Bt.subtitle
        switchable: true; switchOn: Svc.Bt.enabled
        onSwitched: Svc.Bt.toggle()
        onBack: cc.back(); onRefresh: Svc.Bt.scan()
        model: Svc.Bt.devices
        delegate: Component { BtRow {} }
    }
}

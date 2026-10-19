import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SystemTray
import qs.config
import qs.config as Cfg
import qs.services as Svc
import "../cc"

// Control center surface, 560x304 on a 12 px grid: the media mini-card (or, with nothing
// playing or layout.cc.media off, the notifications summary in the same 44 px row), tiles from
// layout.cc.tiles (Composer; Wi-Fi opens an in-place page with a password field, Bluetooth one with
// pair / connect / forget), volume and brightness, battery and the power row, theme strip plus a
// Wallpapers button; layout.cc.{sliders, media, themeStrip, power} switch those sections off.
// App status icons (StatusNotifierItem) sit behind a button in the top row, so the pill never grows
// with them. `page` is "main" | "wifi" | "bluetooth" | "vpn" | "tray" | "focus" (the timer tile's
// chevron; a focus session on the countdown); back() steps out of a sub-page and Esc does the same,
// or asks the host to close (closeRequested) from the main page.
FocusScope {
    id: cc
    readonly property size size: Sizes.expanded
    property string page: "main"
    signal openWallpapers()
    signal openNotifications()
    signal openSettings()
    signal closeRequested()
    // The network whose password field is open on the Wi-Fi page ("" none; hiddenKey: the "Join
    // hidden network" entry, whose field asks the name first).
    property string askSsid: ""
    readonly property string hiddenKey: "\n"

    function openWifi() { page = "wifi"; askSsid = ""; Svc.Net.scan() }
    function openBluetooth() { page = "bluetooth"; Svc.Bt.scan() }
    function openVpn() { page = "vpn"; Svc.Net.poll() }
    function openFocus() { page = "focus" }
    // The tray item whose menu is listed on the tray page, and the menu (its own, or a submenu entry).
    property var trayItem: null
    property var trayMenu: null
    function openTrayMenu(item) { trayItem = item; trayMenu = item.menu }
    function back() {
        if (page === "main") return false
        if (askSsid !== "") { askSsid = ""; return true }
        if (trayMenu) { trayMenu = null; trayItem = null; return true }
        if (page === "bluetooth") Svc.Bt.stopScan()
        page = "main"; return true
    }
    // A row on the Wi-Fi page: secured and never joined asks for the password in place; anything
    // else joins at once (a saved profile whose key no longer works asks for a new one).
    function wifiClicked(n) {
        if (n.hotspot) return
        if (n.hidden) { askSsid = askSsid === hiddenKey ? "" : hiddenKey; return }
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
    Component.onCompleted: { Svc.Net.poll(); Svc.Rfkill.probe() }
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

        // Media when a player exists (and layout.cc.media is on), else the notifications summary:
        // the row is always there, so the panel has no empty band at the bottom. The tray button
        // (app icons, with their count) sits at its right end while an app registers an icon.
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 12
            MediaRow { id: media; Layout.fillWidth: true; Layout.preferredHeight: 44; visible: shown && Composer.media }
            NotifSummary {
                objectName: "notifSummary"
                Layout.fillWidth: true; Layout.preferredHeight: 44; visible: !media.visible
                onOpenCenter: cc.openNotifications()
            }
            Rectangle {
                objectName: "trayButton"
                readonly property int count: SystemTray.items.values.length
                visible: count > 0
                Layout.preferredWidth: 56; Layout.preferredHeight: 44; radius: 10; color: Colors.islandSurfaceHigh
                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "apps"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 22 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.count; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.page = "tray"
                    Accessible.role: Accessible.Button; Accessible.name: parent.count + " app icons" }
            }
        }

        // Tiles in layout.cc.tiles order on a 4-column grid: a 2x1 tile spans two columns, a tile
        // that does not fit the rest of a row starts the next one. Rows share the height left over by
        // the other sections (56 px each at most, 28 at least; the surface never grows).
        Item {
            id: grid
            objectName: "ccGrid"
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 28
            Layout.preferredHeight: rows * 56 + Math.max(0, rows - 1) * rowGap; Layout.maximumHeight: Layout.preferredHeight
            clip: true
            readonly property int gap: 12
            readonly property real colW: (width - 3 * gap) / 4
            readonly property var placed: {
                const out = []; let r = 0, c = 0
                for (const t of Composer.tilesShown) {
                    if (t.id === "nightlight" && cc.extra === "") continue
                    if (t.id === "vpn" && Svc.Net.vpns.length === 0) continue
                    if (t.id === "airplane" && Svc.Rfkill.count === 0) continue
                    const span = t.size === "2x1" ? 2 : 1
                    if (c + span > 4) { r++; c = 0 }
                    out.push({ id: t.id, span: span, row: r, col: c })
                    c += span
                }
                return out
            }
            readonly property int rows: placed.length ? placed[placed.length - 1].row + 1 : 0
            readonly property real rowGap: rows > 2 ? 8 : gap
            visible: rows > 0
            readonly property real tileH: rows ? Math.max(28, Math.min(56, (height - (rows - 1) * rowGap) / rows)) : 0
            Repeater {
                model: grid.placed
                delegate: Loader {
                    required property var modelData
                    objectName: "ccTile_" + modelData.id
                    x: modelData.col * (grid.colW + grid.gap); y: modelData.row * (grid.tileH + grid.rowGap)
                    width: modelData.span * grid.colW + (modelData.span - 1) * grid.gap; height: grid.tileH
                    sourceComponent: cc.tileComps[modelData.id] || null
                    onLoaded: item.compact = Qt.binding(() => modelData.span === 1 || grid.tileH < 44)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 12
            visible: Composer.sliders || Composer.power
            Slider {
                visible: Composer.sliders
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                objectName: "volumeSlider"; label: "Volume"; icon: Svc.Audio.muted ? "volume_off" : "volume_up"; value: Svc.Audio.volume
                onMoved: v => Svc.Audio.setVolume(v)
            }
            Slider {
                visible: Composer.sliders
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                label: "Brightness"; icon: "brightness_6"; value: Svc.Brightness.level
                onMoved: v => { cc.pendingBrightness = v; briDebounce.restart() }
            }
            Item { visible: !Composer.sliders; Layout.fillWidth: true }
            BatteryChip { Layout.alignment: Qt.AlignVCenter }
            PowerRow { visible: Composer.power; Layout.alignment: Qt.AlignVCenter | Qt.AlignRight }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 12
            visible: Composer.themeStrip
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
        // Takes what a switched-off section leaves beyond the grid's tallest rows; absent with every
        // section on (it would still cost a 12 px layout gap).
        Item { visible: !Composer.themeStrip || !(Composer.sliders || Composer.power); Layout.fillHeight: true; Layout.preferredHeight: 0 }
    }

    // --- tiles (ids from Composer.tileIds) ---
    readonly property var tileComps: ({ wifi: wifiTile, bluetooth: btTile, vpn: vpnTile, airplane: airTile, dnd: dndTile, nightlight: nightTile,
        timer: timerTile, recording: recTile, lock: lockTile, theme: themeTile, wallpapers: wallTile, settings: settingsTile })
    Component {
        id: wifiTile
        Toggle {
            icon: Networking.wifiEnabled ? "wifi" : "wifi_off"; label: "Wi-Fi"; chevron: true
            subtitle: Svc.Net.wifi ? Svc.Net.ssid : (Networking.wifiEnabled ? "Not connected" : "Off")
            checked: Networking.wifiEnabled
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onChevronClicked: cc.openWifi()
        }
    }
    Component {
        id: btTile
        Toggle {
            objectName: "btToggle"
            icon: Svc.Bt.icon; label: "Bluetooth"; chevron: true
            subtitle: Svc.Bt.subtitle
            checked: Svc.Bt.enabled
            onClicked: Svc.Bt.toggle()
            onChevronClicked: cc.openBluetooth()
        }
    }
    // One VPN profile toggles on tap; with several the tile opens a page listing them.
    Component {
        id: vpnTile
        Toggle {
            icon: Svc.Net.vpnActive !== "" ? "vpn_lock" : "vpn_key"; label: "VPN"; chevron: Svc.Net.vpns.length > 1
            subtitle: Svc.Net.vpnActive !== "" ? Svc.Net.vpnActive : "Off"
            checked: Svc.Net.vpnActive !== ""
            onClicked: Svc.Net.vpns.length === 1 ? Svc.Net.toggleVpn(Svc.Net.vpns[0]) : cc.openVpn()
            onChevronClicked: cc.openVpn()
        }
    }
    // rfkill block all: the Wi-Fi and Bluetooth tiles read off through their own services.
    Component {
        id: airTile
        Toggle {
            icon: Svc.Rfkill.airplane ? "airplanemode_active" : "airplanemode_inactive"; label: "Airplane"
            subtitle: Svc.Rfkill.airplane ? "On" : "Off"
            checked: Svc.Rfkill.airplane
            onClicked: Svc.Rfkill.setAirplane(!Svc.Rfkill.airplane)
        }
    }
    Component {
        id: dndTile
        Toggle {
            objectName: "dndToggle"
            icon: Svc.Notifs.dnd ? "notifications_off" : "notifications"; label: "Do not disturb"
            subtitle: Svc.Notifs.dnd ? "On" : "Off"
            checked: Svc.Notifs.dnd
            onClicked: Svc.Notifs.dnd = !Svc.Notifs.dnd
        }
    }
    Component {
        id: nightTile
        Toggle {
            icon: cc.extra === "sunset" ? "nightlight" : "lock_clock"
            label: cc.extra === "sunset" ? "Night light" : "Idle lock"
            subtitle: cc.extraOn ? "On" : "Off"
            checked: cc.extraOn
            onClicked: cc.toggleExtra()
        }
    }
    Component {
        id: timerTile
        Toggle {
            readonly property int s: Math.max(0, Svc.Countdown.remaining)
            icon: "timer"; label: "Timer"; chevron: true
            subtitle: Svc.Countdown.running ? (Svc.Countdown.phaseLabel !== "" ? Svc.Countdown.phaseLabel + " " : "") + Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) : "5 min"
            checked: Svc.Countdown.running
            onClicked: Svc.Countdown.running ? Svc.Countdown.stop() : Svc.Countdown.start(300, "")
            onChevronClicked: cc.openFocus()
        }
    }
    // Screen recording through wf-recorder into ~/Videos; a recording another tool started shows
    // as on and is left alone.
    Component {
        id: recTile
        Toggle {
            icon: Svc.Recording.active ? "stop_circle" : "screen_record"; label: "Recording"
            subtitle: Svc.Recording.active ? (Svc.Recording.kind || "On") : cc.recorder ? "Off" : "wf-recorder missing"
            checked: Svc.Recording.active
            onClicked: cc.toggleRecording()
        }
    }
    Component {
        id: lockTile
        Toggle { toggle: false; icon: "lock"; label: "Lock"; subtitle: "Lock the session"
            onClicked: Quickshell.execDetached([Paths.hush, "lock"]) }
    }
    Component {
        id: themeTile
        Toggle { toggle: false; icon: "palette"; label: "Theme"; subtitle: Cfg.State.theme || ""
            onClicked: cc.nextTheme() }
    }
    Component {
        id: wallTile
        Toggle { toggle: false; icon: "wallpaper"; label: "Wallpapers"; onClicked: cc.openWallpapers() }
    }
    Component {
        id: settingsTile
        Toggle { toggle: false; icon: "settings"; label: "Settings"; onClicked: cc.openSettings() }
    }
    function nextTheme() {
        const n = Svc.Ipc.themeNames; if (!n.length) return
        Svc.Ipc.setTheme(n[(n.indexOf(Cfg.State.theme) + 1) % n.length])
    }
    property bool recorder: false
    Process {
        command: ["sh", "-c", "command -v wf-recorder >/dev/null && echo yes || echo no"]
        running: true
        stdout: StdioCollector { onStreamFinished: cc.recorder = text.trim() === "yes" }
    }
    function toggleRecording() {
        if (Svc.Recording.active) {
            if (Svc.Recording.kind === "wf-recorder") Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"])
            return
        }
        if (!recorder) return
        Quickshell.execDetached(["sh", "-c", 'd="${XDG_VIDEOS_DIR:-$HOME/Videos}"; mkdir -p "$d" && exec wf-recorder -f "$d/hush-$(date +%Y%m%d-%H%M%S).mp4"'])
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
        // Under the networks: the hidden-network entry and the hotspot row (WifiRow renders both).
        model: Networking.wifiEnabled ? Svc.Net.networks.concat([{ id: "hidden", hidden: true }, { id: "hotspot", hotspot: true }]) : Svc.Net.networks
        delegate: Component { WifiRow { host: cc } }
    }

    SubPage {
        objectName: "vpnPage"
        anchors.fill: parent; anchors.margins: 12
        visible: opacity > 0; opacity: cc.page === "vpn" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        title: "VPN"; subtitle: Svc.Net.vpnActive !== "" ? "Connected to " + Svc.Net.vpnActive : ""
        emptyText: "No VPN profiles"
        onBack: cc.back(); onRefresh: Svc.Net.poll()
        model: Svc.Net.vpns.map(v => ({ icon: v.active ? "vpn_lock" : "vpn_key", label: v.name, trail: v.active ? "On" : "", active: v.active, uuid: v.uuid }))
        onRowClicked: row => Svc.Net.toggleVpn(row)
    }

    FocusPage {
        objectName: "focusPage"
        anchors.fill: parent; anchors.margins: 12
        visible: opacity > 0; opacity: cc.page === "focus" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        onBack: cc.back()
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

    // App icons: a TrayRow per item (tap activates, right click or the trailing glyph lists its menu
    // here through Quickshell's menu opener), or per entry of the open menu (a submenu lists its
    // entries, back returns to the icons).
    QsMenuOpener { id: menuOpener; menu: cc.trayMenu }
    SubPage {
        objectName: "trayPage"
        anchors.fill: parent; anchors.margins: 12
        visible: opacity > 0; opacity: cc.page === "tray" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        title: cc.trayItem ? cc.trayItem.title : "App icons"
        emptyText: cc.trayMenu ? "Empty menu" : "No app icons"
        onBack: cc.back()
        model: cc.trayMenu
            ? menuOpener.children.values.filter(e => !e.isSeparator).map(e => ({ label: e.text, entry: e }))
            : SystemTray.items.values.map(it => ({ label: it.title || it.id, item: it }))
        delegate: Component { TrayRow { host: cc } }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.config as Cfg
import qs.modules.island.cc

// Settings surface (design 2.6): 560x320 GUI over the Settings singleton. A page rail on the left
// (Island, Behaviour, Modules, Theme, About). Sliders preview while dragging (`preview` overrides,
// `previewed` signal for the host pill) and write Cfg.Settings.set only on release.
FocusScope {
    id: root
    readonly property size size: Sizes.settings
    property string page: "island"
    property var preview: ({})
    property string version: "0.0.0"
    // A one-line problem the host reports (another notification daemon owns the bus name).
    property string warning: ""
    signal previewed(string key, real value)
    signal openWallpapers()
    signal closeRequested()
    focus: true
    Keys.onEscapePressed: closeRequested()

    readonly property var pages: [
        { id: "island", label: "Island", glyph: "pill" },
        { id: "behaviour", label: "Behaviour", glyph: "touch_app" },
        { id: "modules", label: "Modules", glyph: "widgets" },
        { id: "theme", label: "Theme", glyph: "palette" },
        { id: "about", label: "About", glyph: "info" }]

    // Keys are island.* by default; "motion.revealMs" style dotted keys address another section.
    function cfgPath(key) { return key.indexOf(".") >= 0 ? key : "island." + key }
    function cfgValue(key) { return cfgPath(key).split(".").reduce((o, k) => o === undefined || o === null ? undefined : o[k], Cfg.Settings.data) }
    function value(key) { return preview[key] !== undefined ? preview[key] : cfgValue(key) }
    function setPreview(key, v) { const p = Object.assign({}, preview); p[key] = v; preview = p; previewed(key, v) }
    function commit(key, v) {
        Cfg.Settings.set(cfgPath(key), v)
        const p = Object.assign({}, preview); delete p[key]; preview = p
    }

    FileView {
        path: Quickshell.shellDir + "/../../VERSION"
        blockLoading: true
        onLoaded: root.version = text().trim()
    }

    component Label: Text {
        color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }
    component Chip: Rectangle {
        id: chip
        property string text; property bool on: false
        signal clicked()
        implicitWidth: lbl.implicitWidth + 24; implicitHeight: 26; radius: 13
        color: on ? Colors.islandPrimary : (ma.containsMouse ? Colors.islandSurfaceHigh : Colors.islandSurface)
        Text {
            id: lbl; anchors.centerIn: parent; text: chip.text
            color: chip.on ? Colors.islandOnPrimary : Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked()
            Accessible.role: Accessible.Button; Accessible.name: chip.text; Accessible.checked: chip.on }
    }
    component Switch: Rectangle {
        id: sw
        property bool on: false
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        signal toggled(bool v)
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: on ? Colors.islandPrimary : Colors.islandSurfaceHighest
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3; x: sw.on ? 19 : 3
            color: sw.on ? Colors.islandOnPrimary : Colors.islandFgVar
            Behavior on x { NumberAnimation { duration: Theme.durationShort } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.on)
            Accessible.role: Accessible.CheckBox; Accessible.name: sw.rowTitle; Accessible.checked: sw.on }
    }
    component Row2: Item {
        property string title
        default property alias content: slot.data
        Layout.fillWidth: true; Layout.preferredHeight: parent && parent.rowH ? parent.rowH : 30
        Label { text: parent.title; width: 120; height: parent.height; color: Colors.islandFg }
        Item { id: slot; x: 124; width: parent.width - 124; height: parent.height }
    }
    component Slide: Item {
        id: sl
        property string key; property real from: 0; property real to: 100; property string unit: "px"; property real step: 1
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        readonly property real cur: { const v = key ? root.value(key) : from; return v === undefined ? from : v }
        height: 30; anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle { id: track; x: 0; y: 13; width: parent.width - 54; height: 4; radius: 2; color: Colors.islandSurfaceHighest
            Rectangle { width: Math.max(0, Math.min(1, (sl.cur - sl.from) / (sl.to - sl.from))) * parent.width; height: 4; radius: 2; color: Colors.islandPrimary }
            Rectangle { x: Math.max(0, Math.min(1, (sl.cur - sl.from) / (sl.to - sl.from))) * parent.width - 7; y: -5; width: 14; height: 14; radius: 7; color: Colors.islandPrimary }
        }
        Label { x: parent.width - 48; width: 48; height: parent.height; horizontalAlignment: Text.AlignRight
            text: Math.round(sl.cur) + " " + sl.unit; color: Colors.islandFgVar; font.features: { "tnum": 1 } }
        function at(mx) { return Math.round(sl.from + Math.max(0, Math.min(1, mx / track.width)) * (sl.to - sl.from)) }
        MouseArea {
            anchors.fill: parent; anchors.rightMargin: 54; cursorShape: Qt.PointingHandCursor
            onPressed: m => root.setPreview(sl.key, sl.at(m.x))
            onPositionChanged: m => { if (pressed) root.setPreview(sl.key, sl.at(m.x)) }
            onReleased: m => root.commit(sl.key, sl.at(m.x))
            Accessible.role: Accessible.Slider; Accessible.name: sl.rowTitle; Accessible.description: Math.round(sl.cur) + " " + sl.unit
            // Keyboard (the island's navigator calls this on Left/Right): n steps, committed at once.
            function stepAdjust(n) { root.commit(sl.key, Math.max(sl.from, Math.min(sl.to, Math.round(sl.cur) + n * sl.step))) }
        }
    }
    component Drop: Item {
        id: dd
        property string key; property var options: []
        readonly property string cur: String(Cfg.Settings.island[key])
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        property bool open: false
        height: 24; width: 140; anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle {
            anchors.fill: parent; radius: 8; color: Colors.islandSurface
            Label { x: 10; width: parent.width - 30; height: parent.height; text: dd.cur }
            Text { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"; color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dd.open = !dd.open
                Accessible.role: Accessible.ComboBox; Accessible.name: dd.rowTitle; Accessible.description: dd.cur }
        }
        Column {
            visible: dd.open; y: 26; z: 10; width: parent.width
            Repeater {
                model: dd.options
                delegate: Rectangle {
                    required property string modelData
                    width: dd.width; height: 26; color: hov.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                    Label { x: 10; height: parent.height; text: parent.modelData; font.weight: parent.modelData === dd.cur ? Font.DemiBold : Font.Normal }
                    MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true
                        Accessible.role: Accessible.MenuItem; Accessible.name: parent.modelData
                        onClicked: { Cfg.Settings.set("island." + dd.key, parent.modelData); dd.open = false } }
                }
            }
        }
    }

    // Page rail.
    Column {
        x: 12; y: 14; width: 120; spacing: 2
        Repeater {
            model: root.pages
            delegate: Rectangle {
                required property var modelData
                width: 120; height: 32; radius: 10
                color: root.page === modelData.id ? Colors.islandSurfaceHigh : "transparent"
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph
                    color: root.page === modelData.id ? Colors.islandPrimary : Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18 }
                Label { x: 34; height: parent.height; text: modelData.label; font.weight: root.page === modelData.id ? Font.DemiBold : Font.Normal }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page = modelData.id
                    Accessible.role: Accessible.PageTab; Accessible.name: modelData.label }
            }
        }
    }

    Item {
        x: 148; y: 14; width: parent.width - 160; height: parent.height - 28 - (root.warning !== "" ? 24 : 0)

        ColumnLayout {
            visible: root.page === "island"; width: parent.width; height: parent.height; spacing: 0
            readonly property real rowH: Math.min(44, height / 6)
            Row2 { title: "Mode"
                Row { spacing: 6; anchors.verticalCenter: parent.verticalCenter
                    Repeater { model: ["reserve", "overlay", "autohide"]
                        delegate: Chip { required property string modelData; text: modelData; on: Cfg.Settings.island.mode === modelData
                            onClicked: Cfg.Settings.set("island.mode", modelData) } } } }
            Row2 { title: "Width"; Slide { width: parent.width; key: "width"; from: 96; to: 320 } }
            Row2 { title: "Height"; Slide { width: parent.width; key: "height"; from: 28; to: 48 } }
            Row2 { title: "Radius"; Slide { width: parent.width; key: "radius"; from: 8; to: 24 } }
            Row2 { title: "Top gap"; Slide { width: parent.width; key: "topGap"; from: 0; to: 24 } }
            Row2 { title: "Reserve"; Slide { width: parent.width; key: "reserve"; from: 0; to: 80 } }
        }

        ColumnLayout {
            visible: root.page === "behaviour"; width: parent.width; height: parent.height; spacing: 0
            readonly property real rowH: Math.min(44, height / 11)
            Row2 { title: "Hover face"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.hoverFace; onToggled: v => Cfg.Settings.set("island.hoverFace", v) } }
            Row2 { title: "Live activities"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.liveActivities; onToggled: v => Cfg.Settings.set("island.liveActivities", v) } }
            Row2 { title: "Reduced motion"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.reducedMotion; onToggled: v => Cfg.Settings.set("island.reducedMotion", v) } }
            Row2 { title: "Now playing OSD"; Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.island.nowPlayingOsd !== false; onToggled: v => Cfg.Settings.set("island.nowPlayingOsd", v) } }
            Row2 { title: "Fullscreen reveal"; Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.island.fullscreenReveal !== false; onToggled: v => Cfg.Settings.set("island.fullscreenReveal", v) } }
            Row2 { title: "Fullscreen OSD"; Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.island.fullscreenOsd !== false; onToggled: v => Cfg.Settings.set("island.fullscreenOsd", v) } }
            Row2 { title: "Reveal time"; Slide { width: parent.width; key: "motion.revealMs"; from: 500; to: 5000; step: 100; unit: "ms" } }
            Row2 { title: "Left click"; z: 4; Drop { key: "clickLeft"; options: ["cc", "notifs", "media", "calendar", "none"] } }
            Row2 { title: "Right click"; z: 3; Drop { key: "clickRight"; options: ["cc", "notifs", "media", "calendar", "none"] } }
            Row2 { title: "Middle click"; z: 2; Drop { key: "clickMiddle"; options: ["cc", "notifs", "media", "calendar", "none"] } }
            Row2 { title: "Scroll"; z: 1; Drop { key: "scroll"; options: ["volume", "brightness", "none"] } }
        }

        ColumnLayout {
            visible: root.page === "modules"; width: parent.width; height: parent.height; spacing: 0
            readonly property real rowH: Math.min(44, height / 6)
            Repeater {
                model: ["media", "notifications", "calendar", "launcher", "wallpapers", "settings"]
                delegate: Row2 {
                    required property string modelData
                    title: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.modules[modelData] !== false
                        onToggled: v => Cfg.Settings.set("modules." + modelData, v) }
                }
            }
        }

        ColumnLayout {
            visible: root.page === "theme"; width: parent.width; spacing: 14
            Label { text: "Theme"; font.weight: Font.DemiBold }
            ThemeStrip { Layout.fillWidth: true; Layout.preferredHeight: 72 }
            Chip { text: "Wallpapers"; onClicked: root.openWallpapers() }
        }

        ColumnLayout {
            visible: root.page === "about"; width: parent.width; spacing: 8
            Label { text: "Hush"; font.pixelSize: 20; font.weight: Font.DemiBold }
            Label { text: "Version " + root.version; color: Colors.islandFgVar }
            Label { text: "A quiet shell for Hyprland and Quickshell."; color: Colors.islandFgVar }
        }
    }

    // Warning line along the bottom of every page.
    Row {
        objectName: "settingsWarning"
        visible: root.warning !== ""
        x: 148; y: parent.height - 30; height: 20; spacing: 6
        Text { anchors.verticalCenter: parent.verticalCenter; text: "warning"; color: Colors.islandError; font.family: Theme.fontIcon; font.pixelSize: 16 }
        Label { height: parent.height; width: root.width - 148 - 34; text: root.warning; color: Colors.islandError; elide: Text.ElideRight }
    }
}

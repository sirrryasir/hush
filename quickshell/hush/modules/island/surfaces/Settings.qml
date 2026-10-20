import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.config as Cfg
import qs.modules.island.cc
import "../states"

// Settings surface: 560x336 GUI over the Settings singleton. A page rail on the left
// (Island, Behaviour, Modules, Lock, Theme, About). Sliders preview while dragging (`preview` overrides,
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
    // The dropdown whose list is open (lists live on the surface, so the page's clip never cuts them).
    property var openDrop: null
    // Island hook: Esc closes an open list first, then the island closes the surface.
    function back() { if (!openDrop) return false; openDrop.open = false; return true }
    Keys.onEscapePressed: { if (!back()) closeRequested() }
    onPageChanged: { openDrop = null; flick.contentY = 0 }

    readonly property var pages: [
        { id: "island", label: "Island", glyph: "pill" },
        { id: "behaviour", label: "Behaviour", glyph: "touch_app" },
        { id: "shortcuts", label: "Shortcuts", glyph: "keyboard" },
        { id: "modules", label: "Modules", glyph: "widgets" },
        { id: "lock", label: "Lock", glyph: "lock" },
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

    function setLock(k, v) { Cfg.Settings.set("lock." + k, v); lockSync.restart() }
    // after Settings' writer has put settings.json on disk (it runs async)
    Timer { id: lockSync; interval: 500; onTriggered: Quickshell.execDetached(["hush", "sddm", "sync"]) }

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
        property string accName: ""
        signal clicked()
        implicitWidth: lbl.implicitWidth + 24; implicitHeight: 26; radius: 13
        color: on ? Colors.islandPrimary : (ma.containsMouse ? Colors.islandSurfaceHigh : Colors.islandSurface)
        Text {
            id: lbl; anchors.centerIn: parent; text: chip.text
            color: chip.on ? Colors.islandOnPrimary : Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked()
            Accessible.role: Accessible.Button; Accessible.name: chip.accName || chip.text; Accessible.checked: chip.on }
    }
    component Switch: Rectangle {
        id: sw
        property bool on: false
        property string name: ""
        property string navRole: "switch"
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
            Accessible.role: Accessible.CheckBox; Accessible.name: sw.name || sw.rowTitle; Accessible.checked: sw.on }
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
        signal chosen()
        readonly property string cur: String(root.cfgValue(key))
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        property bool open: false
        Connections { target: root; function onOpenDropChanged() { if (root.openDrop !== dd) dd.open = false } }
        readonly property real listH: options.length * 26
        // Where the list goes, set when it opens: below the control, above it when the surface ends first.
        property point at: Qt.point(0, 0)
        onOpenChanged: {
            if (!open) { if (root.openDrop === dd) root.openDrop = null; return }
            const p = dd.mapToItem(root, 0, 0)
            at = Qt.point(p.x, p.y + 26 + listH > root.height - 6 ? p.y - listH - 2 : p.y + 26)
            root.openDrop = dd
        }
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
            parent: root; visible: dd.open; x: dd.at.x; y: dd.at.y; z: 100; width: dd.width
            Repeater {
                model: dd.options
                delegate: Rectangle {
                    required property string modelData
                    width: dd.width; height: 26; color: hov.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                    Label { x: 10; height: parent.height; text: parent.modelData; font.weight: parent.modelData === dd.cur ? Font.DemiBold : Font.Normal }
                    MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true
                        Accessible.role: Accessible.MenuItem; Accessible.name: parent.modelData
                        onClicked: { Cfg.Settings.set(root.cfgPath(dd.key), parent.modelData); dd.open = false; dd.chosen() } }
                }
            }
        }
    }

    // --- Modules page: the composer (Composer singleton over settings `layout`) ---
    // A row: switch, label, then (control center tiles) a 1x1/2x1 size toggle, then up/down. The row
    // buttons are MouseAreas with a navRole, so the island's keyboard navigator reaches them and
    // Alt/Shift + Up/Down on any of them moves the row (reorder / controlFor below).
    component RowButton: MouseArea {
        id: rb
        property string glyph; property string text; property string navRole; property string label
        implicitWidth: text !== "" ? 40 : 26; implicitHeight: 22
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        Accessible.role: Accessible.Button; Accessible.name: rb.label
        Rectangle {
            anchors.fill: parent; radius: 7
            color: rb.containsMouse && rb.enabled ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
            opacity: rb.enabled ? 1 : 0.35
            Text { anchors.centerIn: parent; visible: rb.glyph !== ""; text: rb.glyph; color: Colors.islandFg
                font.family: Theme.fontIcon; font.pixelSize: 18 }
            Text { anchors.centerIn: parent; visible: rb.text !== ""; text: rb.text; color: Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; font.features: { "tnum": 1 } }
        }
    }
    component LayoutRow: Item {
        id: lr
        property string layoutSection   // "hover" | "cc"
        property var entry: ({})
        property int pos: 0
        property int count: 1
        readonly property string label: Cfg.Composer.label(entry.id)
        objectName: "layoutRow_" + layoutSection + "_" + entry.id
        width: parent ? parent.width : 0; height: root.composerRowH
        Switch { x: 0; anchors.verticalCenter: parent.verticalCenter; on: !!lr.entry.enabled
            name: lr.label + (lr.layoutSection === "cc" ? " tile" : " chip") + ", shown"
            onToggled: v => Cfg.Composer.setEnabled(lr.layoutSection, lr.entry.id, v) }
        Label { x: 48; height: parent.height; width: parent.width - 48 - btns.width - 8; text: lr.label; elide: Text.ElideRight
            color: lr.entry.enabled ? Colors.islandFg : Colors.islandFgVar }
        Row {
            id: btns
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            RowButton { visible: lr.layoutSection === "cc"; navRole: "size"; objectName: "layoutBtn_" + lr.layoutSection + "_" + lr.entry.id + "_size"; text: lr.entry.size || "1x1"
                label: lr.label + " size, " + (lr.entry.size || "1x1") + ". Toggle 1x1 or 2x1"
                onClicked: Cfg.Composer.setSize(lr.entry.id, lr.entry.size === "2x1" ? "1x1" : "2x1") }
            RowButton { navRole: "up"; objectName: "layoutBtn_" + lr.layoutSection + "_" + lr.entry.id + "_up"; glyph: "keyboard_arrow_up"; enabled: lr.pos > 0; label: "Move " + lr.label + " up"
                onClicked: Cfg.Composer.move(lr.layoutSection, lr.entry.id, -1) }
            RowButton { navRole: "down"; objectName: "layoutBtn_" + lr.layoutSection + "_" + lr.entry.id + "_down"; glyph: "keyboard_arrow_down"; enabled: lr.pos < lr.count - 1; label: "Move " + lr.label + " down"
                onClicked: Cfg.Composer.move(lr.layoutSection, lr.entry.id, 1) }
        }
    }
    function walkItems(it, f) { if (!it) return null; const r = f(it); if (r) return r
        for (let i = 0; i < it.children.length; i++) { const x = walkItems(it.children[i], f); if (x) return x } return null }
    // Island navigator hooks: the row key for the focused control ("" when not on a composer row),
    // after moving that row by dir; and the control for a key once the list has rebuilt.
    function reorder(control, dir) {
        let role = "", it = control
        while (it && it !== root) {
            if (role === "" && typeof it.navRole === "string") role = it.navRole
            if (typeof it.layoutSection === "string" && it.entry) {
                Cfg.Composer.move(it.layoutSection, it.entry.id, dir)
                return it.layoutSection + "|" + it.entry.id + "|" + (role || "switch")
            }
            it = it.parent
        }
        return ""
    }
    function controlFor(key) {
        const k = String(key).split("|")
        const row = walkItems(root, it => it.objectName === "layoutRow_" + k[0] + "_" + k[1] ? it : null)
        const host = row ? walkItems(row, it => it.navRole === k[2] ? it : null) : null
        return host ? walkItems(host, it => it.acceptedButtons !== undefined && it.pressAndHoldInterval !== undefined ? it : null) : null
    }
    // Every island action the shell exposes; `key` is the default bind (Hyprland key name), "" for none.
    readonly property string ipc: "qs -c hush ipc call hush "
    readonly property var shortcuts: [
        { id: "cc", label: "Control center", cmd: ipc + "toggleControlCenter", key: "C" },
        { id: "media", label: "Media", cmd: ipc + "openSurface mediaSurface", key: "M" },
        { id: "notifs", label: "Notifications", cmd: ipc + "toggleDrawer", key: "N" },
        { id: "calendar", label: "Calendar", cmd: ipc + "openSurface calendar", key: "K" },
        { id: "launcher", label: "Launcher", cmd: ipc + "toggleLauncher", key: "slash" },
        { id: "wallpapers", label: "Wallpapers", cmd: ipc + "toggleWallpapers", key: "W" },
        { id: "settings", label: "Settings", cmd: "hush settings", key: "comma" },
        { id: "shelf", label: "Shelf", cmd: ipc + "openSurface shelf", key: "O" },
        { id: "focus", label: "Focus session", cmd: "qs -c hush ipc call activity focusStart", key: "F" },
        { id: "lock", label: "Lock", cmd: "hush lock", key: "L" },
        { id: "overview", label: "Overview", cmd: "hush overview", key: "" },
        { id: "mute", label: "Mute", cmd: "hush volume mute", key: "" }]
    // A ready block of binds for the default keys, in Hyprland's syntax or the Lua API's.
    function bindBlock(lua) {
        return shortcuts.filter(e => e.key !== "").map(e => lua
            ? 'hl.bind("SUPER + ' + e.key + '", hl.dsp.exec_cmd("' + e.cmd + '"))'
            : "bind = SUPER, " + e.key + ", exec, " + e.cmd).join("\n") + "\n"
    }
    function copyBinds(lua) { Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", bindBlock(lua)]) }
    property string modulesSection: "surfaces"
    // Ten rows plus the section tabs and the bottom row share the page height (28 px at most).
    property real composerRowH: 24
    readonly property var modulesSections: [
        { id: "surfaces", label: "Surfaces" }, { id: "rest", label: "Rest" },
        { id: "hover", label: "Hover face" }, { id: "cc", label: "Control center" }]

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

    Flickable {
        id: flick
        x: 148; y: 14; width: parent.width - 160; height: parent.height - 28 - (root.warning !== "" ? 24 : 0)
        clip: true; contentWidth: width; boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: root.back()
        contentHeight: Math.max(height, behaviourPage.visible ? behaviourPage.height : shortcutsPage.visible ? shortcutsPage.height : modulesPage.visible ? modulesPage.height : 0)

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
            id: behaviourPage
            visible: root.page === "behaviour"; width: parent.width; spacing: 0
            readonly property real rowH: 32
            Row2 { title: "Hover face"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.hoverFace; onToggled: v => Cfg.Settings.set("island.hoverFace", v) } }
            Row2 { title: "Live activities"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.liveActivities; onToggled: v => Cfg.Settings.set("island.liveActivities", v) } }
            Row2 { title: "Reduced motion"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.reducedMotion; onToggled: v => Cfg.Settings.set("island.reducedMotion", v) } }
            Row2 { title: "Now playing OSD"; Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.island.nowPlayingOsd !== false; onToggled: v => Cfg.Settings.set("island.nowPlayingOsd", v) } }
            Row2 { title: "Fullscreen reveal"; Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.island.fullscreenReveal !== false; onToggled: v => Cfg.Settings.set("island.fullscreenReveal", v) } }
            Row2 { title: "Fullscreen OSD"; Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.island.fullscreenOsd !== false; onToggled: v => Cfg.Settings.set("island.fullscreenOsd", v) } }
            Row2 { title: "Reveal time"; Slide { width: parent.width; key: "motion.revealMs"; from: 500; to: 5000; step: 100; unit: "ms" } }
            Row2 { title: "Clock"; z: 6; Drop { key: "clock"; options: ["24", "12"] } }
            Row2 { title: "Status centre"; z: 5; Drop { key: "statusCenter"; options: ["none", "battery", "wifi"] } }
            Row2 { title: "Left click"; z: 4; Drop { key: "clickLeft"; options: ["cc", "notifs", "media", "calendar", "none"] } }
            Row2 { title: "Right click"; z: 3; Drop { key: "clickRight"; options: ["cc", "notifs", "media", "calendar", "none"] } }
            Row2 { title: "Middle click"; z: 2; Drop { key: "clickMiddle"; options: ["cc", "notifs", "media", "calendar", "none"] } }
            Row2 { title: "Scroll"; z: 1; Drop { key: "scroll"; options: ["volume", "brightness", "none"] } }
        }

        // Shortcuts: a reference of the IPC actions with copy buttons for ready bind blocks (no editing).
        Column {
            id: shortcutsPage
            visible: root.page === "shortcuts"; width: parent.width; spacing: 0
            Repeater {
                model: root.shortcuts
                delegate: Item {
                    required property var modelData
                    objectName: "shortcut_" + modelData.id
                    width: parent.width; height: 22
                    Label { width: 88; height: parent.height; text: modelData.label; elide: Text.ElideRight }
                    Label { x: 90; width: parent.width - 90; height: parent.height; text: modelData.cmd; elide: Text.ElideRight
                        color: Colors.islandFgVar; font.family: Theme.fontMono; font.pixelSize: 10 }
                }
            }
            Item { width: 1; height: 8 }
            Row {
                spacing: 6
                Chip { objectName: "copyHypr"; text: "Copy Hyprland binds"; onClicked: root.copyBinds(false) }
                Chip { objectName: "copyLua"; text: "Copy Lua binds"; onClicked: root.copyBinds(true) }
            }
        }

        // Modules: the surfaces on/off (modules.*) and the composer for the rest pill, the hover face
        // and the control center (Composer). Changes apply live and persist; Reset layout drops
        // the user's layout so the defaults apply again.
        Column {
            id: modulesPage
            objectName: "modulesPage"
            visible: root.page === "modules"; width: parent.width; spacing: 6
            Binding { target: root; property: "composerRowH"; value: 28 }
            Row {
                spacing: 6
                Repeater {
                    model: root.modulesSections
                    delegate: Chip { required property var modelData; text: modelData.label; on: root.modulesSection === modelData.id
                        onClicked: root.modulesSection = modelData.id }
                }
            }
            // Live preview: the real rest pill / hover face at real size on black, reading the layout being edited.
            Item {
                visible: root.modulesSection === "rest" || root.modulesSection === "hover"
                width: parent.width; height: 48
                Rectangle {
                    objectName: "modulesPreview"
                    readonly property var face: root.modulesSection === "rest" ? restPreview : hoverPreview
                    anchors.centerIn: parent; width: Math.min(parent.width, face.size.width); height: face.size.height
                    radius: Math.min(height / 2, Cfg.Settings.island.radius || 18); color: "#000000"; clip: true
                    // enabled false: a preview must not act on clicks; visible true: the states hide themselves without an island.
                    Rest { id: restPreview; enabled: false; visible: root.modulesSection === "rest" }
                    HoverFace { id: hoverPreview; enabled: false; visible: root.modulesSection === "hover" }
                }
            }
            Column {
                visible: root.modulesSection === "surfaces"; width: parent.width
                Repeater {
                    model: ["media", "notifications", "calendar", "launcher", "wallpapers", "settings"]
                    delegate: Row2 {
                        required property string modelData
                        width: parent.width; height: 34
                        title: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.modules[modelData] !== false
                            onToggled: v => Cfg.Settings.set("modules." + modelData, v) }
                    }
                }
            }
            Column {
                visible: root.modulesSection === "rest"; width: parent.width
                Row2 { width: parent.width; height: 34; title: "Left: activity"
                    Switch { anchors.verticalCenter: parent.verticalCenter; name: "Rest left, activity circle"; on: Cfg.Composer.restLeft === "activity"
                        onToggled: v => Cfg.Composer.setRest("left", v ? "activity" : "none") } }
                Row2 { width: parent.width; height: 34; title: "Centre: clock"
                    Label { height: parent.height; text: "Always shown"; color: Colors.islandFgVar } }
                Row2 { width: parent.width; height: 34; title: "Right: status"
                    Switch { anchors.verticalCenter: parent.verticalCenter; name: "Rest right, status"; on: Cfg.Composer.restRight === "status"
                        onToggled: v => Cfg.Composer.setRest("right", v ? "status" : "none") } }
                Label { width: parent.width; height: 40; wrapMode: Text.WordWrap; color: Colors.islandFgVar; font.pixelSize: 11
                    text: "What the status slot shows is the Status centre setting (Behaviour). A low battery and the mic/camera glyphs show even with it off." }
            }
            Column {
                visible: root.modulesSection === "hover"; width: parent.width
                Repeater {
                    model: Cfg.Composer.hover
                    delegate: LayoutRow { required property var modelData; required property int index
                        layoutSection: "hover"; entry: modelData; pos: index; count: Cfg.Composer.hover.length }
                }
            }
            Column {
                visible: root.modulesSection === "cc"; width: parent.width
                Repeater {
                    model: Cfg.Composer.tiles
                    delegate: LayoutRow { required property var modelData; required property int index
                        layoutSection: "cc"; entry: modelData; pos: index; count: Cfg.Composer.tiles.length }
                }
            }
            // Bottom row: the control center's section switches (on that section) and Reset layout.
            Item {
                width: parent.width; height: 26; visible: root.modulesSection !== "surfaces"
                Row {
                    spacing: 6; visible: root.modulesSection === "cc"
                    Repeater {
                        model: Cfg.Composer.sectionKeys
                        delegate: Chip { required property string modelData; objectName: "ccSection_" + modelData
                            text: Cfg.Composer.sectionLabels[modelData]; on: Cfg.Composer.section(modelData)
                            accName: "Control center " + Cfg.Composer.label(modelData).toLowerCase() + (on ? ", shown" : ", hidden")
                            onClicked: Cfg.Composer.setSection(modelData, !on) }
                    }
                }
                Chip { objectName: "resetLayout"; anchors.right: parent.right; text: "Reset layout"; onClicked: Cfg.Composer.reset() }
            }
        }

        // Lock: settings.json lock.* for the lock and login screens (lockscreen/gen.py reads them);
        // `hush lock` regenerates its layout, the greeter follows through `hush sddm sync`.
        ColumnLayout {
            visible: root.page === "lock"; width: parent.width; spacing: 0
            readonly property real rowH: 32
            Row2 { title: "Clock"; z: 1; Drop { key: "lock.clock"; options: ["quiet", "bold", "stacked"]; onChosen: lockSync.restart() } }
            Row2 { title: "Date"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.date") !== false; onToggled: v => root.setLock("date", v) } }
            Row2 { title: "Name"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.name") !== false; onToggled: v => root.setLock("name", v) } }
            Row2 { title: "Reveal on key"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.reveal") !== false; onToggled: v => root.setLock("reveal", v) } }
            Row2 { title: "Status line"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.status") !== false; onToggled: v => root.setLock("status", v) } }
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
            Label { text: "Dynamic island shell for Hyprland, built on Quickshell."; color: Colors.islandFgVar }
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

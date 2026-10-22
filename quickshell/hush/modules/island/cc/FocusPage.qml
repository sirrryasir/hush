import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services as Svc

// The timer tile's focus page: back, where the session stands, Start / Stop; a ring card with the
// time left and the phase; then three rows: the phase durations as chips (a tap jumps to that phase,
// or starts the session), the cycle dots (long break after the fourth) and the do-not-disturb switch.
Item {
    id: page
    readonly property bool on: Svc.Countdown.phase !== ""
    readonly property int s: Math.max(0, Svc.Countdown.remaining)
    // Idle: the ring is a dial for the phase picked in `sel`; `drag` holds the value while the pointer is down.
    property string sel: "focus"
    property int drag: 0
    readonly property int mins: drag > 0 ? drag : Settings.focus[sel]
    readonly property int cycles: Settings.focus.cycles
    readonly property var words: ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"]
    readonly property var ordinals: ["", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"]
    readonly property string timeText: on ? Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) : (mins < 10 ? "0" : "") + mins + ":00"
    readonly property real progress: on ? s / (Svc.Countdown.phaseMins * 60) : Math.min(1, mins / 60)
    readonly property string subtitle: {
        const c = Svc.Countdown
        const F = Settings.focus.focus, B = Settings.focus.break, L = Settings.focus.long, N = cycles
        if (c.phase === "") return words[N] + (N === 1 ? " focus block" : " focus blocks") + " of " + F + " min, breaks of " + B + ", then " + L
        if (c.phase === "long") return "Long break, then done"
        // The blocks and breaks still ahead of the long break, at full length.
        const ahead = c.phase === "focus" ? (N - c.cycle) * (F + B) * 60 : ((N - c.cycle) * F + (N - 1 - c.cycle) * B) * 60
        const at = new Date(Date.now() + (page.s + ahead) * 1000)
        const o = ordinals[c.cycle]
        return o[0].toUpperCase() + o.slice(1) + " of " + words[N].toLowerCase() + " · long break at "
            + Qt.formatTime(at, String(Settings.island.clock) === "12" ? "h:mm AP" : "hh:mm")
    }
    signal back()

    RowLayout {
        id: head
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 36; spacing: 8
        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18; color: Colors.islandSurfaceHigh
            Text { anchors.centerIn: parent; text: "arrow_back"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 20 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.back(); Accessible.role: Accessible.Button; Accessible.name: "Back" }
        }
        Column {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
            Text { width: parent.width; text: "Focus"; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text {
                objectName: "focusSubtitle"
                width: parent.width; elide: Text.ElideRight; text: page.subtitle; color: Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
        PillButton {
            objectName: "focusButton"
            text: page.on ? "Stop" : "Start"; primary: !page.on
            onClicked: page.on ? Svc.Countdown.stop() : Svc.Countdown.focusStart("focus")
        }
    }

    Rectangle {
        id: card
        anchors.left: parent.left; anchors.top: head.bottom; anchors.bottom: parent.bottom; anchors.topMargin: 12
        width: 180; radius: 14; color: Colors.islandSurfaceHigh
        Column {
            anchors.centerIn: parent; spacing: 8
            Canvas {
                id: ring
                width: 132; height: 132
                property real p: page.progress
                onPChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset(); c.lineWidth = 8; c.lineCap = "round"
                    const r = width / 2 - 4
                    c.strokeStyle = Colors.islandSurfaceHighest; c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke()
                    if (p > 0.005) { c.strokeStyle = Colors.islandPrimary; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
                }
                MouseArea {
                    objectName: "focusDial"
                    anchors.fill: parent; enabled: !page.on
                    onPressed: m => setFromPointer(m)
                    onPositionChanged: m => { if (pressed) setFromPointer(m) }
                    onReleased: if (page.drag > 0) { Settings.set("focus." + page.sel, page.drag); page.drag = 0 }
                    onWheel: w => Settings.set("focus." + page.sel, Math.max(1, Math.min(120, page.mins + (w.angleDelta.y > 0 ? 1 : -1))))
                    // 12 o'clock = 0, clockwise, a full turn = 60 min.
                    function setFromPointer(m) {
                        const a = Math.atan2(m.x - width / 2, height / 2 - m.y)
                        page.drag = Math.max(1, Math.min(60, Math.round((a < 0 ? a + Math.PI * 2 : a) / (Math.PI * 2) * 60)))
                    }
                }
                Text {
                    objectName: "focusTime"
                    anchors.centerIn: parent; text: page.timeText; color: Colors.islandFg
                    font.family: Theme.fontUi; font.pixelSize: 30; font.weight: Font.Medium; font.features: { "tnum": 1 }
                }
            }
            Text {
                objectName: "focusPhase"
                anchors.horizontalCenter: parent.horizontalCenter
                text: (page.on ? Svc.Countdown.phaseLabel : ({ focus: "Focus", break: "Break", long: "Long break" })[page.sel]) + " · " + (page.on ? Svc.Countdown.phaseMins : page.mins) + " min" + (page.on ? "" : " · drag the ring")
                color: Colors.islandFgVar; font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }

    component Entry: Rectangle {
        id: entry
        property string icon: ""
        property string title: ""
        property string sub: ""
        default property alias trailing: trail.data
        Layout.fillWidth: true; Layout.fillHeight: true; radius: 14; color: Colors.islandSurfaceHigh
        Text {
            id: glyph; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
            text: entry.icon; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 22
        }
        Column {
            anchors.left: glyph.right; anchors.leftMargin: 10; anchors.right: trail.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: entry.title; elide: Text.ElideRight; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium }
            Text { width: parent.width; text: entry.sub; elide: Text.ElideRight; color: Colors.islandFg; opacity: 0.75; font.family: Theme.fontUi; font.pixelSize: 11 }
        }
        Row { id: trail; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 6 }
    }
    ColumnLayout {
        anchors.left: card.right; anchors.right: parent.right; anchors.top: card.top; anchors.bottom: parent.bottom; anchors.leftMargin: 12
        spacing: 12
        Entry {
            icon: "timer"; title: "Phases"; sub: "Focus, break, long break"
            Repeater {
                model: ["focus", "break", "long"]
                PillButton {
                    required property string modelData
                    objectName: "focusChip_" + modelData
                    text: String(Settings.focus[modelData]); primary: (page.on ? Svc.Countdown.phase : page.sel) === modelData
                    onClicked: page.on ? Svc.Countdown.focusStart(modelData) : page.sel = modelData
                }
            }
        }
        Entry {
            icon: "repeat"; title: "Cycles"; sub: "Long break after the " + page.ordinals[page.cycles]
            Repeater {
                model: Math.min(8, page.cycles)
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8; width: index + 1 === Svc.Countdown.cycle ? 20 : 8; radius: 4
                    color: index < Svc.Countdown.cycle ? Colors.islandPrimary : Colors.islandSurfaceHighest
                    Behavior on width { NumberAnimation { duration: Theme.durationShort } }
                }
            }
            PillButton {
                objectName: "focusCyclesLess"; glyph: "remove"; enabledLook: !page.on && page.cycles > 1
                onClicked: Settings.set("focus.cycles", page.cycles - 1)
            }
            PillButton {
                objectName: "focusCyclesMore"; glyph: "add"; enabledLook: !page.on && page.cycles < 8
                onClicked: Settings.set("focus.cycles", page.cycles + 1)
            }
        }
        Entry {
            icon: "notifications_off"; title: "Do not disturb"; sub: "On while focused, back to how it was after"
            Rectangle {
                readonly property bool on: Svc.Countdown.focusDnd
                width: 44; height: 36; radius: 18; color: on ? Colors.islandPrimary : Colors.islandSurfaceHighest
                Rectangle {
                    width: 24; height: 24; radius: 12; y: 6
                    x: parent.on ? parent.width - width - 6 : 6
                    color: parent.on ? Colors.islandOnPrimary : Colors.islandFgVar
                    Behavior on x { NumberAnimation { duration: Theme.durationShort } }
                }
                MouseArea {
                    objectName: "focusDndSwitch"
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Svc.Countdown.focusDnd = !Svc.Countdown.focusDnd
                    Accessible.role: Accessible.CheckBox; Accessible.name: "Do not disturb while focused"; Accessible.checked: parent.on
                }
            }
        }
    }
}

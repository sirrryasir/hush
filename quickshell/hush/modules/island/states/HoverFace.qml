import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services as Svc
import "../rest"

// The hover face, 44 px tall and 320 px wide (wider with many chips, up to 656): chips in layout.hover order (default: this monitor's
// workspaces as dots with the active one drawn as a pill, the date, the media title while something
// plays, Bluetooth, Wi-Fi, battery; optional volume, brightness, timer, recording; the shelf chip shows while files are kept). A dot goes to
// its workspace and the date opens the calendar; the active dot or a long press opens the GloView
// overview; any other left click goes to the pill's click mapping.
StateBase {
    id: face
    name: "hover"; priority: 1
    // 320 px at least; grows with the shown chips (and their gaps), 656 px (the widest surface) at most.
    size: Qt.size(Math.max(Sizes.hover.width, Math.min(Sizes.wallpapers.width, Sizes.snap(row.implicitWidth + 2 * row.anchors.leftMargin))), Sizes.hover.height)
    readonly property color fg: island ? island.fg : Colors.darkOnSurface
    readonly property var workspaces: Svc.Hypr.workspacesFor(island ? island.screenName : Svc.Hypr.focusedMonitorName)
    readonly property string title: Svc.Media.playing ? (Svc.Media.title || "") : ""

    // A long press anywhere on the face opens the overview; a short click falls through to the pill.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        Accessible.role: Accessible.Button; Accessible.name: "Workspace overview (long press)"
        onPressAndHold: Svc.Ipc.overview()
        onClicked: if (face.island) face.island.click(Qt.LeftButton)
    }
    // The chips, in layout.hover order (Composer), left to right. "Now playing" takes the spare width
    // (empty while nothing plays); without it a spacer splits the row in the middle. A chip with
    // nothing to say (Bluetooth off, no battery, no timer) leaves no gap.
    readonly property var chips: {
        const ids = Composer.hoverShown.slice()
        if (ids.indexOf("media") < 0) ids.splice(Math.ceil(ids.length / 2), 0, "_spacer")
        return ids
    }
    readonly property var chipComps: ({ workspaces: wsChip, date: dateChip, media: mediaChip, battery: batteryChip,
        network: netChip, bluetooth: btChip, volume: volChip, brightness: briChip, timer: timerChip, shelf: shelfChip,
        recording: recChip, keyboard: kbdChip, _spacer: spacerChip })
    RowLayout {
        id: row
        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 18; anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Repeater {
            model: face.chips
            delegate: Loader {
                required property string modelData
                objectName: modelData === "_spacer" ? "" : "hoverChip_" + modelData
                sourceComponent: face.chipComps[modelData] || null
                visible: item !== null && item.shown !== false
                Layout.fillWidth: modelData === "media" || modelData === "_spacer"
                Layout.minimumWidth: modelData === "media" || modelData === "_spacer" ? 0 : implicitWidth
                Layout.preferredWidth: modelData === "media" || modelData === "_spacer" ? 0 : implicitWidth
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
    Component { id: spacerChip; Item { implicitHeight: 1 } }
    Component {
        id: wsChip
        Row {
            spacing: 6
            Accessible.role: Accessible.Grouping; Accessible.name: "Workspaces"
            Repeater {
                model: face.workspaces
                delegate: Rectangle {
                    required property var modelData
                    width: modelData.active ? 18 : 6; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.alpha(face.fg, modelData.active ? 1 : (modelData.occupied ? 0.55 : 0.22))
                    Behavior on width { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -4
                        Accessible.role: Accessible.Button
                        Accessible.name: "Workspace " + parent.modelData.name + (parent.modelData.active ? ", current" : "")
                        // The active dot opens the workspace overview (GloView); any other dot goes there.
                        onClicked: parent.modelData.active ? Svc.Ipc.overview() : Svc.Hypr.go(parent.modelData.id)
                    }
                }
            }
        }
    }
    Component {
        id: dateChip
        Text {
            id: date
            text: Qt.formatDate(clock.date, "ddd d MMM")
            color: face.fg
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                Accessible.role: Accessible.Button; Accessible.name: "Calendar, " + date.text
                onClicked: if (face.island) face.island.openSurface("calendar")
            }
        }
    }
    Component {
        id: mediaChip
        Text {
            horizontalAlignment: Text.AlignRight
            text: face.title; elide: Text.ElideRight; maximumLineCount: 1
            color: Colors.alpha(face.fg, 0.7)
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland
            Accessible.role: Accessible.StaticText; Accessible.name: face.title !== "" ? "Now playing, " + face.title : ""
        }
    }
    component Glyph: Text {
        color: Colors.alpha(face.fg, 0.9)
        font.family: Theme.fontIcon; font.pixelSize: 16
    }
    component Readout: Row {
        id: ro
        property string glyph; property string value; property color tint: Colors.alpha(face.fg, 0.9)
        property bool shown: true
        spacing: 3
        Accessible.role: Accessible.StaticText
        Text { anchors.verticalCenter: parent.verticalCenter; text: ro.glyph; color: ro.tint; font.family: Theme.fontIcon; font.pixelSize: 16 }
        Text { anchors.verticalCenter: parent.verticalCenter; text: ro.value; color: Colors.alpha(face.fg, 0.8)
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.features: { "tnum": 1 } }
    }
    // Bluetooth (when on), Wi-Fi, and the battery glyph (larger than at rest, percent inside; hidden
    // without a battery). The resting pill leaves these out.
    Component {
        id: btChip
        Glyph {
            objectName: "hoverBt"
            readonly property bool shown: Svc.Bt.enabled
            text: Svc.Bt.icon; color: Colors.alpha(face.fg, Svc.Bt.connectedName !== "" ? 0.9 : 0.6)
            Accessible.role: Accessible.StaticText; Accessible.name: "Bluetooth" + (Svc.Bt.connectedName !== "" ? ", " + Svc.Bt.connectedName : " on")
        }
    }
    Component {
        id: netChip
        Glyph {
            objectName: "hoverWifi"
            text: Svc.Net.connected ? Svc.Net.icon : "signal_wifi_off"
            Accessible.role: Accessible.StaticText; Accessible.name: Svc.Net.connected ? "Network connected" : "No network"
        }
    }
    Component {
        id: batteryChip
        BatteryGlyph {
            objectName: "hoverBattery"
            readonly property bool shown: Svc.Battery.present
            bodyW: 30; bodyH: 15
            Accessible.role: Accessible.StaticText; Accessible.name: "Battery " + Svc.Battery.percent + " percent"
        }
    }
    // Only while Hyprland has more than one layout; a tap switches to the next.
    Component {
        id: kbdChip
        Text {
            objectName: "hoverKbd"
            readonly property bool shown: Svc.Kbd.count > 1
            text: Svc.Kbd.short
            color: Colors.alpha(face.fg, 0.8)
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
            Accessible.role: Accessible.Button; Accessible.name: "Keyboard layout " + text + ", switch to next"
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Svc.Kbd.next() }
        }
    }
    Component {
        id: volChip
        Readout {
            glyph: Svc.Audio.muted ? "volume_off" : "volume_up"; value: Math.round(Svc.Audio.volume * 100) + "%"
            Accessible.name: "Volume " + Math.round(Svc.Audio.volume * 100) + " percent" + (Svc.Audio.muted ? ", muted" : "")
        }
    }
    Component {
        id: briChip
        Readout {
            shown: Svc.Brightness.available
            glyph: "brightness_6"; value: Math.round(Svc.Brightness.level * 100) + "%"
            Accessible.name: "Brightness " + Math.round(Svc.Brightness.level * 100) + " percent"
        }
    }
    Component {
        id: timerChip
        Readout {
            shown: Svc.Countdown.running
            readonly property int s: Math.max(0, Svc.Countdown.remaining)
            glyph: "timer"; tint: Colors.darkPrimary
            value: Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
            Accessible.name: "Timer, " + value + " left"
        }
    }
    // Files on the shelf: the glyph and the count; a tap opens the strip.
    Component {
        id: shelfChip
        Item {
            readonly property bool shown: Svc.Shelf.count > 0
            implicitWidth: kept.implicitWidth; implicitHeight: kept.implicitHeight
            Readout {
                id: kept
                glyph: "inventory_2"; tint: Colors.darkPrimary; value: String(Svc.Shelf.count)
                Accessible.role: Accessible.Button; Accessible.name: "Shelf, " + value + " kept. Open"
            }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: if (face.island) face.island.openSurface("shelf") }
        }
    }
    Component {
        id: recChip
        Row {
            readonly property bool shown: Svc.Recording.active
            spacing: 5
            Accessible.role: Accessible.StaticText; Accessible.name: "Recording the screen"
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Colors.darkError }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "REC"; color: Colors.alpha(face.fg, 0.8)
                font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold }
        }
    }
    SystemClock { id: clock; precision: SystemClock.Hours }
}

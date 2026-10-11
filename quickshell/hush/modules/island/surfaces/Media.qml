import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services as Svc

// Media surface: accent-tinted art, title and artist, a scrubber that seeks over MPRIS,
// prev/play/next and an optional cava strip. cava runs only while this item is visible; hiding or
// destroying the surface stops it.
Item {
    id: root
    readonly property size size: Sizes.mediaSurface
    width: size.width; height: size.height

    readonly property var player: Svc.Media.player
    readonly property real length: Svc.Media.length
    readonly property real position: scrub.pressed ? scrub.drag : Svc.Media.position
    // !! because a departing player yields undefined fields (and undefined does not assign to bool).
    readonly property bool canSeek: !!(player && player.canSeek && player.positionSupported) && length > 0
    readonly property color tint: Colors.islandPrimary

    // settings modules.media.cava: explicit true/false wins, otherwise on when cava is installed.
    property bool cavaInstalled: false
    readonly property var cavaSetting: Settings.get("modules.media.cava")
    readonly property bool cavaWanted: cavaSetting === undefined || cavaSetting === null ? cavaInstalled : !!cavaSetting
    property var bars: []

    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    Process { running: true; command: ["sh", "-c", "command -v cava"]; onExited: (code) => root.cavaInstalled = code === 0 }
    Process {
        id: cava
        running: root.visible && root.cavaWanted
        command: ["sh", "-c", 'c="${XDG_RUNTIME_DIR:-/tmp}/hush-cava.conf"; '
            + 'printf "[general]\\nbars = 28\\nframerate = 30\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\n" > "$c"; '
            + 'exec cava -p "$c"']
        stdout: SplitParser {
            onRead: (line) => { const a = line.split(";"); a.pop(); if (a.length) root.bars = a.map(Number) }
        }
        onRunningChanged: if (!running) root.bars = []
    }

    // Card: dark base washed with the accent.
    ClippingRectangle {
        anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
        Rectangle { anchors.fill: parent; color: root.tint; opacity: 0.16 }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.islandShadow, 0) }
                GradientStop { position: 1; color: Colors.alpha(Colors.islandShadow, 0.6) }
            }
        }
    }

    ClippingRectangle {
        id: artBox
        x: 16; y: 16; width: 88; height: 88; radius: 14; color: Colors.islandPrimaryContainer
        Image {
            id: art
            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
            source: Svc.Media.artUrl; sourceSize: Qt.size(176, 176); asynchronous: true
            visible: status === Image.Ready
        }
        // Accent tint over the art: multiply-like darkening plus an overlay wash.
        Rectangle { anchors.fill: parent; color: root.tint; opacity: art.visible ? 0.28 : 0 }
        Rectangle { anchors.fill: parent; color: Colors.islandPrimaryContainer; opacity: art.visible ? 0.12 : 0 }
        Text {
            anchors.centerIn: parent; visible: !art.visible
            text: "music_note"; color: Colors.islandOnPrimaryContainer
            font.family: Theme.fontIcon; font.pixelSize: 36
        }
    }

    Column {
        x: 120; y: 20; width: root.width - 120 - 20; spacing: 2
        Text {
            width: parent.width; text: Svc.Media.title || "Nothing playing"; elide: Text.ElideRight
            color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; text: Svc.Media.artist; visible: text !== ""; elide: Text.ElideRight
            color: Colors.islandFg; opacity: 0.7; font.family: Theme.fontUi; font.pixelSize: 13
        }
    }

    // Spectrum strip, only built while cava is running.
    Row {
        id: strip
        x: 120; y: 66; width: root.width - 120 - 20; height: 38; spacing: 3
        visible: cava.running && root.bars.length > 0
        Repeater {
            model: root.bars.length
            delegate: Rectangle {
                required property int index
                readonly property real v: Math.min(100, root.bars[index] || 0) / 100
                width: (strip.width - (root.bars.length - 1) * 3) / Math.max(1, root.bars.length)
                height: Math.max(2, v * strip.height); anchors.bottom: parent.bottom
                radius: width / 2; color: root.tint; opacity: 0.35 + 0.65 * v
            }
        }
    }

    // Scrubber.
    Item {
        id: scrub
        x: 16; y: 116; width: root.width - 32; height: 20
        readonly property bool pressed: ma.pressed
        property real drag: 0
        readonly property real frac: root.length > 0 ? Math.min(1, Math.max(0, root.position / root.length)) : 0
        Rectangle { id: track; y: 6; width: parent.width; height: 4; radius: 2; color: Colors.islandFg; opacity: 0.2 }
        Rectangle { y: 6; width: parent.width * scrub.frac; height: 4; radius: 2; color: root.tint }
        Rectangle {
            x: parent.width * scrub.frac - width / 2; y: 3; width: 10; height: 10; radius: 5
            color: Colors.islandFg; visible: root.canSeek
        }
        Text {
            y: 14; text: root.fmt(root.position); color: Colors.islandFg; opacity: 0.6
            font.family: Theme.fontUi; font.pixelSize: 10; font.features: { "tnum": 1 }
        }
        Text {
            y: 14; anchors.right: parent.right; text: root.length > 0 ? root.fmt(root.length) : ""
            color: Colors.islandFg; opacity: 0.6; font.family: Theme.fontUi; font.pixelSize: 10; font.features: { "tnum": 1 }
        }
        MouseArea {
            id: ma
            Accessible.role: Accessible.Slider; Accessible.name: "Seek"
            // Keyboard: n steps of 5 s, committed at once.
            function stepAdjust(n) {
                if (!root.player) return
                const p = Math.min(root.length, Math.max(0, root.position + n * 5)); scrub.drag = p
                root.player.position = p; Svc.Media.position = p
            }
            anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6; enabled: root.canSeek
            function at(x) { return Math.min(1, Math.max(0, x / width)) * root.length }
            onPressed: (m) => scrub.drag = at(m.x)
            onPositionChanged: (m) => { if (pressed) scrub.drag = at(m.x) }
            onReleased: { if (root.player) { root.player.position = scrub.drag; Svc.Media.position = scrub.drag } }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: 140; spacing: 18
        Repeater {
            model: [
                { g: "skip_previous", f: "previous", big: false },
                { g: Svc.Media.playing ? "pause" : "play_arrow", f: "toggle", big: true },
                { g: "skip_next", f: "next", big: false }
            ]
            delegate: Rectangle {
                required property var modelData
                width: modelData.big ? 44 : 36; height: width; radius: width / 2; anchors.verticalCenter: parent.verticalCenter
                color: modelData.big ? root.tint : (btn.containsMouse ? Colors.alpha(Colors.islandFg, 0.13) : "transparent")
                Text {
                    anchors.centerIn: parent; text: modelData.g
                    color: modelData.big ? Colors.islandOnPrimary : Colors.islandFg
                    font.family: Theme.fontIcon; font.pixelSize: modelData.big ? 28 : 24
                }
                MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; onClicked: Svc.Media[modelData.f]()
                    Accessible.role: Accessible.Button; Accessible.name: modelData.f === "toggle" ? (Svc.Media.playing ? "Pause" : "Play") : modelData.f === "next" ? "Next track" : "Previous track" }
            }
        }
    }
}

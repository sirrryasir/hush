import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Hush lock screen: a thin clock and the date in capitals over the blurred,
// dimmed wallpaper; a key, the pointer or a tap reveals the user name, one black pill (the island)
// holding the password dots, and a status line under it, all hidden again 2 s after the field
// empties. The pill collapses to a circle with an arc while checking, shakes with a red hairline and a
// red status on a failure, and dissolves upward on success.
// Filled by quickshell/hush/lock.qml.
Rectangle {
    id: root
    color: "black"

    // ---- what the host fills ------------------------------------------------------------------
    property string userName: ""
    property url background: ""
    property var glyphs: []                    // Material Symbols names, top right
    property string message: ""                // muted status under the pill (fingerprint prompt)
    property string fontName: "Inter Variable"
    property string iconFontName: "Material Symbols Rounded"
    signal submit(string password)
    property QtObject colors: null             // an object with the island roles (the shell's Colors)

    // ---- palette: the shell's island roles, with fallbacks ------------------------------------
    QtObject {
        id: pal
        property color islandPrimary: root.colors ? root.colors.islandPrimary : "#9cd1c1"
        property color islandError: root.colors ? root.colors.islandError : "#ffb4ab"
    }

    // ---- layout ----
    QtObject {
        id: lay
        property real base: 1080
        property real clock12: 0
        property real clockCy: 0.32
        property real clockSize: 160
        property real clockWeight: 100
        property real clockTracking: -4.8
        property real clockStack: 0
        property real dateCy: 0.4033
        property real dateSize: 16
        property real dateWeight: 500
        property real dateTracking: 4.8
        property real userCy: 0.6435
        property real userSize: 13
        property real userTracking: 3.25
        property real pillCy: 0.70
        property real pillW: 340
        property real pillH: 56
        property real pillOutlineAlpha: 0.12
        property real fieldDot: 8
        property real fieldDotGap: 10
        property real statusCy: 0.7546
        property real statusSize: 14
        property real iconsTop: 49
        property real iconsRight: 40
        property real iconsSize: 18
        property real blurRadius: 24
        property real blurBrightness: 0.6
        property real blurSaturation: 0.85
        property real motionFadeMs: 250
        property real motionCheckMs: 260
        property real motionErrorMs: 600
        property real motionShakeMs: 300
        property real motionShakePx: 8
        property real motionSuccessMs: 300
        property real motionSuccessLift: 24
    }
    // s = H / 1080; lengths round to even pixels
    readonly property real s: height / lay.base
    function px(v) { return 2 * Math.round(v * s / 2); }
    function fs(v) { return Math.round(v * s); }
    readonly property color edge: Qt.rgba(1, 1, 1, lay.pillOutlineAlpha)

    // ---- state ------------------------------------------------------------------------------
    // idle | checking | error | success
    property string phase: "idle"
    property string failText: ""                // the last failure, until the next key
    // the pill, name and status hide until a key or the pointer wakes them (2 s after the last one)
    readonly property bool awake: field.text.length > 0 || pillHover.hovered || wake.running || phase !== "idle"
    Timer { id: wake; interval: 2000 }
    HoverHandler { // only real movement: compositors resend the resting position, and the cursor is there at map time
        property var last: null
        onPointChanged: {
            const p = point.position;
            if (last && (p.x !== last.x || p.y !== last.y)) wake.restart();
            last = Qt.point(p.x, p.y);
        }
    }
    TapHandler { onTapped: wake.restart() }
    onMessageChanged: wake.restart()

    function trySubmit() {
        if (phase === "checking" || phase === "success" || field.text.length === 0)
            return;
        phase = "checking";
        root.submit(field.text);
    }
    function fail(reason) {
        phase = "error";
        failText = reason;
        field.text = "";
        errorTimer.restart();
        wake.restart();
        shake.restart();
        field.forceActiveFocus();
    }
    function succeed() { phase = "success"; }
    Timer { id: errorTimer; interval: lay.motionErrorMs; onTriggered: if (root.phase === "error") root.phase = "idle" }

    Component.onCompleted: field.forceActiveFocus()
    Timer { interval: 300; running: true; onTriggered: field.forceActiveFocus() } // after the window maps

    // ---- background: one MultiEffect pass ------------------------------------------------------
    // a margin past the edges keeps the blur from fading into the window border
    Image {
        id: wall
        anchors.fill: parent
        anchors.margins: -root.px(60)
        source: root.background
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        autoPaddingEnabled: false
        visible: wall.status === Image.Ready
        blurEnabled: true
        blurMax: Math.round(lay.blurRadius * root.s * 2.5)  // MultiEffect's radius vs a CSS blur sigma
        blur: root.phase === "success" ? 0 : 1
        saturation: lay.blurSaturation - 1
        Behavior on blur { NumberAnimation { duration: lay.motionSuccessMs; easing.type: Easing.OutQuint } }
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: 1 - lay.blurBrightness } // multiply by brightness

    // ---- top right: battery and network ---------------------------------------------------------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.px(lay.iconsRight)
        y: Math.round(lay.iconsTop * root.s - height / 2)
        spacing: root.px(8)
        Repeater {
            model: root.glyphs
            Text {
                required property string modelData
                text: modelData
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: root.iconFontName
                font.pixelSize: root.fs(lay.iconsSize)
            }
        }
    }

    // ---- clock and date ------------------------------------------------------------------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Item {
        id: hero
        anchors.fill: parent
        opacity: root.phase === "success" ? 0 : 1
        transform: Translate { y: root.phase === "success" ? -root.px(lay.motionSuccessLift) : 0
            Behavior on y { NumberAnimation { duration: lay.motionSuccessMs; easing.type: Easing.OutQuint } } }
        Behavior on opacity { NumberAnimation { duration: lay.motionSuccessMs; easing.type: Easing.OutQuint } }

        // stacked: HH over MM, clockStack x size apart; clockCy is then the block's centre
        readonly property real pitch: lay.clockStack * lay.clockSize * root.s
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.clockCy - hero.pitch / 2 - height / 2)   // Inter's line box centre is its figures' centre
            text: Qt.formatTime(root.now, hero.pitch > 0 ? (lay.clock12 > 0 ? "h" : "hh") : lay.clock12 > 0 ? "h:mm AP" : "hh:mm")
            color: "white"
            font.family: root.fontName
            font.pixelSize: root.fs(lay.clockSize)
            font.weight: lay.clockWeight
            font.variableAxes: { "wght": lay.clockWeight, "opsz": 32 } // optical size as a browser sets it (Inter's display cut)
            font.letterSpacing: lay.clockTracking * root.s
            font.features: { "calt": 0 } // the colon on the baseline (Inter's calt raises it)
            renderType: Text.CurveRendering // distance-field text breaks up a 100-weight stroke at this size
        }
        Text {
            visible: hero.pitch > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: clock.y + Math.round(hero.pitch)
            text: Qt.formatTime(root.now, "mm")
            color: clock.color
            font: clock.font
            renderType: clock.renderType
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.dateCy - height / 2)
            text: Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: root.fontName
            font.pixelSize: root.fs(lay.dateSize)
            font.weight: lay.dateWeight
            font.variableAxes: { "wght": lay.dateWeight, "opsz": lay.dateSize }
            font.letterSpacing: lay.dateTracking * root.s
        }
        Text { // user name over the pill
            opacity: root.awake ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: lay.motionFadeMs; easing.type: Easing.OutQuint } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.userCy - height / 2)
            text: root.userName.toUpperCase()
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: root.fontName
            font.pixelSize: root.fs(lay.userSize)
            font.letterSpacing: lay.userTracking * root.s
        }
        Text { // status under the pill: the host's message, or the last failure in the error colour
            objectName: "status"
            opacity: root.awake ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: lay.motionFadeMs; easing.type: Easing.OutQuint } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.statusCy - height / 2)
            text: root.failText || root.message
            color: root.failText ? pal.islandError : Qt.rgba(1, 1, 1, 0.55)
            font.family: root.fontName
            font.pixelSize: root.fs(lay.statusSize)
        }
    }

    // ---- the pill ------------------------------------------------------------------------------
    Rectangle {
        id: pill
        objectName: "pill"
        property real shakeX: 0
        width: root.phase === "checking" || root.phase === "success" ? height : root.px(lay.pillW)
        height: root.px(lay.pillH)
        radius: height / 2
        x: Math.round((root.width - width) / 2 + shakeX)
        y: Math.round(root.height * lay.pillCy - height / 2)
        color: "black"
        border.width: 1
        border.color: root.failText ? pal.islandError : root.edge
        clip: true
        opacity: root.phase === "success" || !root.awake ? 0 : 1
        scale: root.phase === "success" ? 0.96 : 1

        Behavior on width { NumberAnimation { duration: lay.motionCheckMs; easing.type: Easing.OutQuint } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: root.phase === "success" ? lay.motionSuccessMs : lay.motionFadeMs; easing.type: Easing.OutQuint } }
        Behavior on scale { NumberAnimation { duration: lay.motionSuccessMs; easing.type: Easing.OutQuint } }

        HoverHandler { id: pillHover }

        SequentialAnimation {
            id: shake
            readonly property int leg: Math.round(lay.motionShakeMs / 6)
            loops: 1
            NumberAnimation { target: pill; property: "shakeX"; to: root.px(lay.motionShakePx); duration: shake.leg; easing.type: Easing.OutQuad }
            NumberAnimation { target: pill; property: "shakeX"; to: -root.px(lay.motionShakePx); duration: shake.leg }
            NumberAnimation { target: pill; property: "shakeX"; to: root.px(lay.motionShakePx); duration: shake.leg }
            NumberAnimation { target: pill; property: "shakeX"; to: -root.px(lay.motionShakePx); duration: shake.leg }
            NumberAnimation { target: pill; property: "shakeX"; to: root.px(lay.motionShakePx); duration: shake.leg }
            NumberAnimation { target: pill; property: "shakeX"; to: 0; duration: shake.leg; easing.type: Easing.InQuad }
        }

        // the field: an invisible TextInput drives our own dots
        TextInput {
            id: field
            objectName: "password"
            x: pill.height; width: Math.max(0, pill.width - 2 * pill.height)
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0
            echoMode: TextInput.Password
            enabled: root.phase !== "checking" && root.phase !== "success"
            focus: true
            Keys.onPressed: wake.restart()
            onTextChanged: if (text.length > 0) root.failText = ""
            onAccepted: root.trySubmit()
            Keys.onEscapePressed: text = ""
        }
        Item {
            id: textArea
            x: field.x; width: field.width
            height: pill.height
            clip: true
            opacity: root.phase === "checking" || root.phase === "success" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Row {
                id: dots
                anchors.verticalCenter: parent.verticalCenter
                // centred while it fits, then the newest dots stay visible at the right edge
                x: Math.min((parent.width - width) / 2, parent.width - width)
                spacing: root.px(lay.fieldDotGap)
                Repeater {
                    model: field.text.length
                    Rectangle {
                        width: root.px(lay.fieldDot); height: width; radius: width / 2
                        color: "white"
                        NumberAnimation on scale { from: 0.4; to: 1; duration: 120; easing.type: Easing.OutQuint }
                    }
                }
            }
        }
    }

    // checking: a 2 px primary arc spinning around the collapsed circle
    Shape {
        id: spinner
        objectName: "spinner"
        width: pill.height; height: width
        x: Math.round((root.width - width) / 2); y: pill.y
        visible: opacity > 0
        opacity: root.phase === "checking" ? 1 : 0
        // fades in; leaves at once, or it would ghost over the pill as it grows back on an error
        Behavior on opacity { NumberAnimation { duration: root.phase === "checking" ? 150 : 0 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: pal.islandPrimary
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: spinner.width / 2; centerY: spinner.height / 2; radiusX: spinner.width / 2 - 1; radiusY: radiusX; startAngle: -90; sweepAngle: 100 }
        }
        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: spinner.visible }
    }
}

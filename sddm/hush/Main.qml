import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Hush login screen, layout B "island-native": the same screen as the hyprlock lock (thin clock,
// date, one black pill holding the password, hidden until a key or the pointer wakes it) plus the
// greeter's avatar in the pill and three black circles at the bottom (session, sleep, power). The
// pill morphs: it grows on focus, shows a submit button once there is text, collapses to a circle
// with an arc while checking, shakes with a red hairline on a wrong password, and dissolves upward
// on success.
// Everything user-specific comes from current/ (~/.cache/hush/sddm, written by `hush sddm sync`):
// colors.qml, layout.qml (from lockscreen/layout.toml), wallpaper.png, face.png. Each one is optional:
// the baked defaults below match harbor and the shipped layout. No XMLHttpRequest file reads.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    // ---- fonts (bundled by sddm/install.sh: the sddm user cannot see ~/.local fonts) -----------
    FontLoader { id: interFont; source: "fonts/InterVariable.ttf" }
    FontLoader { id: iconFont; source: "fonts/MaterialSymbolsRounded.ttf" }
    readonly property string fontName: interFont.status === FontLoader.Ready ? interFont.name : (config.stringValue("font") || "Inter")
    readonly property bool iconsReady: iconFont.status === FontLoader.Ready

    // ---- palette: harbor defaults, overridden by current/colors.qml ------------------------------
    QtObject {
        id: pal
        property color surface: "#111413"
        property color fg: "#e1e3e0"
        property color fgVar: "#c0c9c4"
        property color islandFg: "#e1e3e0"
        property color islandFgVar: "#c0c9c4"
        property color islandPrimary: "#9cd1c1"
        property color islandPrimaryText: "#00382d"
        property color islandSurfaceHigh: "#282b29"
        property color islandError: "#ffb4ab"
        property color wallText: "#e1e3e0"
        property color wallShade: "#111413"
    }
    Loader {
        source: config.stringValue("colorsQml") || "current/colors.qml"
        onLoaded: root.copyInto(item, pal)
    }

    // ---- layout: lockscreen/layout.toml defaults, overridden by current/layout.qml ---------------
    QtObject {
        id: lay
        property real base: 1080
        property real clockCy: 0.3704
        property real clock12: 0
        property real clockSize: 280
        property real clockWeight: 100
        property real clockTracking: -2
        property real dateCy: 0.56
        property real dateSize: 28
        property real dateWeight: 500
        property real pillCy: 0.7037
        property real pillW: 380
        property real pillH: 72
        property real pillFocusW: 420
        property real pillOutlineAlpha: 0.12
        property real avatarSize: 56
        property real avatarInset: 8
        property real fieldLeft: 76
        property real fieldRight: 76
        property real fieldPlaceholder: 15
        property real fieldDot: 8
        property real fieldDotGap: 10
        property real submitSize: 48
        property real submitInset: 12
        property real glyphSize: 20
        property real glyphInset: 26
        property real hintCy: 0.7648
        property real hintSize: 13
        property real powerCy: 0.9333
        property real powerSize: 40
        property real powerGap: 12
        property real powerMenuItem: 36
        property real blurSddmBlur: 0.45
        property real blurSddmBlurMax: 32
        property real blurSddmBrightness: -0.12
        property real blurSddmSaturation: 0.10
        property real motionFadeMs: 250
        property real motionFocusMs: 220
        property real motionSubmitMs: 100
        property real motionCheckMs: 260
        property real motionErrorMs: 600
        property real motionShakeMs: 300
        property real motionShakePx: 8
        property real motionSuccessMs: 300
        property real motionSuccessLift: 24
    }
    Loader {
        source: config.stringValue("layoutQml") || "current/layout.qml"
        onLoaded: root.copyInto(item, lay)
    }

    function copyInto(from, to) {
        for (var k in to) {
            if (from.hasOwnProperty(k) && typeof from[k] !== "function" && k !== "objectName")
                to[k] = from[k];
        }
    }

    // s = H / 1080; lengths round to even pixels like the hyprlock emitter
    readonly property real s: height / lay.base
    function px(v) { return 2 * Math.round(v * s / 2); }
    function fs(v) { return Math.round(v * s); }
    readonly property color edge: Qt.rgba(1, 1, 1, lay.pillOutlineAlpha)

    // ---- state ------------------------------------------------------------------------------
    // idle | checking | error | success
    property string phase: "idle"
    // the pill and the user name hide until a key or the pointer wakes them (2 s after the last one)
    readonly property bool awake: field.text.length > 0 || pillHover.hovered || wake.running || phase !== "idle"
    Timer { id: wake; interval: 2000 }
    HoverHandler { onPointChanged: wake.restart() }
    TapHandler { onTapped: wake.restart() }
    readonly property string userName: userModel.lastUser || (userModel.count > 0 ? userModel.data(userModel.index(0, 0), 257) : "")
    property int sessionIndex: 0
    property var sessionOrder: []   // model indices, Hyprland first
    readonly property string testAuth: config.stringValue("testAuth") || ""

    function sessionName(i) {
        return i >= 0 && i < sessionModel.count ? sessionModel.data(sessionModel.index(i, 0), 260) || "" : "";
    }
    function buildSessions() {
        var first = [], rest = [];
        for (var i = 0; i < sessionModel.count; i++)
            (/^hyprland/i.test(sessionName(i)) ? first : rest).push(i);
        // plain "Hyprland" before variants such as "Hyprland (uwsm-managed)"
        first.sort(function (a, b) { return sessionName(a).length - sessionName(b).length || a - b; });
        sessionOrder = first.concat(rest);
        // SDDM remembers the last session (state.conf) as lastIndex, but reports 0 when it has none;
        // a 0 that is not a Hyprland entry is read as "nothing remembered" and Hyprland is preselected
        var last = sessionModel.lastIndex;
        var remembered = last > 0 && last < sessionModel.count || (last === 0 && /^hyprland/i.test(sessionName(0)));
        sessionIndex = remembered ? last : (sessionOrder.length ? sessionOrder[0] : 0);
    }

    function submit() {
        if (phase === "checking" || phase === "success" || field.text.length === 0)
            return;
        phase = "checking";
        if (testAuth !== "")
            fakeAuth.restart();
        else
            sddm.login(userName, field.text, sessionIndex);
    }
    function failed() {
        phase = "error";
        field.text = "";
        errorTimer.restart();
        wake.restart();
        shake.restart();
        field.forceActiveFocus();
    }
    function succeeded() { phase = "success"; }

    Connections {
        target: sddm
        function onLoginFailed() { root.failed(); }
        function onLoginSucceeded() { root.succeeded(); }
    }
    // theme.conf testAuth=fail|succeed: stands in for the daemon under --test-mode (empty in production)
    Timer { id: fakeAuth; interval: 900; onTriggered: root.testAuth === "succeed" ? root.succeeded() : root.failed() }
    Timer { id: errorTimer; interval: lay.motionErrorMs; onTriggered: if (root.phase === "error") root.phase = "idle" }

    Component.onCompleted: {
        buildSessions();
        field.forceActiveFocus();
        console.log("hush-greeter: font=" + root.fontName + " icons=" + root.iconsReady + " sessions="
                    + sessionOrder.map(sessionName).join("|") + " selected=" + sessionName(sessionIndex));
    }
    Timer { interval: 300; running: true; onTriggered: if (!menu.open) field.forceActiveFocus() } // after the window maps

    // ---- background: one MultiEffect pass ------------------------------------------------------
    Image {
        id: wall
        anchors.fill: parent
        source: config.stringValue("background") || "current/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        autoPaddingEnabled: false
        visible: wall.status === Image.Ready
        blurEnabled: true
        blurMax: lay.blurSddmBlurMax
        blur: root.phase === "success" ? 0 : lay.blurSddmBlur
        brightness: lay.blurSddmBrightness
        saturation: lay.blurSddmSaturation
        Behavior on blur { NumberAnimation { duration: lay.motionSuccessMs; easing.type: Easing.OutQuint } }
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

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.clockCy - height / 2)
            text: Qt.formatTime(root.now, lay.clock12 > 0 ? "h:mm AP" : "hh:mm")
            color: pal.wallText
            font.family: root.fontName
            font.pixelSize: root.fs(lay.clockSize)
            font.weight: lay.clockWeight
            font.variableAxes: { "wght": lay.clockWeight }
            font.letterSpacing: lay.clockTracking * root.s
            font.features: { "tnum": 1 }
            renderType: Text.CurveRendering // distance-field text breaks up a 100-weight stroke at this size
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.dateCy - height / 2)
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: Qt.alpha(pal.wallText, 0.72)
            font.family: root.fontName
            font.pixelSize: root.fs(lay.dateSize)
            font.weight: lay.dateWeight
            font.variableAxes: { "wght": lay.dateWeight }
        }
        Text { // user name under the pill
            opacity: root.awake ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: lay.motionFadeMs; easing.type: Easing.OutQuint } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * lay.hintCy - height / 2)
            text: root.userName
            color: pal.wallText
            font.family: root.fontName
            font.pixelSize: root.fs(lay.hintSize)
            font.weight: 500
        }
    }

    // ---- the pill ------------------------------------------------------------------------------
    Rectangle {
        id: pill
        objectName: "pill"
        // the field holds focus from the start (keyboard-first), so "focus" is engagement: typing or
        // pointing at the pill grows it 380 -> 420
        readonly property bool engaged: field.text.length > 0 || pillHover.hovered
        readonly property real restW: root.px(engaged ? lay.pillFocusW : lay.pillW)
        property real shakeX: 0
        width: root.phase === "checking" || root.phase === "success" ? height : restW
        height: root.px(lay.pillH)
        radius: height / 2
        x: Math.round((root.width - width) / 2 + shakeX)
        y: Math.round(root.height * lay.pillCy - height / 2)
        color: "black"
        border.width: 1
        border.color: root.phase === "error" ? pal.islandError : root.edge
        clip: true
        opacity: root.phase === "success" || !root.awake ? 0 : 1
        scale: root.phase === "success" ? 0.96 : 1

        Behavior on width { NumberAnimation { duration: root.phase === "checking" ? lay.motionCheckMs : lay.motionFocusMs; easing.type: Easing.OutQuint } }
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

        // avatar disc, inset on the left; centred in the 72 px circle while checking
        Item {
            id: avatar
            width: root.px(lay.avatarSize); height: width
            x: (pill.height - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: avatarImg
                anchors.fill: parent
                source: config.stringValue("avatar") || "current/face.png"
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: false
                onStatusChanged: if (status === Image.Error)
                    source = config.stringValue("fallbackAvatar") || "assets/avatar.png"
            }
            Rectangle { id: avatarMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            MultiEffect { anchors.fill: parent; source: avatarImg; maskEnabled: true; maskSource: avatarMask }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: root.edge }
        }

        // the field: an invisible TextInput drives our own dots and placeholder
        TextInput {
            id: field
            objectName: "password"
            x: root.px(lay.fieldLeft); width: pill.width - x - root.px(lay.fieldRight)
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0
            echoMode: TextInput.Password
            enabled: root.phase !== "checking" && root.phase !== "success"
            focus: true
            Keys.onPressed: wake.restart()
            onAccepted: root.submit()
            Keys.onEscapePressed: text = ""
            Keys.onTabPressed: sessionBtn.forceActiveFocus()
            KeyNavigation.backtab: powerBtn
        }
        Item {
            id: textArea
            x: root.px(lay.fieldLeft); width: Math.max(0, pill.width - x - root.px(lay.fieldRight))
            height: pill.height
            clip: true
            opacity: root.phase === "checking" || root.phase === "success" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                visible: field.text.length === 0
                text: "Password"
                color: Qt.alpha(pal.islandFg, 0.6)
                font.family: root.fontName
                font.pixelSize: root.fs(lay.fieldPlaceholder)
            }
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
                        color: pal.islandFg
                        NumberAnimation on scale { from: 0.4; to: 1; duration: 120; easing.type: Easing.OutQuint }
                    }
                }
            }
        }

        // caps lock glyph (left of the submit button when that shows)
        Text {
            readonly property bool on: typeof keyboard !== "undefined" && keyboard !== null && keyboard.capsLock
            visible: on && root.phase !== "checking"
            anchors.verticalCenter: parent.verticalCenter
            x: pill.width - root.px(lay.glyphInset) - width / 2 - (submit.opacity > 0.5 ? root.px(lay.submitSize + 4) : 0)
            text: root.iconsReady ? "keyboard_capslock" : "⇪"
            color: pal.islandFgVar
            font.family: root.iconsReady ? iconFont.name : root.fontName
            font.pixelSize: root.fs(lay.glyphSize)
        }

        // round submit button, only while there is text
        Rectangle {
            id: submit
            objectName: "submit"
            width: root.px(lay.submitSize); height: width; radius: width / 2
            x: pill.width - width - root.px(lay.submitInset)
            anchors.verticalCenter: parent.verticalCenter
            color: submitArea.containsMouse ? Qt.lighter(pal.islandSurfaceHigh, 1.3) : pal.islandSurfaceHigh
            opacity: field.text.length > 0 && root.phase === "idle" ? 1 : 0
            visible: opacity > 0
            scale: opacity > 0 ? 0.9 + 0.1 * opacity : 0.9
            Behavior on opacity { NumberAnimation { duration: lay.motionSubmitMs; easing.type: Easing.OutQuint } }
            Text {
                anchors.centerIn: parent
                text: root.iconsReady ? "arrow_forward" : "→"
                color: pal.islandFg
                font.family: root.iconsReady ? iconFont.name : root.fontName
                font.pixelSize: root.fs(22)
            }
            MouseArea { id: submitArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
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

    // ---- bottom row: session, sleep, power -----------------------------------------------------
    component CircleButton: Rectangle {
        id: cb
        property string icon
        property string fallback
        property bool active: false
        signal activated
        width: root.px(lay.powerSize); height: width; radius: width / 2
        color: "black"
        border.width: 1
        border.color: activeFocus || active ? pal.islandPrimary : root.edge
        activeFocusOnTab: true
        opacity: enabled ? 1 : 0.4
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
        Text {
            anchors.centerIn: parent
            text: root.iconsReady ? cb.icon : cb.fallback
            color: cbArea.containsMouse || cb.activeFocus ? pal.islandFg : pal.islandFgVar
            font.family: root.iconsReady ? iconFont.name : root.fontName
            font.pixelSize: root.fs(20)
        }
        MouseArea { id: cbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cb.activated() }
    }

    Row {
        id: powerRow
        opacity: root.phase === "success" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: lay.motionSuccessMs; easing.type: Easing.OutQuint } }
        spacing: root.px(lay.powerGap)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * lay.powerCy - height / 2)
        CircleButton {
            id: sessionBtn
            objectName: "sessionButton"
            icon: "desktop_windows"; fallback: "▭"
            active: menu.open && menu.kind === "session"
            visible: sessionModel.count > 0
            onActivated: menu.toggle("session", sessionBtn)
            KeyNavigation.tab: sleepBtn
        }
        CircleButton {
            id: sleepBtn
            icon: "bedtime"; fallback: "☾"
            enabled: sddm.canSuspend
            onActivated: sddm.suspend()
            KeyNavigation.tab: powerBtn
        }
        CircleButton {
            id: powerBtn
            objectName: "powerButton"
            icon: "power_settings_new"; fallback: "⏻"
            active: menu.open && menu.kind === "power"
            onActivated: menu.toggle("power", powerBtn)
            KeyNavigation.tab: field
        }
    }

    // ---- popups: a black rounded list opening upward from its button ----------------------------
    MouseArea { // click outside closes
        anchors.fill: parent
        visible: menu.open
        onClicked: menu.close()
    }
    Rectangle {
        id: menu
        objectName: "menu"
        property bool open: false
        property string kind: "session"
        property Item anchorItem: sessionBtn
        property int current: 0
        readonly property var items: kind === "session"
            ? root.sessionOrder.map(function (i) { return { label: root.sessionName(i), value: i }; })
            : [{ label: "Restart", value: "reboot" }, { label: "Shut down", value: "poweroff" }]

        function toggle(k, from) {
            if (open && kind === k) { close(); return; }
            kind = k; anchorItem = from; measure(); open = true;
            current = 0;
            if (k === "session")
                for (var j = 0; j < items.length; j++) if (items[j].value === root.sessionIndex) current = j;
            forceActiveFocus();
        }
        function close() { open = false; field.forceActiveFocus(); }
        function choose(j) {
            var it = items[j];
            if (!it) return;
            if (kind === "session") { root.sessionIndex = it.value; close(); }
            else if (it.value === "reboot") sddm.reboot();
            else sddm.powerOff();
        }

        property real labelW: 0
        TextMetrics { id: menuMetrics; font.family: root.fontName; font.pixelSize: root.fs(14); font.weight: 500 }
        function measure() {
            var m = 0;
            for (var j = 0; j < items.length; j++) { menuMetrics.text = items[j].label; m = Math.max(m, menuMetrics.advanceWidth); }
            labelW = m;
        }
        width: Math.max(root.px(150), Math.ceil(labelW) + root.px(28 + 24 + 12))
        height: list.implicitHeight + root.px(12)
        radius: root.px(18)
        color: "black"
        border.width: 1
        border.color: root.edge
        x: Math.round(Math.min(root.width - width - root.px(16), Math.max(root.px(16),
           powerRow.x + anchorItem.x + anchorItem.width / 2 - width / 2)))
        y: powerRow.y - height - root.px(12)
        opacity: open ? 1 : 0
        visible: opacity > 0
        transform: Translate { y: menu.open ? 0 : root.px(8); Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }

        Keys.onEscapePressed: close()
        Keys.onUpPressed: current = Math.max(0, current - 1)
        Keys.onDownPressed: current = Math.min(items.length - 1, current + 1)
        Keys.onReturnPressed: choose(current)
        Keys.onEnterPressed: choose(current)
        Keys.onTabPressed: close()

        Column {
            id: list
            anchors.centerIn: parent
            Repeater {
                model: menu.items
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool selected: menu.kind === "session" && modelData.value === root.sessionIndex
                    width: menu.width - root.px(12)
                    height: root.px(lay.powerMenuItem)
                    radius: height / 2
                    color: index === menu.current || rowArea.containsMouse ? pal.islandSurfaceHigh : "transparent"
                    Rectangle { // selected session dot
                        visible: parent.selected
                        width: root.px(6); height: width; radius: width / 2
                        color: pal.islandPrimary
                        x: root.px(14); anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: label
                        x: root.px(28); anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.selected || index === menu.current ? pal.islandFg : pal.islandFgVar
                        font.family: root.fontName
                        font.pixelSize: root.fs(14)
                        font.weight: parent.selected ? 500 : 400
                    }
                    MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.choose(index) }
                }
            }
        }
    }
}

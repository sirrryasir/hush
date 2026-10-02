import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Hush login screen. Mirrors the hyprlock layout: blurred dimmed wallpaper, thin clock,
// date, round avatar, pill password field with an accent outline, small session and power
// buttons at the bottom. Colours come from current/colors.conf with harbor fallbacks.
Rectangle {
    id: root
    width: 1280
    height: 720
    color: pal.surface

    FontLoader { id: interFont; source: "fonts/InterVariable.ttf" }
    readonly property string fontName: interFont.status === FontLoader.Ready ? interFont.name : (config.stringValue("font") || "Inter")
    property string failMsg: ""
    property bool busy: false

    // ---- palette (harbor defaults, overridden by colors.conf) -------------------------
    QtObject {
        id: pal
        property color surface: "#111413"
        property color surfaceHigh: "#282b29"
        property color fg: "#e1e3e0"
        property color fgVar: "#c0c9c4"
        property color primary: "#9cd1c1"
        property color primaryText: "#00382d"
        property color outline: "#8a938f"
        property color error: "#ffb4ab"
    }

    // Palette: current/colors.qml (written by `hush sddm sync`, same values as colors.conf).
    // XMLHttpRequest cannot read files in the greeter, so a Loader imports it instead.
    Loader {
        source: config.stringValue("colorsQml") || "current/colors.qml"
        onLoaded: {
            for (var k in pal) {
                if (item.hasOwnProperty(k) && typeof item[k] !== "function")
                    pal[k] = item[k];
            }
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()

    // ---- background -------------------------------------------------------------------
    Image {
        id: wall
        anchors.fill: parent
        source: config.stringValue("background") || "current/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        brightness: 0.0
        saturation: 0.1
    }
    Rectangle { // dim, so text always reads
        anchors.fill: parent
        color: pal.surface
        opacity: 0.2
    }

    // ---- clock and date ---------------------------------------------------------------
    property date now: new Date()
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "hh:mm")
            color: pal.fg
            font.family: root.fontName
            font.italic: false
            font.pixelSize: Math.round(root.height * 0.13)
            font.weight: Font.Thin
            font.variableAxes: { "wght": 200 }
            font.features: { "tnum": 1 }
            style: Text.Raised
            styleColor: Qt.alpha(pal.surface, 0.5)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            color: pal.fgVar
            font.family: root.fontName
            font.italic: false
            font.pixelSize: Math.round(root.height * 0.028)
            font.weight: Font.Light
        }
    }

    // ---- avatar, name, password -------------------------------------------------------
    Column {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.46
        spacing: 16

        Item {
            id: avatarBox
            width: 96; height: 96
            anchors.horizontalCenter: parent.horizontalCenter
            Image {
                id: avatarImg
                anchors.fill: parent
                source: config.stringValue("avatar") || "current/face.png"
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectCrop
                visible: false
                onStatusChanged: if (status === Image.Error)
                    source = config.stringValue("fallbackAvatar") || "assets/avatar.png"
            }
            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: avatarImg
                maskEnabled: true
                maskSource: avatarMask
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Qt.alpha(pal.primary, 0.7)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: userName
            color: pal.fg
            font.family: root.fontName
            font.italic: false
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        Rectangle {
            id: pill
            width: 300; height: 48
            radius: height / 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.alpha(pal.surfaceHigh, 0.6)
            border.width: 2
            border.color: root.failMsg !== "" ? pal.error : pal.primary
            Behavior on border.color { ColorAnimation { duration: 150 } }

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                color: pal.fg
                font.family: root.fontName
            font.italic: false
                font.pixelSize: 20
                selectionColor: pal.primary
                selectedTextColor: pal.primaryText
                enabled: !root.busy
                onTextChanged: root.failMsg = ""
                onAccepted: {
                    root.busy = true;
                    sddm.login(userName, text, sessionIndex);
                }
                Text {
                    anchors.centerIn: parent
                    visible: passwordField.text.length === 0
                    text: root.failMsg !== "" ? root.failMsg : "Password"
                    color: root.failMsg !== "" ? pal.error : Qt.alpha(pal.fgVar, 0.7)
                    font: passwordField.font
                }
            }
        }
    }

    // ---- state ------------------------------------------------------------------------
    readonly property string userName: userModel.lastUser || (userModel.count > 0 ? userModel.data(userModel.index(0, 0), 257) : "")
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property string sessionName: sessionModel.count > 0 ? sessionModel.data(sessionModel.index(sessionIndex, 0), 260) : ""

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            passwordField.text = "";
            root.failMsg = "Wrong password";
            passwordField.forceActiveFocus();
        }
    }

    // ---- bottom bar: session on the left, power on the right --------------------------
    component SmallButton: Rectangle {
        id: btn
        property alias label: lbl.text
        signal clicked
        height: 32
        width: lbl.implicitWidth + 28
        radius: height / 2
        color: area.containsMouse ? Qt.alpha(pal.surfaceHigh, 0.85) : Qt.alpha(pal.surfaceHigh, 0.45)
        opacity: enabled ? 1 : 0.4
        Text {
            id: lbl
            anchors.centerIn: parent
            color: pal.fgVar
            font.family: root.fontName
            font.italic: false
            font.pixelSize: 13
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    SmallButton {
        id: sessionBtn
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        visible: sessionModel.count > 0
        label: root.sessionName
        onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8
        SmallButton { label: "Sleep"; enabled: sddm.canSuspend; onClicked: sddm.suspend() }
        SmallButton { label: "Restart"; enabled: sddm.canReboot; onClicked: sddm.reboot() }
        SmallButton { label: "Shut down"; enabled: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }
}

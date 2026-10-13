import QtQuick
import "." as Hush

// Hush login screen: lockscreen/Screen.qml (copied here by sddm/install.sh) in login mode, fed by
// SDDM's sddm, userModel, sessionModel and config objects. Everything user-specific comes from
// current/ (~/.cache/hush/sddm, written by `hush sddm sync`); each file there is optional.
Item {
    id: root
    width: 1920
    height: 1080

    // the sddm user cannot see ~/.local fonts: sddm/install.sh bundles them
    FontLoader { id: interFont; source: "fonts/InterVariable.ttf" }
    FontLoader { id: iconFont; source: "fonts/MaterialSymbolsRounded.ttf" }
    // theme.conf testAuth=fail|succeed: stands in for the daemon under --test-mode (empty in production)
    readonly property string testAuth: config.stringValue("testAuth") || ""
    property int failures: 0

    function sessionName(i) {
        return i >= 0 && i < sessionModel.count ? sessionModel.data(sessionModel.index(i, 0), 260) || "" : "";
    }
    function buildSessions() {
        var first = [], rest = [];
        for (var i = 0; i < sessionModel.count; i++)
            (/^hyprland/i.test(sessionName(i)) ? first : rest).push(i);
        // plain "Hyprland" before variants such as "Hyprland (uwsm-managed)"
        first.sort(function (a, b) { return sessionName(a).length - sessionName(b).length || a - b; });
        screen.sessions = first.concat(rest).map(function (i) { return { label: sessionName(i), value: i }; });
        // SDDM remembers the last session (state.conf) as lastIndex, but reports 0 when it has none;
        // a 0 that is not a Hyprland entry is read as "nothing remembered" and Hyprland is preselected
        var last = sessionModel.lastIndex;
        var remembered = last > 0 && last < sessionModel.count || (last === 0 && /^hyprland/i.test(sessionName(0)));
        screen.sessionIndex = remembered ? last : (screen.sessions.length ? screen.sessions[0].value : 0);
    }
    function failed() { screen.fail("Wrong password (" + (++failures) + ")"); }

    Hush.Screen {
        id: screen
        anchors.fill: parent
        mode: "login"
        userName: userModel.lastUser || (userModel.count > 0 ? userModel.data(userModel.index(0, 0), 257) : "")
        avatarSource: config.stringValue("avatar") || "current/face.png"
        avatarFallback: config.stringValue("fallbackAvatar") || "assets/avatar.png"
        background: config.stringValue("background") || "current/wallpaper.png"
        colorsSource: config.stringValue("colorsQml") || "current/colors.qml"
        layoutSource: config.stringValue("layoutQml") || "current/layout.qml"
        canSuspend: sddm.canSuspend
        fontName: interFont.status === FontLoader.Ready ? interFont.name : (config.stringValue("font") || "Inter")
        iconFontName: iconFont.name
        iconsReady: iconFont.status === FontLoader.Ready
        onSubmit: password => root.testAuth !== "" ? fakeAuth.restart() : sddm.login(userName, password, sessionIndex)
        onPower: action => action === "suspend" ? sddm.suspend() : action === "reboot" ? sddm.reboot() : sddm.powerOff()
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.failed(); }
        function onLoginSucceeded() { screen.succeed(); }
    }
    Timer { id: fakeAuth; interval: 900; onTriggered: root.testAuth === "succeed" ? screen.succeed() : root.failed() }

    Component.onCompleted: {
        buildSessions();
        console.log("hush-greeter: font=" + screen.fontName + " icons=" + screen.iconsReady + " sessions="
                    + screen.sessions.map(function (s) { return s.label; }).join("|") + " selected=" + sessionName(screen.sessionIndex));
    }
}

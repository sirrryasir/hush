import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// Left slot of the rest pill. Priority: recording dot (pulsing red, 1 Hz), countdown ring
// with mm:ss, then album art in a circle with a thin progress ring while a player is playing (a
// music-note glyph when it has no art). `shown` is false when there is nothing to show; the parent
// then collapses the slot so the pill narrows. The recording/timer/media inputs are plain properties
// bound to the services, so a harness can override them.
Item {
    id: root
    property bool recording: Recording.active
    property bool timerOn: Countdown.running
    property int timerSecs: Countdown.remaining
    // Focus session: the block count ("2/4") after the time; 0 for a plain timer.
    property int focusCycle: Countdown.cycle
    property string phase: Countdown.phase
    onPhaseChanged: timerTotal = 0
    // The next reminder within the hour ("Standup in 12 min"): an alarm glyph and the text, after the timer.
    property string reminderText: Reminders.pill
    property bool mediaOn: Media.player !== null && Media.playing
    property real mediaProgress: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
    property string artUrl: Media.artUrl
    readonly property string mode: !Settings.island.liveActivities ? "" : recording ? "recording" : timerOn ? "timer" : reminderText !== "" ? "reminder" : mediaOn ? "media" : ""
    readonly property bool shown: mode !== ""
    readonly property real progress: mode === "timer" ? timerProgress : mediaProgress
    readonly property bool hasArt: artUrl !== "" && art.status === Image.Ready
    readonly property string timeText: { const s = Math.max(0, timerSecs); const m = Math.floor(s / 60)
        return (m < 10 ? "0" : "") + m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
    // The timer's total is the largest remaining value seen since it started.
    property int timerTotal: 0
    property real timerProgress: timerTotal > 0 ? Math.max(0, Math.min(1, timerSecs / timerTotal)) : 0
    onTimerSecsChanged: if (timerOn && timerSecs > timerTotal) timerTotal = timerSecs
    onTimerOnChanged: if (!timerOn) timerTotal = 0; else if (timerSecs > timerTotal) timerTotal = timerSecs
    implicitWidth: mode === "timer" || mode === "reminder" ? 24 + 6 + timeLabel.implicitWidth + (cycleLabel.visible ? 6 + cycleLabel.implicitWidth : 0) : 24; implicitHeight: 24
    width: implicitWidth; height: implicitHeight

    Rectangle {
        id: recDot
        objectName: "recDot"
        visible: root.mode === "recording"
        anchors.centerIn: ringBox; width: 10; height: 10; radius: 5; color: Colors.darkError
        SequentialAnimation on opacity {
            running: recDot.visible; loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
        }
    }
    Text {
        id: timeLabel
        objectName: "timeLabel"
        visible: root.mode === "timer" || root.mode === "reminder"
        anchors.left: ringBox.right; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
        text: root.mode === "reminder" ? root.reminderText : root.timeText; color: Colors.darkOnSurface
        font.family: root.mode === "reminder" ? Theme.fontUi : Theme.fontMono; font.pixelSize: 11
    }
    Text {
        visible: root.mode === "reminder"
        anchors.centerIn: ringBox; text: "alarm"; color: Colors.darkPrimary
        font.family: Theme.fontIcon; font.pixelSize: 16
    }
    Text {
        id: cycleLabel
        objectName: "cycleLabel"
        visible: root.mode === "timer" && root.focusCycle > 0
        anchors.left: timeLabel.right; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
        text: root.focusCycle + "/4"; color: Colors.darkOnSurface; opacity: 0.6
        font.family: Theme.fontMono; font.pixelSize: 11
    }
    Item { id: ringBox; x: 0; width: 24; height: 24 }

    Item {
        visible: root.mode === "media"
        anchors.centerIn: ringBox; width: 18; height: 18
        Image {
            id: art
            anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop
            sourceSize.width: 48; sourceSize.height: 48; asynchronous: true
            visible: false; layer.enabled: true
        }
        // A visible copy through the mask; the plain Image above only feeds it.
        MultiEffect { anchors.fill: parent; source: art; visible: root.hasArt; maskEnabled: true; maskSource: maskItem
            maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Item { id: maskItem; anchors.fill: parent; visible: false; layer.enabled: true
            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
        Rectangle { anchors.fill: parent; radius: width / 2; visible: !root.hasArt; color: Qt.rgba(1, 1, 1, 0.10)
            Text { anchors.centerIn: parent; text: "music_note"; font.family: Theme.fontIcon; font.pixelSize: 12; color: Colors.darkOnSurface } }
    }
    Canvas {
        id: ring
        anchors.fill: ringBox
        visible: root.mode === "media" || root.mode === "timer"
        property real p: root.progress
        property color track: Qt.rgba(1, 1, 1, 0.16)
        property color fill: Colors.darkPrimary
        onPChanged: requestPaint(); onFillChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.lineWidth = 1.5; c.lineCap = "round"
            const cx = width / 2, cy = height / 2, r = width / 2 - 1.25
            c.strokeStyle = track; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (p > 0.005) { c.strokeStyle = fill; c.beginPath(); c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
        }
    }
}

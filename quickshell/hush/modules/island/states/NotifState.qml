import QtQuick
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import "../cc"

// One notification on the island: app icon, summary, body. 520x36, or 520x56 when the
// body does not fit beside the summary on one line. Hover pauses the hold (the island pauses its
// arbiter); click runs the default action, else opens the notification center. A critical one
// (sticky, never times out) wears a red ring round its icon and a red dot (Colors.darkError).
// A job card (hint x-hush-kind: job, sent by integrations/shell/hush.sh when a long command ends)
// is always 56 tall: a tick or cross disc, the command in mono, "finished" or "failed", then the
// duration (the body), the exit code (x-hush-exit) and the terminal's class and workspace
// (x-hush-window); Open, or a click on the card, focuses that window.
StateBase {
    id: card
    name: "notification"; priority: 3
    // The arbiter's payload; the last one is kept so the card does not blank while it fades out.
    property var n: null
    readonly property var shownN: island && island.payload ? island.payload.n : null
    onShownNChanged: if (shownN) n = shownN
    Component.onCompleted: if (shownN) n = shownN
    readonly property bool critical: !!n && n.urgency === NotificationUrgency.Critical
    readonly property string summary: n ? n.summary : ""
    readonly property string body: n ? n.body.replace(/\s*\n+\s*/g, "  ") : ""
    readonly property var hints: n && n.hints ? n.hints : ({})
    readonly property bool job: hints["x-hush-kind"] === "job"
    readonly property int jobExit: job ? Number(hints["x-hush-exit"]) || 0 : 0
    // Hyprland addresses: hyprctl prints 0x..., Quickshell's toplevels carry the bare hex.
    readonly property string jobWindow: job ? String(hints["x-hush-window"] || "").replace(/^0x/, "") : ""
    onNChanged: if (job) Hyprland.refreshToplevels()
    // "kitty on workspace 3" from the toplevel the shell named; "" once that window is gone.
    readonly property string jobWhere: {
        if (jobWindow === "") return ""
        const v = Hyprland.toplevels.values
        for (let i = 0; i < v.length; i++) {
            if (v[i].address !== jobWindow) continue
            return ((v[i].lastIpcObject || {}).class || "") + (v[i].workspace ? " on workspace " + v[i].workspace.name : "")
        }
        return ""
    }
    readonly property string line: job ? [body, "exit " + jobExit, jobWhere].filter(s => s !== "").join(" · ") : body
    // From the declared width, not this item's own: the item is sized from `size`, which depends on
    // `tall`, which depends on textWidth, so reading `width` here was a binding loop.
    readonly property real textWidth: Sizes.notification.width - (job ? 10 + 36 + 10 + (open.visible ? open.width + 10 : 0) + 10 : 14 + 20 + 10 + 16)
    readonly property bool tall: job || body !== "" && summaryMetrics.advanceWidth + 10 + bodyMetrics.advanceWidth > textWidth
    size: tall ? Sizes.notificationTall : Sizes.notification
    function openJob() {
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + jobWindow + "\" })")
        island.arbiter.lower("notification", n.id)
    }

    TextMetrics { id: summaryMetrics; text: card.summary; font.family: card.job ? Theme.fontMono : Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium }
    TextMetrics { id: bodyMetrics; text: card.body; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland }

    Item {
        id: iconBox
        width: card.job ? 36 : 20; height: width
        anchors.left: parent.left; anchors.leftMargin: card.job ? 10 : 14; anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent; radius: width / 2; visible: card.job
            color: card.jobExit === 0 ? Colors.islandPrimary : Colors.islandErrorContainer
        }
        IconImage {
            id: icon
            anchors.fill: parent; asynchronous: true
            source: card.job ? "" : Notifs.iconSource(card.n)
            visible: source != "" && status === Image.Ready
        }
        Text {
            objectName: "notifGlyph"
            anchors.centerIn: parent; visible: !icon.visible
            text: card.job ? (card.jobExit === 0 ? "check" : "close") : card.critical ? "priority_high" : "notifications"
            color: card.job ? (card.jobExit === 0 ? Colors.islandOnPrimary : Colors.islandError)
                : card.critical ? Colors.darkError : (card.island ? card.island.fg : Colors.darkOnSurface)
            font.family: Theme.fontIcon; font.pixelSize: card.job ? 20 : 18
        }
    }
    // Critical marker: an error-coloured ring round the icon plus a dot on its shoulder.
    Rectangle {
        objectName: "criticalMarker"
        visible: card.critical
        anchors.centerIn: iconBox; width: 26; height: 26; radius: 13
        color: "transparent"; border.width: 1.5; border.color: Colors.darkError
        Rectangle {
            width: 7; height: 7; radius: 3.5; color: Colors.darkError
            border.width: 1; border.color: "#000000"
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -1; anchors.topMargin: -1
        }
    }
    Text {
        id: summaryText
        objectName: "notifTitle"
        anchors.left: iconBox.right; anchors.leftMargin: 10
        anchors.verticalCenter: card.tall ? undefined : parent.verticalCenter
        anchors.top: card.tall ? parent.top : undefined; anchors.topMargin: 10
        width: card.tall && !card.job ? card.textWidth
            : Math.min(Math.ceil(summaryMetrics.advanceWidth) + 1, card.textWidth - (card.job ? verb.width + 6 : 0))
        text: card.summary; elide: Text.ElideRight; maximumLineCount: 1
        color: card.island ? card.island.fg : Colors.darkOnSurface
        font.family: card.job ? Theme.fontMono : Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
    }
    Text {
        id: verb
        objectName: "jobVerb"
        visible: card.job
        anchors.left: summaryText.right; anchors.leftMargin: 6; anchors.baseline: summaryText.baseline
        text: card.jobExit === 0 ? "finished" : "failed"
        color: summaryText.color
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
    }
    Text {
        objectName: "notifBody"
        x: card.tall ? summaryText.x : summaryText.x + summaryText.width + 10
        y: card.tall ? summaryText.y + summaryText.height + 2 : (parent.height - height) / 2
        width: card.tall ? card.textWidth : Math.max(0, card.textWidth - summaryText.width - 10)
        text: card.line; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
        color: Colors.alpha(card.island ? card.island.fg : Colors.darkOnSurface, 0.7)
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland
    }
    MouseArea {
        anchors.fill: parent
        Accessible.role: Accessible.Button
        Accessible.name: (card.critical ? "Critical notification: " : "Notification: ") + card.summary
        onClicked: {
            if (!card.island || !card.n) return
            if (card.job && card.jobWindow !== "") card.openJob()
            else if (Notifs.invokeDefault(card.n)) {
                card.island.arbiter.lower("notification", card.n.id); card.island.arbiter.lower("critical", card.n.id)
            } else card.island.openSurface("notifCenter")
        }
    }
    PillButton {
        id: open
        objectName: "jobOpen"
        visible: card.job && card.jobWindow !== ""
        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
        text: "Open"
        onClicked: card.openJob()
    }
}

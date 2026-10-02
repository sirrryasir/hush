import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.services

// One notification on the island: app icon, summary, body. 520x36, or 520x56 when the
// body does not fit beside the summary on one line. Hover pauses the hold (the island pauses its
// arbiter); click runs the default action, else opens the notification center. A critical one
// (sticky, never times out) wears a red ring round its icon and a red dot (Colors.darkError).
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
    // From the declared width, not this item's own: the item is sized from `size`, which depends on
    // `tall`, which depends on textWidth, so reading `width` here was a binding loop.
    readonly property real textWidth: Sizes.notification.width - 14 - 20 - 10 - 16
    readonly property bool tall: body !== "" && summaryMetrics.advanceWidth + 10 + bodyMetrics.advanceWidth > textWidth
    size: tall ? Sizes.notificationTall : Sizes.notification

    TextMetrics { id: summaryMetrics; text: card.summary; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium }
    TextMetrics { id: bodyMetrics; text: card.body; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland }

    Item {
        id: iconBox
        width: 20; height: 20
        anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
        IconImage {
            id: icon
            anchors.fill: parent; asynchronous: true
            source: Notifs.iconSource(card.n)
            visible: source != "" && status === Image.Ready
        }
        Text {
            anchors.centerIn: parent; visible: !icon.visible
            text: card.critical ? "priority_high" : "notifications"
            color: card.critical ? Colors.darkError : (card.island ? card.island.fg : Colors.darkOnSurface)
            font.family: Theme.fontIcon; font.pixelSize: 18
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
        anchors.left: iconBox.right; anchors.leftMargin: 10
        anchors.verticalCenter: card.tall ? undefined : parent.verticalCenter
        anchors.top: card.tall ? parent.top : undefined; anchors.topMargin: 10
        width: card.tall ? card.textWidth : Math.min(Math.ceil(summaryMetrics.advanceWidth) + 1, card.textWidth)
        text: card.summary; elide: Text.ElideRight; maximumLineCount: 1
        color: card.island ? card.island.fg : Colors.darkOnSurface
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
    }
    Text {
        id: bodyText
        x: card.tall ? summaryText.x : summaryText.x + summaryText.width + 10
        y: card.tall ? summaryText.y + summaryText.height + 2 : (parent.height - height) / 2
        width: card.tall ? card.textWidth : Math.max(0, card.textWidth - summaryText.width - 10)
        text: card.body; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
        color: Colors.alpha(card.island ? card.island.fg : Colors.darkOnSurface, 0.7)
        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland
    }
    MouseArea {
        anchors.fill: parent
        Accessible.role: Accessible.Button
        Accessible.name: (card.critical ? "Critical notification: " : "Notification: ") + card.summary
        onClicked: {
            if (!card.island || !card.n) return
            if (Notifs.invokeDefault(card.n)) {
                card.island.arbiter.lower("notification", card.n.id); card.island.arbiter.lower("critical", card.n.id)
            } else card.island.openSurface("notifCenter")
        }
    }
}

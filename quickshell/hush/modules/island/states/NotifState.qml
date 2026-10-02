import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// One notification on the island: app icon, summary, body. 520x36, or 520x56 when the
// body does not fit beside the summary on one line. Hover pauses the hold; click runs
// the default action or opens the drawer.
StateBase {
    id: card
    name: "notification"; priority: 3
    readonly property var n: Notifs.current
    readonly property string summary: n ? n.summary : ""
    readonly property string body: n ? n.body.replace(/\s*\n+\s*/g, "  ") : ""
    readonly property real textWidth: width - 14 - 20 - 10 - 16
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
            text: "notifications"; color: card.island ? card.island.fg : Colors.darkOnSurface
            font.family: Theme.fontIcon; font.pixelSize: 18
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
        anchors.fill: parent; hoverEnabled: true
        onEntered: Notifs.hold(true)
        onExited: Notifs.hold(false)
        onClicked: {
            if (Notifs.invokeDefault(card.n)) Notifs.next()
            else if (Ipc.drawer && !Ipc.drawer.open) Ipc.drawer.toggle()
        }
    }
}

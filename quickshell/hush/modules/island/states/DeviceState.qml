import QtQuick
import qs.config
import qs.services
import "../cc"

// A removable drive on the island, 520x56 like a tall notification: the drive's name, "28.9 GB · exfat ·
// not mounted", and Mount, Open and Eject. After an eject the same card reads "Safe to remove".
// Payload: { dev } for a drive (read live from Devices, so Mount updates it in place) or { safe: name }.
StateBase {
    id: card
    name: "device"; priority: 3
    size: Sizes.notificationTall
    // The last payload and drive are kept so the card does not blank while it fades out.
    property var p: null
    property var last: null
    readonly property var shownP: island && island.payload && (island.payload.dev || island.payload.safe) ? island.payload : null
    onShownPChanged: if (shownP) p = shownP
    Component.onCompleted: if (shownP) p = shownP
    readonly property var d: p && p.dev ? Devices.find(p.dev) : null
    onDChanged: if (d) last = d
    readonly property bool safe: !!p && !!p.safe
    readonly property string title: safe ? "Safe to remove" : last ? last.name : ""
    readonly property string sub: safe ? p.safe + " unmounted and powered off"
        : last ? last.size + " · " + last.fs + " · " + (last.mount ? "mounted" : "not mounted") : ""
    readonly property color fg: island ? island.fg : Colors.darkOnSurface
    property alias mountBtn: mountBtn
    property alias openBtn: openBtn
    property alias ejectBtn: ejectBtn
    function done() { if (island && last) island.arbiter.lower("device", last.dev) }

    Rectangle {
        id: badge
        width: 40; height: 40; radius: 20
        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
        color: card.safe ? Colors.islandPrimaryContainer : Colors.islandSurfaceHighest
        Text {
            anchors.centerIn: parent; text: card.safe ? "check" : "usb"; color: card.fg
            font.family: Theme.fontIcon; font.pixelSize: 22
        }
    }
    Column {
        anchors.left: badge.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
        anchors.right: buttons.visible ? buttons.left : parent.right; anchors.rightMargin: 12
        Text {
            width: parent.width; text: card.title; elide: Text.ElideRight; color: card.fg
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium
        }
        Text {
            width: parent.width; text: card.sub; elide: Text.ElideRight; color: Colors.alpha(card.fg, 0.7)
            font.family: Theme.fontUi; font.pixelSize: Theme.textIsland - 1
        }
    }
    Row {
        id: buttons
        visible: !card.safe
        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        PillButton { id: mountBtn; text: "Mount"; primary: true; visible: !!card.last && !card.last.mount
            onClicked: Devices.mount(card.last) }
        PillButton { id: openBtn; text: "Open"; enabledLook: !!card.last && !!card.last.mount
            onClicked: { Devices.open(card.last); card.done() } }
        PillButton { id: ejectBtn; glyph: "eject"
            onClicked: { Devices.eject(card.last); card.done() } }
    }
}

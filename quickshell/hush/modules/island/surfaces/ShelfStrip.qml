import QtQuick
import Quickshell
import qs.config
import qs.services

// The shelf strip: one chip per kept file (icon, name, "folder · N h left"). Drag a chip into any app
// (text/uri-list), double click opens it; the round buttons at the right copy or remove the chip last
// clicked. Closing when the shelf empties is the island's job (it watches Shelf.count).
Item {
    id: strip
    property size size: Sizes.shelf
    property string current: ""
    readonly property string selected: Shelf.items.some(i => i.path === current) ? current : (Shelf.count ? Shelf.items[0].path : "")
    readonly property color fg: Colors.darkOnSurface
    function copy() {
        if (selected) Quickshell.execDetached(["wl-copy", "-t", "text/uri-list", "file://" + selected + "\r\n"])
    }

    ListView {
        id: list
        objectName: "shelfList"
        anchors { left: parent.left; leftMargin: 10; right: buttons.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        height: 40; orientation: ListView.Horizontal; spacing: 8; clip: true
        model: Shelf.items
        delegate: Rectangle {
            id: chip
            required property var modelData
            objectName: "shelfChip"
            readonly property string summary: Shelf.nameOf(modelData.path) + " | " + Shelf.folderOf(modelData.path) + " · " + Shelf.left(modelData.at)
            width: 200; height: 40; radius: 20
            color: Colors.alpha(strip.fg, 0.1)
            border.width: 2; border.color: strip.selected === modelData.path ? Colors.darkPrimary : "transparent"
            Row {
                anchors.fill: parent; anchors.leftMargin: 8; spacing: 8
                Rectangle {
                    width: 28; height: 28; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: Colors.alpha(strip.fg, 0.08)
                    Text { anchors.centerIn: parent; text: "description"; color: strip.fg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                }
                Column {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter; width: 144
                    Text { width: parent.width; elide: Text.ElideMiddle; text: chip.summary.slice(0, chip.summary.indexOf(" |")); color: strip.fg
                        font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium }
                    Text { width: parent.width; elide: Text.ElideRight; text: chip.summary.slice(chip.summary.indexOf("|") + 2)
                        color: Colors.alpha(strip.fg, 0.7); font.family: Theme.fontUi; font.pixelSize: 11 }
                }
            }
            MouseArea {
                id: grab
                anchors.fill: parent
                Accessible.role: Accessible.Button; Accessible.name: Shelf.nameOf(chip.modelData.path) + ". Drag out, double click to open"
                onClicked: strip.current = chip.modelData.path
                onDoubleClicked: Quickshell.execDetached(["xdg-open", chip.modelData.path])
                // Dragged past the press slop, the native drag starts and Wayland takes it from here.
                drag.target: ghost; drag.threshold: 8
            }
            Item {
                id: ghost
                width: 1; height: 1
                Drag.active: grab.drag.active
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.mimeData: ({ "text/uri-list": "file://" + chip.modelData.path + "\r\n", "text/plain": chip.modelData.path })
            }
        }
    }
    Row {
        id: buttons
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 8
        Repeater {
            model: [{ n: "shelfCopy", g: "content_copy", t: "Copy as file" }, { n: "shelfRemove", g: "close", t: "Remove" }]
            delegate: Rectangle {
                id: btn
                required property var modelData
                objectName: modelData.n
                width: 36; height: 36; radius: 18; color: Colors.alpha(strip.fg, 0.14)
                Text { anchors.centerIn: parent; text: btn.modelData.g; color: strip.fg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                MouseArea {
                    anchors.fill: parent
                    Accessible.role: Accessible.Button; Accessible.name: btn.modelData.t
                    onClicked: btn.modelData.n === "shelfCopy" ? strip.copy() : Shelf.remove(strip.selected)
                }
            }
        }
    }
}

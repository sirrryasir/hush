import QtQuick
import Quickshell.Widgets
import qs.config
import qs.config as Cfg

// The grid itself. `files` is a list of absolute paths; `pick(path)` is emitted on Enter or click.
Item {
    id: root
    property var files: []
    signal pick(string path)
    signal dismiss()

    function moveBy(n) { grid.currentIndex = Math.max(0, Math.min(grid.count - 1, grid.currentIndex + n)) }
    function focusCurrent() {
        const i = root.files.indexOf(Cfg.State.wallpaper)
        grid.currentIndex = i >= 0 ? i : 0
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
        grid.forceActiveFocus()
    }

    GridView {
        id: grid
        anchors.fill: parent
        cellWidth: 182
        cellHeight: 99 + 24 + 8
        clip: true
        model: root.files
        currentIndex: 0
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (grid.currentIndex >= 0 && grid.currentIndex < root.files.length) root.pick(root.files[grid.currentIndex])
                event.accepted = true
            }
        }

        delegate: Item {
            id: cell
            required property int index
            required property string modelData
            readonly property bool current: modelData === Cfg.State.wallpaper
            width: grid.cellWidth
            height: grid.cellHeight

            ClippingRectangle {
                id: thumb
                x: 3; y: 3
                width: 176; height: 99
                radius: 14
                color: Colors.surface_container_high
                border.width: cell.current ? 2 : (grid.currentIndex === cell.index ? 1 : 0)
                border.color: cell.current ? Colors.primary : Colors.outline
                Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("file://" + encodeURI(cell.modelData).replace(/#/g, "%23"))
                    sourceSize: Qt.size(352, 198)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Border drawn above the image so it stays visible.
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: cell.current ? 2 : (grid.currentIndex === cell.index ? 1 : 0)
                    border.color: cell.current ? Colors.primary : Colors.outline
                }
            }
            Text {
                x: 3; y: 99 + 6
                width: 176
                text: {
                    const parts = cell.modelData.split("/")
                    const base = parts.pop().replace(/\.[^.]+$/, "")
                    return base === "wallpaper" ? parts.pop() : base
                }
                elide: Text.ElideRight
                color: cell.current ? Colors.primary : Colors.on_surface_variant
                font.family: Theme.fontUi
                font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = cell.index
                onClicked: root.pick(cell.modelData)
            }
        }
    }
}

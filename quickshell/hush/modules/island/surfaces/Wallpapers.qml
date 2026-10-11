import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.config as Cfg

// Wallpapers surface (design 2.6): a grid of every theme wallpaper plus images found in the
// directories of HUSH_WALL_DIRS (colon-separated). Hover or arrows move the highlight; Enter or a
// click runs `hush wall <path> --from X,Y` with X,Y the tile's centre in global pixels, so the
// circle reveal grows from the tile. Esc emits `close`.
Item {
    id: root
    property size size: Sizes.wallpapers
    property var files: []
    readonly property int count: files.length
    readonly property alias currentIndex: grid.currentIndex
    // Global (compositor) position of this item's top-left. A host that knows it sets `origin`;
    // otherwise it is the window position of this item plus `screenOffset` (the window sits at its
    // screen's top-left, as the island surface does), read at pick time so a mid-morph layout never sticks.
    property var origin: null
    property point screenOffset: Qt.point(0, 0)
    function globalOrigin() {
        if (origin) return origin
        const p = root.mapToItem(null, 0, 0)
        return Qt.point(screenOffset.x + p.x, screenOffset.y + p.y)
    }
    property string hushBin: Paths.hush
    // The --from of the last pick, "X,Y" (tests read it).
    property string lastFrom: ""
    signal close()
    signal picked(string path, point from)

    function pickIndex(i) {
        if (i < 0 || i >= files.length) return
        // A pick by path (IPC, Settings) can name a tile scrolled out of the grid: bring it into
        // view first so the reveal grows from where the tile is drawn, never from below the pill.
        grid.currentIndex = i
        grid.positionViewAtIndex(i, GridView.Contain)
        grid.forceLayout()
        const it = grid.itemAtIndex(i)
        const raw = it ? it.mapToItem(root, it.thumbCentre.x, it.thumbCentre.y)
                       : Qt.point(root.width / 2, root.height / 2)
        const c = Qt.point(Math.max(grid.x, Math.min(grid.x + grid.width, raw.x)),
                           Math.max(grid.y, Math.min(grid.y + grid.height, raw.y)))
        const o = globalOrigin()
        const from = Qt.point(Math.round(o.x + c.x), Math.round(o.y + c.y))
        lastFrom = from.x + "," + from.y
        // Detached: the host closes the surface on picked(), which destroys this item mid-transition.
        Quickshell.execDetached([root.hushBin, "wall", files[i], "--from", from.x + "," + from.y])
        root.picked(files[i], from)
    }
    function focusCurrent() {
        const i = files.indexOf(Cfg.State.wallpaper)
        grid.currentIndex = i >= 0 ? i : 0
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
        grid.forceActiveFocus()
    }
    onFilesChanged: if (files.length) Qt.callLater(focusCurrent)

    Process {
        id: lister
        property var found: []
        command: ["bash", "-c",
            "IFS=: read -ra d <<<\"${HUSH_WALL_DIRS:-}\"; find \"${d[@]}\" \"$1\" -maxdepth 2 -type f " +
            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) 2>/dev/null | sort", "hush-wallpapers", Paths.themes]
        running: Paths.ready
        stdout: SplitParser { onRead: line => { if (line.length) lister.found.push(line) } }
        onExited: root.files = lister.found.slice()
    }

    GridView {
        id: grid
        anchors.fill: parent; anchors.margins: 16
        cellWidth: 208; cellHeight: 112 + 24 + 8
        clip: true
        model: root.files
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.pickIndex(grid.currentIndex); event.accepted = true }
        }

        delegate: Item {
            id: cell
            required property int index
            required property string modelData
            readonly property bool current: modelData === Cfg.State.wallpaper
            readonly property bool sel: grid.currentIndex === index
            readonly property point thumbCentre: Qt.point(thumb.x + thumb.width / 2, thumb.y + thumb.height / 2)
            width: grid.cellWidth; height: grid.cellHeight

            ClippingRectangle {
                id: thumb
                x: 4; y: 3; width: 200; height: 112; radius: 14
                color: Colors.islandSurfaceHigh
                Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("file://" + encodeURI(cell.modelData).replace(/#/g, "%23"))
                    sourceSize: Qt.size(400, 224)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent; radius: 14; color: "transparent"
                    border.width: cell.current || cell.sel ? 2 : 1
                    border.color: cell.current ? Colors.islandPrimary : cell.sel ? Colors.islandFg : Colors.islandOutline
                }
            }
            Text {
                x: 4; y: 112 + 8; width: 200
                text: {
                    const parts = cell.modelData.split("/")
                    const base = parts.pop().replace(/\.[^.]+$/, "")
                    return base === "wallpaper" ? parts.pop() : base
                }
                elide: Text.ElideRight
                color: cell.current ? Colors.islandPrimary : cell.sel ? Colors.islandFg : Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onEntered: grid.currentIndex = cell.index
                onClicked: { grid.currentIndex = cell.index; root.pickIndex(cell.index) }
                Accessible.role: Accessible.Button; Accessible.name: "Wallpaper " + cell.modelData.split("/").slice(-2).join(" ")
            }
        }
    }
}

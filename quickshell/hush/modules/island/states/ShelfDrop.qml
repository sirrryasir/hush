import QtQuick
import QtQuick.Shapes
import qs.config

// What the pill becomes while a file is dragged over it: a dashed outline and "Drop to keep".
StateBase {
    id: drop
    name: "shelfDrop"; size: Sizes.shelfDrop; priority: 65

    Shape {
        id: sh
        anchors.fill: parent; anchors.margins: 5
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Colors.darkPrimary; strokeWidth: 1; fillColor: "transparent"
            strokeStyle: ShapePath.DashLine; dashPattern: [3, 3]
            startX: sh.height / 2; startY: 0
            PathLine { x: sh.width - sh.height / 2; y: 0 }
            PathArc { x: sh.width - sh.height / 2; y: sh.height; radiusX: sh.height / 2; radiusY: sh.height / 2 }
            PathLine { x: sh.height / 2; y: sh.height }
            PathArc { x: sh.height / 2; y: 0; radiusX: sh.height / 2; radiusY: sh.height / 2 }
        }
    }
    Row {
        anchors.centerIn: parent; spacing: 8
        Text { text: "add"; color: Colors.darkPrimary; font.family: Theme.fontIcon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Drop to keep"; color: Colors.darkPrimary; font.family: Theme.fontUi; font.pixelSize: Theme.textIsland; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
}

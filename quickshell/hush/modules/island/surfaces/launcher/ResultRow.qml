import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config

// One launcher result: a leading icon (app icon, a Material glyph, or an image thumbnail), the name
// with an optional description line under it, and a right-aligned hint.
Item {
    id: row
    property var entry
    property bool selected: false
    // Decoded clipboard thumbnails by id (Clip.thumbs); entry.thumbId picks one.
    property var thumbs: ({})
    signal clicked()
    signal hovered()
    height: 44

    readonly property string glyph: entry && entry.glyph ? entry.glyph : ""
    readonly property string thumb: entry && entry.thumbId && thumbs[entry.thumbId] ? thumbs[entry.thumbId] : ""
    readonly property string desc: entry && entry.desc ? entry.desc : ""

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: row.selected ? Colors.alpha(Colors.islandPrimary, 0.16) : "transparent"
    }
    Item {
        id: lead
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        width: 28; height: 28
        IconImage {
            anchors.fill: parent
            visible: row.glyph === "" && row.thumb === ""
            implicitSize: 28
            asynchronous: true
            source: visible ? Quickshell.iconPath(row.entry ? row.entry.icon : "", "application-x-executable") : ""
        }
        Text {
            objectName: "rowGlyph"
            anchors.centerIn: parent
            visible: row.glyph !== "" && thumbImg.status !== Image.Ready
            text: row.glyph
            font.family: Theme.fontIcon; font.pixelSize: 22
            color: row.selected ? Colors.islandPrimary : Colors.islandFgVar
        }
        ClippingRectangle {
            anchors.centerIn: parent
            width: 36; height: 28; radius: 6
            color: "transparent"
            visible: thumbImg.status === Image.Ready
            Image {
                id: thumbImg
                objectName: "rowThumb"
                anchors.fill: parent
                source: row.thumb
                sourceSize: Qt.size(72, 56)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }
    }
    Text {
        id: hint
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, parent.width * 0.4)
        elide: Text.ElideRight
        text: row.entry && row.entry.hint ? row.entry.hint : ""
        font.family: Theme.fontUi
        font.pixelSize: 12
        color: Colors.islandFgVar
    }
    Column {
        anchors { left: lead.right; leftMargin: 14; right: hint.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        Text {
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            text: row.entry ? row.entry.name : ""
            font.family: Theme.fontUi
            font.pixelSize: Theme.textLauncher
            color: row.selected ? Colors.islandPrimary : Colors.islandFg
        }
        Text {
            objectName: "rowDesc"
            width: parent.width
            visible: row.desc !== ""
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            text: row.desc
            font.family: Theme.fontUi
            font.pixelSize: 11
            color: Colors.islandFgVar
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: row.hovered()
        onClicked: row.clicked()
        Accessible.role: Accessible.Button; Accessible.name: row.entry ? row.entry.name : ""
    }
}

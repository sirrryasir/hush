import QtQuick
import Quickshell.Widgets
import qs.config
import qs.config as Cfg
import qs.services as Svc

// The installed themes as wallpaper cards; the active one gets a primary border.
ListView {
    id: strip
    implicitHeight: 44
    orientation: ListView.Horizontal; spacing: 8; clip: true
    interactive: contentWidth > width
    model: Svc.Ipc.themeNames
    delegate: ClippingRectangle {
        id: card
        required property string modelData
        readonly property bool active: Cfg.State.theme === modelData
        width: 72; height: 44; radius: 10; color: Colors.islandSurfaceHigh
        Image {
            anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
            source: "file://" + Paths.themes + "/" + card.modelData + "/wallpaper.png"
            sourceSize: Qt.size(144, 88)
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 24
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.islandShadow, 0) }
                GradientStop { position: 1; color: Colors.alpha(Colors.islandShadow, 0.8) }
            }
        }
        Text {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 6; anchors.rightMargin: 4; anchors.bottomMargin: 3
            text: card.modelData; elide: Text.ElideRight; color: Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
        }
        Rectangle {
            anchors.fill: parent; radius: card.radius; color: "transparent"
            border.width: card.active ? 2 : 0; border.color: Colors.islandPrimary
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Svc.Ipc.setTheme(card.modelData); Accessible.role: Accessible.Button; Accessible.name: "Theme " + card.modelData }
    }
}

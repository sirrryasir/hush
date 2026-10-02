pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string fontUi: "Inter Variable"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontIcon: "Material Symbols Rounded"
    readonly property int textIsland: 13
    readonly property int textCorner: 12
    readonly property int textLauncher: 14
    readonly property int textControl: 13
    readonly property int topMargin: 6
    readonly property int exclusiveTop: 48
    readonly property size islandRest: Qt.size(320, 36)
    readonly property size islandMedia: Qt.size(420, 36)
    readonly property size islandNotification: Qt.size(520, 36)
    readonly property size islandNotificationTall: Qt.size(520, 56)
    readonly property size islandOsd: Qt.size(300, 36)
    readonly property size islandExpanded: Qt.size(560, 320)
    readonly property int radiusExpanded: 20
    readonly property real springStiffness: 4.2
    readonly property real springDamping: 0.42
    readonly property int durationShort: 120
    readonly property int durationNormal: 220
    readonly property int osdHoldMs: 1200
    readonly property int notificationHoldMs: 5000
    readonly property int hoverExpandMs: 400
}

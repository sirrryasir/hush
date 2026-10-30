pragma Singleton
import QtQuick
import Quickshell

// Declared island sizes per state: the pill morphs to these before the state's content
// loads, so the shape never waits on a layout. Widths sit on the 8 px grid (snap()); a state item may
// still report a different `size` (a tall notification) and the pill follows it once that item shows.
Singleton {
    id: root
    readonly property size rest: Qt.size(104, 36)
    readonly property size hover: Qt.size(320, 44)
    readonly property size media: Qt.size(424, 36)
    readonly property size mediaSurface: Qt.size(420, 180)
    readonly property size osd: Qt.size(304, 36)
    readonly property size notification: Qt.size(520, 36)
    readonly property size notificationTall: Qt.size(520, 56)
    // The control center: 560x304 is the declared (and smallest) size; its surface reports the real
    // height, which grows by 56 px tiles to expandedMax (header 44, five rows of 56 + 8 gaps, sliders 32,
    // theme strip 44, three 12 px gaps, 24 margin).
    readonly property size expanded: Qt.size(560, 304)
    readonly property size expandedMax: Qt.size(560, 492)
    readonly property size calendar: Qt.size(360, 336)
    readonly property size wallpapers: Qt.size(656, 320)
    // Settings grows past the other panels so the Modules composer lists fit without scrolling.
    // The island window's fixed height is the tallest surface plus the largest top gap (24).
    readonly property size settings: Qt.size(560, 336)
    readonly property size notifCenter: Qt.size(480, 260)
    readonly property size launcher: Qt.size(520, 300)
    readonly property size overview: Qt.size(672, 474)
    readonly property size shelf: Qt.size(520, 56)
    readonly property size shelfDrop: Qt.size(320, 44)
    readonly property int radiusExpanded: 20
    readonly property int windowHeight: Math.max(settings.height, expandedMax.height) + 24

    function snap(w) { return Math.ceil(w / 8) * 8 }
    function of(name) {
        switch (name) {
        case "hover": return hover
        case "media": return media
        case "mediaSurface": return mediaSurface
        case "osd": return osd
        case "notification": return notification
        case "device": return notificationTall
        case "expanded": return expanded
        case "calendar": return calendar
        case "wallpapers": return wallpapers
        case "settings": return settings
        case "launcher": return launcher
        case "overview": return overview
        case "notifCenter": return notifCenter
        case "shelf": return shelf
        case "shelfDrop": return shelfDrop
        default: return rest
        }
    }
    function area(s) { return s.width * s.height }
    // Pill corner radius for a size: a full capsule up to the 44 px hover face, a rounded panel above.
    function radiusFor(h) { return h <= hover.height ? h / 2 : radiusExpanded }
}

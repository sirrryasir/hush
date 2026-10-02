pragma Singleton
import QtQuick
import Quickshell

// Declared island sizes per state (design 2.5): the pill morphs to these before the state's content
// loads, so the shape never waits on a layout. Widths sit on the 8 px grid (snap()); a state item may
// still report a different `size` (a tall notification) and the pill follows it once that item shows.
Singleton {
    id: root
    readonly property size rest: Qt.size(320, 36)
    readonly property size media: Qt.size(424, 36)
    readonly property size mediaSurface: Qt.size(420, 180)
    readonly property size osd: Qt.size(304, 36)
    readonly property size notification: Qt.size(520, 36)
    readonly property size notificationTall: Qt.size(520, 56)
    readonly property size expanded: Qt.size(560, 320)
    readonly property size calendar: Qt.size(360, 300)
    readonly property int radiusExpanded: 20

    function snap(w) { return Math.ceil(w / 8) * 8 }
    function of(name) {
        switch (name) {
        case "media": return media
        case "mediaSurface": return mediaSurface
        case "osd": return osd
        case "notification": return notification
        case "expanded": return expanded
        case "calendar": return calendar
        default: return rest
        }
    }
    function area(s) { return s.width * s.height }
    // Pill corner radius for a size: a full capsule up to 36 px tall, a rounded panel above.
    function radiusFor(h) { return h <= 36 ? h / 2 : radiusExpanded }
}

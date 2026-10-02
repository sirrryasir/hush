import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.modules.island.surfaces

// Harness: the Calendar surface alone, at its declared size on a black pill, centred near the top.
// Run with: qs -p tests/harness/calendar.qml   (IPC target "harness-calendar": todayText, monthTitle, upcomingCount, next/prev)
ShellRoot {
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-calendar"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 60
        implicitWidth: Sizes.calendar.width; implicitHeight: Sizes.calendar.height
        exclusiveZone: 0
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            Calendar { id: cal; anchors.fill: parent }
        }
    }
    IpcHandler {
        target: "harness-calendar"
        function todayText(): string { return cal.todayText }
        function monthTitle(): string { return cal.monthTitle }
        function upcomingCount(): int { return cal.upcoming.length }
        function size(): string { return cal.size.width + "x" + cal.size.height }
        function next(): void { cal.shift(1) }
        function prev(): void { cal.shift(-1) }
    }
}

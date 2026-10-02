import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.modules.island.surfaces

// Harness: the NotificationCenter surface alone with a FAKE host (never the notification server, so the
// live shell keeps D-Bus ownership). Three notifications from two apps. Run: qs -p tests/harness/notifs.qml
ShellRoot {
    id: root
    QtObject {
        id: fake
        property bool dnd: false
        property var invoked: []
        property var list: [
            { appName: "Mail", summary: "Re: Quarterly plan", body: "Looks good to me, let's ship it on Thursday and revisit the numbers afterwards.", appIcon: "", actions: [{ identifier: "default", text: "Open", invoke: () => {} }, { identifier: "reply", text: "Reply", invoke: () => {} }, { identifier: "archive", text: "Archive", invoke: () => {} }] },
            { appName: "Mail", summary: "Invoice #4021", body: "Your invoice is ready.", appIcon: "", actions: [] },
            { appName: "Calendar", summary: "Standup in 5 minutes", body: "", appIcon: "", actions: [{ identifier: "snooze", text: "Snooze", invoke: () => {} }] }
        ]
        function dismiss(n) { list = list.filter(x => x !== n) }
        function clearAll() { list = [] }
        function invokeDefault(n) { return false }
        function iconSource(n) { return "" }
    }
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-notifs"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 60
        implicitWidth: Sizes.notifCenter.width; implicitHeight: Sizes.notifCenter.height
        exclusiveZone: 0
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            NotificationCenter { id: nc; anchors.fill: parent; host: fake }
        }
    }
    IpcHandler {
        target: "harness-notifs"
        function groupCount(): int { return nc.groupCount }
        function count(): int { return nc.count }
        function size(): string { return nc.size.width + "x" + nc.size.height }
        function dnd(): bool { return fake.dnd }
        function toggleDnd(): void { fake.dnd = !fake.dnd }
        function clearAll(): void { fake.clearAll() }
        function toggleGroup(app: string): void { nc.toggleGroup(app) }
    }
}

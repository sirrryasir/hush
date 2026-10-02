import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// The notification drawer controller (Ipc.drawer) plus one window per screen; only the
// window on the monitor focused at open time is shown.
Scope {
    id: root
    property bool open: false
    property string screenName: ""
    readonly property int unread: Notifs.unread

    function toggle() { open ? close() : show() }
    function show() {
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
        open = true
        markSeen()
    }
    function close() { open = false }
    function markSeen() { Notifs.markSeen() }

    Variants { model: Quickshell.screens; delegate: DrawerWindow { drawer: root } }
    Component.onCompleted: Ipc.drawer = root
}

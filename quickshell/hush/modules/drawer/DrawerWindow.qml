import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// One drawer surface: a flat card under the right corner. No blur (namespace hush-drawer).
PanelWindow {
    id: win
    required property ShellScreen modelData
    property var drawer: null
    screen: modelData
    readonly property bool shown: drawer !== null && drawer.open && drawer.screenName === modelData.name

    visible: shown || panel.opacity > 0
    anchors { top: true; right: true }
    margins { top: Theme.exclusiveTop + 8; right: 16 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 380
    implicitHeight: Math.min(Math.round(modelData.height * 0.6), header.height + Math.max(list.contentHeight, 64) + 20)
    color: "transparent"
    WlrLayershell.namespace: "hush-drawer"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Group by app: apps ordered by their newest notification, newest first within each.
    readonly property var entries: {
        const groups = [], byApp = {}
        for (const n of Notifs.list) {
            const app = n.appName || "Other"
            if (!byApp[app]) { byApp[app] = []; groups.push(app) }
            byApp[app].push(n)
        }
        const out = []
        for (const app of groups) {
            out.push({ header: true, app: app, n: null })
            for (const n of byApp[app]) out.push({ header: false, app: app, n: n })
        }
        return out
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (win.drawer) win.drawer.close()
    }

    Rectangle {
        id: panel
        width: parent.width; height: parent.height
        radius: 20
        color: Colors.surface_container
        border.width: 1; border.color: Colors.outline_variant
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: win.shown ? 0 : -12
            Behavior on y { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        }
        focus: win.shown
        Keys.onEscapePressed: if (win.drawer) win.drawer.close()

        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 48
            Text {
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                text: "Notifications"; color: Colors.on_surface
                font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Row {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 6
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: Notifs.dnd ? Colors.primary_container : (dndArea.containsMouse ? Colors.surface_container_high : "transparent")
                    Text {
                        anchors.centerIn: parent
                        text: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                        color: Notifs.dnd ? Colors.on_primary_container : Colors.on_surface_variant
                        font.family: Theme.fontIcon; font.pixelSize: 18
                    }
                    MouseArea { id: dndArea; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.dnd = !Notifs.dnd }
                }
                Rectangle {
                    width: clearText.implicitWidth + 20; height: 30; radius: 15
                    color: clearArea.containsMouse ? Colors.surface_container_high : "transparent"
                    Text {
                        id: clearText
                        anchors.centerIn: parent; text: "Clear all"
                        color: Notifs.count ? Colors.primary : Colors.on_surface_variant
                        font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.clearAll() }
                }
            }
        }

        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
            anchors { leftMargin: 10; rightMargin: 10; bottomMargin: 10 }
            clip: true; spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: win.entries
            delegate: Loader {
                required property var modelData
                width: ListView.view.width
                sourceComponent: modelData.header ? headerComp : cardComp
                Component {
                    id: headerComp
                    Text {
                        leftPadding: 8; topPadding: 6
                        text: modelData.app; color: Colors.on_surface_variant
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                    }
                }
                Component { id: cardComp; NotifCard { notif: modelData.n } }
            }
        }
        Text {
            anchors.centerIn: list
            visible: Notifs.count === 0
            text: Notifs.dnd ? "Do not disturb is on" : "No notifications"
            color: Colors.on_surface_variant
            font.family: Theme.fontUi; font.pixelSize: 13
        }
    }
}

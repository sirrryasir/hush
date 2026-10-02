//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
import QtQuick
import Quickshell
import qs.config
import qs.services
import "modules/island"

// One island surface per screen; every panel and modal (control center, notifications, launcher,
// wallpapers, settings) grows out of it, so hush maps no other layer.
ShellRoot {
    id: root
    Component.onCompleted: { void Ipc.island; void Notifs.count; console.log("hush shell up, mode=" + Colors.mode) }
    Variants { model: Quickshell.screens; delegate: IslandWindow {} }
}

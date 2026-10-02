//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
import QtQuick
import Quickshell
import qs.config
import qs.services
import "modules/wallpapers"
import "modules/island"
import "modules/corners"
import "modules/launcher"
import "modules/drawer"

ShellRoot {
    id: root
    Component.onCompleted: { void Ipc.island; console.log("hush shell up, mode=" + Colors.mode) }
    Variants { model: Quickshell.screens; delegate: IslandWindow {} }
    Corners {}
    Drawer {}
    LauncherWindow {}
    WallpapersWindow {}
    // SLOT wallpapers
}

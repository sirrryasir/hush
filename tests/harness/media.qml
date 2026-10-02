import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import "modules/island/surfaces"

// Harness: the media surface alone, at its declared size, on the focused screen. config/, services/
// and modules/ are symlinks to quickshell/hush so the qs.* imports resolve. Run: qs -p tests/harness/media.qml
ShellRoot {
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "hush-harness-media"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true; anchors.left: true
        margins.top: 80; margins.left: 80
        implicitWidth: Sizes.mediaSurface.width; implicitHeight: Sizes.mediaSurface.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        Media { anchors.fill: parent }
    }
}

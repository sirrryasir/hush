import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.services as Svc
import "modules/island/states"

// Harness: the hover face alone on a black pill. IPC target "hover": kbdShown, kbdText, kbdTap
// (clicks the layout chip). Run with HUSH_ROOT set; a fake hyprctl on PATH feeds the layout chip.
ShellRoot {
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-hover"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 320; implicitHeight: 44
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: 22
            HoverFace {
                id: face
                island: QtObject {
                    property color fg: "#ffffff"
                    property string screenName: ""
                    function click(b) {}
                    function openSurface(n) {}
                }
            }
        }
    }
    function chip(): var {
        const find = it => { for (const c of it.children) { if (c.objectName === "hoverChip_keyboard") return c; const r = find(c); if (r) return r } return null }
        return find(face)
    }
    IpcHandler {
        target: "hover"
        function kbdShown(): bool { const c = chip(); return !!c && c.visible }
        function kbdText(): string { const c = chip(); return c && c.item ? c.item.text : "" }
        function kbdTap(): void { chip().item.children[0].clicked(null) }
    }
}

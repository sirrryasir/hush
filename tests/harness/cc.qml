import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.services as Svc
import "modules/island/surfaces"

// Harness for the control-center surface: one top-anchored layer window with the surface on a black
// pill shape. Drive it with: qs -p tests/harness/cc.qml ipc call cc <fn>   (HUSH_ROOT must be set).
ShellRoot {
    id: root
    property int wallRequests: 0
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-cc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 560; implicitHeight: 320
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            ControlCenter { id: cc; anchors.fill: parent; onOpenWallpapers: root.wallRequests++ }
            // Stands in for the island's navigator (Left/Right on a focused slider = value steps,
            // Shift = ten; the live wiring is Island.navAdjust): the armed target gets stepAdjust.
            Item {
                id: keys; focus: true
                property var target: null
                property int adjusts: 0
                property int lastN: 0
                Keys.onPressed: event => {
                    if (!target || (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right)) return
                    const n = (event.key === Qt.Key_Right ? 1 : -1) * ((event.modifiers & Qt.ShiftModifier) ? 10 : 1)
                    target.stepAdjust(n); adjusts++; lastN = n; event.accepted = true
                }
            }
        }
    }
    IpcHandler {
        target: "cc"
        function page(): string { return cc.page }
        function openWifi(): void { cc.openWifi() }
        function openBluetooth(): void { cc.openBluetooth() }
        function back(): bool { return cc.back() }
        function networkCount(): int { return Svc.Net.networks.length }
        function scanning(): bool { return Svc.Net.scanning }
        function wallRequests(): int { return root.wallRequests }
        function pressWallpapers(): void { cc.openWallpapers() }
        // Bluetooth tile (test_cc_surface runs this harness with a stub rfkill and HUSH_BT_NO_ADAPTER=1).
        function pressBtTile(): void { const t = find(cc, "btToggle"); if (t) t.clicked() }
        function btBlocked(): bool { return Svc.Bt.blocked }
        function btSubtitle(): string { const t = find(cc, "btToggle"); return t ? t.subtitle : "" }
        function find(it, name): var { if (!it) return null; if (it.objectName === name) return it; for (let i = 0; i < it.children.length; i++) { const r = find(it.children[i], name); if (r) return r } return null }
        function armSlider(): bool {
            const sl = find(cc, "volumeSlider"); if (!sl) return false
            const w = (it) => { if (typeof it.stepAdjust === "function") return it; for (let i = 0; i < it.children.length; i++) { const r = w(it.children[i]); if (r) return r } return null }
            keys.target = w(sl); keys.forceActiveFocus(); return keys.target !== null
        }
        function adjusts(): int { return keys.adjusts }
        function lastStep(): int { return keys.lastN }
        function volume(): string { return Svc.Audio.volume.toFixed(2) }
        function sliderValue(): string { const sl = find(cc, "volumeSlider"); return sl ? sl.value.toFixed(2) : "" }
    }
}

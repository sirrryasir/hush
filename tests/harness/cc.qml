import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking
import qs.config
import qs.services as Svc
import "modules/island/surfaces"

// Harness for the control-center surface: one top-anchored layer window with the surface on a black
// pill shape. Drive it with: qs -p tests/harness/cc.qml ipc call cc <fn>   (HUSH_ROOT must be set).
ShellRoot {
    id: root
    property int wallRequests: 0
    property int notifRequests: 0
    PanelWindow {
        id: win
        WlrLayershell.namespace: "hush-harness-cc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Sizes.expanded.width; implicitHeight: Sizes.expanded.height
        color: "transparent"
        Rectangle {
            anchors.fill: parent; color: "#000000"; radius: Sizes.radiusExpanded
            ControlCenter { id: cc; anchors.fill: parent; onOpenWallpapers: root.wallRequests++; onOpenNotifications: root.notifRequests++ }
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
        // Rows on a sub-page ("wifiPage" / "btPage") by SSID or device name.
        function rowFor(pageName, key): var {
            const pg = find(cc, pageName); if (!pg) return null
            const kids = pg.listView.contentItem.children
            for (let i = 0; i < kids.length; i++) { const m = kids[i].modelData; if (m && (m.ssid === key || m.name === key || m.id === key)) return kids[i] }
            return null
        }
        function rowCount(pageName: string): int { const pg = find(cc, pageName); return pg ? pg.listView.count : -1 }
        // Clicks the row itself (objName "") or the named control inside it; false when hidden or absent.
        function press(pageName: string, key: string, objName: string): bool {
            const r = rowFor(pageName, key); if (!r) return false
            if (objName === "") { if (pageName === "wifiPage") cc.wifiClicked(r.modelData); else Svc.Bt.toggleDevice(r.modelData.dev); return true }
            const b = find(r, objName); if (!b || !b.visible) return false
            b.clicked(); return true
        }
        function visibleIn(pageName: string, key: string, objName: string): bool { const r = rowFor(pageName, key); const b = r ? find(r, objName) : null; return !!b && b.visible }
        function textIn(pageName: string, key: string, objName: string): string { const r = rowFor(pageName, key); const b = r ? find(r, objName) : null; return b ? b.text : "" }
        function rowHeight(pageName: string, key: string): int { const r = rowFor(pageName, key); return r ? r.height : -1 }
        function typePassword(ssid: string, pw: string): bool { const r = rowFor("wifiPage", ssid); const f = r ? find(r, "wifiPassword") : null; if (!f) return false; f.text = pw; return true }
        function passwordFocused(ssid: string): bool { const r = rowFor("wifiPage", ssid); const f = r ? find(r, "wifiPassword") : null; return !!f && f.activeFocus }
        function askSsid(): string { return cc.askSsid }
        function wifiEnabled(): bool { return Networking.wifiEnabled }
        function hiddenSsid(): string { const r = rowFor("wifiPage", "hidden"); return r ? r.hiddenSsid : "" }
        function passwordEcho(key: string): int { const r = rowFor("wifiPage", key); const f = r ? find(r, "wifiPassword") : null; return f ? f.echoMode : -1 }
        function netError(): string { return Svc.Net.errorSsid + "|" + Svc.Net.lastError }
        function netConnecting(): string { return Svc.Net.connecting }
        function btLog(): string { return Svc.Bt.fakeLog.join(",") }
        function btDiscovering(): bool { return Svc.Bt.discovering }
        function btSubtitleLine(): string { const pg = find(cc, "btPage"); return pg ? pg.subtitle : "" }
        function notifSummaryVisible(): bool { const n = find(cc, "notifSummary"); return !!n && n.visible }
        function notifTitle(): string { const t = find(cc, "notifSummaryTitle"); return t ? t.text : "" }
        function pressOpenNotifs(): void { const b = find(cc, "notifOpen"); if (b) b.clicked() }
        function notifRequests(): int { return root.notifRequests }
        function mainContentBottom(): int {
            // Lowest visible child edge of the main page, in surface pixels (dead band check).
            let m = 0
            const walk = (it) => { for (let i = 0; i < it.children.length; i++) { const c = it.children[i]; if (!c.visible || c.height <= 0) continue; const p = c.mapToItem(cc, 0, c.height); if (p.y > m && c.width > 0) m = p.y } }
            walk(find(cc, "mainPage")); return Math.round(m)
        }
        function mediaShown(): bool { return Svc.Media.player !== null }
        function surfaceHeight(): int { return cc.height }
        function sliderValue(): string { const sl = find(cc, "volumeSlider"); return sl ? sl.value.toFixed(2) : "" }
    }
}

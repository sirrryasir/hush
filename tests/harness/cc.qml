import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.SystemTray
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
        implicitWidth: Sizes.expanded.width; implicitHeight: cc.size.height
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
        function openFocus(): void { cc.openFocus() }
        function focusText(name: string): string { const t = find(cc, name); return t ? t.text : "" }
        function pressFocus(name: string): bool { const b = find(cc, name); if (!b) return false; b.clicked(); return true }
        function focusPhase(): string { return Svc.Countdown.phase + "/" + Svc.Countdown.cycle }
        function openAudio(): void { cc.openAudio() }
        // Sound page: "kind:name" per row, the default sink's node.name, a row's level (moveLevel drags its slider).
        function audioRows(): string { const pg = find(cc, "audioPage"); return pg ? pg.model.map(m => m.kind + ":" + m.name).join(",") : "" }
        function sinkName(): string { return Svc.Audio.sink ? Svc.Audio.sink.name : "" }
        function nodeVolume(key: string): string { const r = rowFor("audioPage", key); return r && r.node.audio ? r.node.audio.volume.toFixed(2) : "" }
        function moveLevel(key: string, v: real): bool { const r = rowFor("audioPage", key); const s = r ? find(r, "audioLevel") : null; if (!s) return false; s.moved(v); return true }
        function rowActive(pageName: string, key: string): bool { const r = rowFor(pageName, key); return !!r && r.modelData.active === true }
        function openPower(): void { cc.openPower() }
        function powerChip(): string { const c = find(cc, "ccBattery"); const t = find(cc, "ccBatteryState"); return c && t ? c.saver + "|" + t.text + "|" + (t.color.toString() === Colors.islandFgVar.toString()) : "" }
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
            for (let i = 0; i < kids.length; i++) { const m = kids[i].modelData; if (m && (m.ssid === key || m.name === key || m.label === key || m.id === key)) return kids[i] }
            return null
        }
        function rowCount(pageName: string): int { const pg = find(cc, pageName); return pg ? pg.listView.count : -1 }
        // Clicks the row itself (objName "") or the named control inside it; false when hidden or absent.
        function press(pageName: string, key: string, objName: string): bool {
            const r = rowFor(pageName, key); if (!r) return false
            if (objName === "") {
                if (pageName === "wifiPage") cc.wifiClicked(r.modelData); else if (pageName === "btPage") Svc.Bt.toggleDevice(r.modelData.dev)
                else if (pageName === "powerPage") Svc.PowerProfile.set(r.modelData.label)
                else if (pageName === "audioPage") Svc.Audio.setSink(r.modelData.node)
                else find(cc, pageName).rowClicked(r.modelData)
                return true
            }
            const b = find(r, objName); if (!b || !b.visible) return false
            b.clicked(); return true
        }
        function visibleIn(pageName: string, key: string, objName: string): bool { const r = rowFor(pageName, key); const b = r ? find(r, objName) : null; return !!b && b.visible }
        function textIn(pageName: string, key: string, objName: string): string { const r = rowFor(pageName, key); const b = r ? find(r, objName) : null; return b ? b.text : "" }
        function rowHeight(pageName: string, key: string): int { const r = rowFor(pageName, key); return r ? r.height : -1 }
        function typePassword(ssid: string, pw: string): bool { const r = rowFor("wifiPage", ssid); const f = r ? find(r, "wifiPassword") : null; if (!f) return false; f.text = pw; return true }
        function passwordFocused(ssid: string): bool { const r = rowFor("wifiPage", ssid); const f = r ? find(r, "wifiPassword") : null; return !!f && f.activeFocus }
        function askSsid(): string { return cc.askSsid }
        // Grid tiles by Composer id (the Loader "ccTile_<id>"; absent when the tile hides).
        function enableAllTiles(): void { for (const id of Composer.tileIds) Composer.setEnabled("cc", id, true) }
        // "height|sliderTop|id:y:h,..." in surface coordinates for every tile in the grid.
        function tileGeom(): string {
            const out = []
            for (const id of Composer.tileIds) { const t = find(cc, "ccTile_" + id); if (t) out.push(id + ":" + Math.round(t.mapToItem(cc, 0, 0).y) + ":" + Math.round(t.height)) }
            const sl = find(cc, "volumeSlider")
            return Math.round(cc.size.height) + "|" + Math.round(sl.mapToItem(cc, 0, 0).y) + "|" + out.join(",")
        }
        // Only the given ids (in tileIds order) on, each with its size; "row:col:span,..." of the placed grid.
        function mixTiles(spec: string): string {
            const want = JSON.parse(spec)
            for (const id of Composer.tileIds) { Composer.setEnabled("cc", id, id in want); if (id in want) Composer.setSize(id, want[id]) }
            return find(cc, "ccGrid").placed.map(p => p.row + ":" + p.col + ":" + p.span).join(",")
        }
        function tileShown(id: string): bool { return find(cc, "ccTile_" + id) !== null }
        function tileSub(id: string): string { const t = find(cc, "ccTile_" + id); return t ? t.item.subtitle : "" }
        function tileChecked(id: string): bool { const t = find(cc, "ccTile_" + id); return !!t && t.item.checked }
        function pressTile(id: string): bool { const t = find(cc, "ccTile_" + id); if (!t) return false; t.item.clicked(); return true }
        function pressTileChevron(id: string): bool { const t = find(cc, "ccTile_" + id); if (!t) return false; t.item.chevronClicked(); return true }
        function netPoll(): void { Svc.Net.poll() }
        function enableTile(id: string): void { Composer.setEnabled("cc", id, true) }
        function vpnCount(): int { return Svc.Net.vpns.length }
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
        // Tray (test_cc_tray runs tests/fakesni.py): the header button, the page's rows, a row's tap or menu.
        function trayCount(): int { return SystemTray.items.values.length }
        function trayButtonVisible(): bool { const b = find(cc, "trayButton"); return !!b && b.visible }
        function openTray(): void { cc.page = "tray" }
        function trayTap(title: string, menu: bool): bool { const r = rowFor("trayPage", title); if (!r) return false; r.tap(menu); return true }
        function trayMenuOpen(): bool { return cc.trayMenu !== null }
        function sliderValue(): string { const sl = find(cc, "volumeSlider"); return sl ? sl.value.toFixed(2) : "" }
    }
}

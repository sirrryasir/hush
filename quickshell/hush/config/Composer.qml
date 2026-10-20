pragma Singleton
import QtQuick
import Quickshell

// The island's composition (settings key `layout`): what the rest pill shows beside the clock, the
// hover face's chips in order, and the control center's tiles (order, size) and sections. The
// renderers read the normalised lists here; the Settings Modules page edits them through the
// functions below, which write the whole list back with Settings.set (applies live, persists).
// Normalising: unknown ids are dropped, duplicates keep the first, known ids missing from a user's
// list are appended disabled (so an id added later still shows up in the editor), and an empty or
// malformed list falls back to the defaults.
Singleton {
    id: root
    readonly property var hoverIds: ["workspaces", "date", "media", "battery", "network", "bluetooth", "volume", "brightness", "timer", "shelf", "recording", "keyboard"]
    readonly property var tileIds: ["wifi", "bluetooth", "vpn", "airplane", "dnd", "nightlight", "caffeine", "timer", "focus", "recording", "screenshot", "lock", "theme", "wallpapers", "settings"]
    readonly property var sectionKeys: ["sliders", "media", "themeStrip", "power"]
    readonly property var labels: ({
        workspaces: "Workspaces", date: "Date", media: "Now playing", battery: "Battery", network: "Network",
        bluetooth: "Bluetooth", volume: "Volume", brightness: "Brightness", timer: "Timer", focus: "Focus", shelf: "Shelf", recording: "Recording", keyboard: "Keyboard layout",
        screenshot: "Screenshot", wifi: "Wi-Fi", vpn: "VPN", airplane: "Airplane mode", dnd: "Do not disturb", nightlight: "Night light", caffeine: "Stay awake", lock: "Lock", theme: "Theme",
        wallpapers: "Wallpapers", settings: "Settings",
        sliders: "Sliders", themeStrip: "Theme strip", power: "Power row"
    })
    readonly property var sectionLabels: ({ sliders: "Sliders", media: "Media", themeStrip: "Themes", power: "Power" })
    // Built-in fallbacks for a settings.default.json without a layout block.
    readonly property var builtinHover: ["workspaces", "date", "media", "bluetooth", "network", "battery", "keyboard"]
    readonly property var builtinTiles: ["wifi", "bluetooth", "dnd", "nightlight"]

    readonly property var defaults: Settings.defaults.layout || ({})
    readonly property var cfg: Settings.layout

    readonly property string restLeft: root.cfg.rest && root.cfg.rest.left === "none" ? "none" : "activity"
    readonly property string restRight: root.cfg.rest && root.cfg.rest.right === "none" ? "none" : "status"

    readonly property var defaultHover: root.norm(root.defaults.hover, root.hoverIds, root.builtinHover, false, null)
    readonly property var hover: root.norm(root.cfg.hover, root.hoverIds, root.builtinHover, false, root.defaultHover)
    readonly property var hoverShown: root.hover.filter(e => e.enabled).map(e => e.id)

    readonly property var ccCfg: root.cfg.cc || ({})
    readonly property var defaultTiles: root.norm((root.defaults.cc || {}).tiles, root.tileIds, root.builtinTiles, true, null)
    readonly property var tiles: root.norm(root.ccCfg.tiles, root.tileIds, root.builtinTiles, true, root.defaultTiles)
    readonly property var tilesShown: root.tiles.filter(e => e.enabled)
    function section(key) { return root.ccCfg[key] !== false }
    readonly property bool sliders: root.section("sliders")
    readonly property bool media: root.section("media")
    readonly property bool themeStrip: root.section("themeStrip")
    readonly property bool power: root.section("power")

    function label(id) { return root.labels[id] || id }
    // list (anything) -> [{id, enabled[, size]}] over `known`; `fallback` (normalised) when empty.
    function norm(list, known, builtin, sized, fallback) {
        const out = [], seen = {}
        if (Array.isArray(list)) for (const e of list) {
            const id = e && typeof e === "object" ? String(e.id) : String(e)
            if (known.indexOf(id) < 0 || seen[id]) continue
            seen[id] = true
            const o = { id: id, enabled: !(e && typeof e === "object" && e.enabled === false) }
            if (sized) o.size = e && e.size === "2x1" ? "2x1" : "1x1"
            out.push(o)
        }
        if (out.length === 0) {
            if (fallback) return fallback
            for (const id of builtin) { seen[id] = true; out.push(sized ? { id: id, enabled: true, size: "2x1" } : { id: id, enabled: true }) }
        }
        for (const id of known) if (!seen[id]) out.push(sized ? { id: id, enabled: false, size: "1x1" } : { id: id, enabled: false })
        return out
    }

    // --- editing (the Settings Modules page, IPC) ---
    function listOf(sectionName) { return sectionName === "hover" ? root.hover : root.tiles }
    function pathOf(sectionName) { return sectionName === "hover" ? "layout.hover" : "layout.cc.tiles" }
    function copy(sectionName) { return root.listOf(sectionName).map(e => Object.assign({}, e)) }
    function indexOf(sectionName, id) { return root.listOf(sectionName).findIndex(e => e.id === id) }
    // Moves `id` one place up (dir -1) or down (+1); false at either end.
    function move(sectionName, id, dir) {
        const l = root.copy(sectionName), i = l.findIndex(e => e.id === id), j = i + dir
        if (i < 0 || j < 0 || j >= l.length) return false
        const t = l[i]; l[i] = l[j]; l[j] = t
        Settings.set(root.pathOf(sectionName), l)
        return true
    }
    function setEnabled(sectionName, id, on) {
        const l = root.copy(sectionName), e = l.find(x => x.id === id)
        if (!e) return
        e.enabled = !!on
        Settings.set(root.pathOf(sectionName), l)
    }
    function setSize(id, size) {
        const l = root.copy("cc"), e = l.find(x => x.id === id)
        if (!e) return
        e.size = size === "2x1" ? "2x1" : "1x1"
        Settings.set("layout.cc.tiles", l)
    }
    function setRest(side, value) { Settings.set("layout.rest." + side, value) }
    function setSection(key, on) { if (root.sectionKeys.indexOf(key) >= 0) Settings.set("layout.cc." + key, !!on) }
    function reset() { Settings.unset("layout") }
}

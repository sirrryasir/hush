pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The Hush palette. Every Material key in ~/.config/hush/Colors.json becomes a color
// property here. `hush` writes state.json last, so a state.json change is the signal
// that Colors.json is complete; both files are watched and either triggers a reload.
Singleton {
    id: root
    readonly property string path: Quickshell.env("HOME") + "/.config/hush/Colors.json"
    property bool loaded: false
    property string mode: "dark"
    readonly property bool isDark: mode === "dark"
    property var base16: ({})
    // The same keys in their dark-scheme values; the island draws on black even in light themes.
    property var dark: ({})
    readonly property color darkOnSurface: dark.on_surface || on_surface
    readonly property color darkPrimary: dark.primary || primary
    readonly property color darkError: dark.error || error


    // Island roles: the dark-scheme value of each key (the island is black in every theme), falling back
    // to the live key until Colors.json carries a dark set. Plain properties so they cross-fade too.
    property color islandFg: dark.on_surface || on_surface
    property color islandFgVar: dark.on_surface_variant || on_surface_variant
    property color islandSurface: dark.surface_container || surface_container
    property color islandSurfaceHigh: dark.surface_container_high || surface_container_high
    property color islandSurfaceHighest: dark.surface_container_highest || surface_container_highest
    property color islandOutline: dark.outline || outline
    property color islandPrimary: dark.primary || primary
    property color islandOnPrimary: dark.on_primary || on_primary
    property color islandPrimaryContainer: dark.primary_container || primary_container
    property color islandOnPrimaryContainer: dark.on_primary_container || on_primary_container
    property color islandSecondaryContainer: dark.secondary_container || secondary_container
    property color islandOnSecondaryContainer: dark.on_secondary_container || on_secondary_container
    property color islandError: dark.error || error
    property color islandErrorContainer: dark.error_container || error_container
    property color islandShadow: dark.shadow || shadow
    // The battery glyph keeps one muted green in every theme (9.7:1 on the black pill) and a white bolt.
    readonly property color islandBatteryGood: "#4cc38a"
    readonly property color islandBatteryBolt: "#ffffff"

    // Defaults are the harbor palette so the shell renders before Colors.json exists.
    property color primary: "#9cd1c1"
    property color on_primary: "#00382d"
    property color primary_container: "#7fb3a3"
    property color on_primary_container: "#00231b"
    property color secondary: "#b6cbc3"
    property color on_secondary: "#22342e"
    property color secondary_container: "#384b44"
    property color on_secondary_container: "#cfe5dc"
    property color tertiary: "#fab6aa"
    property color on_tertiary: "#4e241d"
    property color tertiary_container: "#d9998e"
    property color on_tertiary_container: "#38120c"
    property color error: "#ffb4ab"
    property color on_error: "#690005"
    property color error_container: "#93000a"
    property color on_error_container: "#ffdad6"
    property color background: "#111413"
    property color on_background: "#e1e3e0"
    property color surface: "#111413"
    property color surface_dim: "#111413"
    property color surface_bright: "#373a38"
    property color surface_container_lowest: "#0c0f0e"
    property color surface_container_low: "#191c1b"
    property color surface_container: "#1d201f"
    property color surface_container_high: "#282b29"
    property color surface_container_highest: "#333534"
    property color surface_variant: "#404945"
    property color surface_tint: "#9cd1c1"
    property color on_surface: "#e1e3e0"
    property color on_surface_variant: "#c0c9c4"
    property color inverse_surface: "#e1e3e0"
    property color inverse_on_surface: "#2e3130"
    property color inverse_primary: "#35675a"
    property color outline: "#8a938f"
    property color outline_variant: "#404945"
    property color shadow: "#000000"
    property color scrim: "#000000"
    property color source_color: "#7fb3a3"
    property color primary_fixed: "#b8eedc"
    property color primary_fixed_dim: "#9cd1c1"
    property color on_primary_fixed: "#002019"
    property color on_primary_fixed_variant: "#1a4f43"
    property color secondary_fixed: "#d2e7df"
    property color secondary_fixed_dim: "#b6cbc3"
    property color on_secondary_fixed: "#0c1f1a"
    property color on_secondary_fixed_variant: "#384b44"
    property color tertiary_fixed: "#ffdad4"
    property color tertiary_fixed_dim: "#fab6aa"
    property color on_tertiary_fixed: "#34100a"
    property color on_tertiary_fixed_variant: "#693a32"

    // Cross-fade: each role eases to its new value when a theme change rewrites Colors.json. Off for
    // the first load (defaults -> real palette) so the shell never fades in from harbor at startup.
    property bool fade: false
    readonly property int fadeMs: Math.round(400 * (Settings.island.reducedMotion ? (Settings.motion.reducedScale || 0.4) : 1))
    Behavior on primary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_primary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on primary_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_primary_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on secondary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_secondary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on secondary_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_secondary_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on tertiary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_tertiary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on tertiary_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_tertiary_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on error { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_error { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on error_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_error_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on background { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_background { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_dim { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_bright { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_container_lowest { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_container_low { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_container { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_container_high { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_container_highest { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_variant { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on surface_tint { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_surface { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_surface_variant { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on inverse_surface { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on inverse_on_surface { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on inverse_primary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on outline { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on outline_variant { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on shadow { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on scrim { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on source_color { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on primary_fixed { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on primary_fixed_dim { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_primary_fixed { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_primary_fixed_variant { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on secondary_fixed { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on secondary_fixed_dim { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_secondary_fixed { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_secondary_fixed_variant { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on tertiary_fixed { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on tertiary_fixed_dim { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_tertiary_fixed { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on on_tertiary_fixed_variant { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandFg { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandFgVar { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandSurface { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandSurfaceHigh { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandSurfaceHighest { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandOutline { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandPrimary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandOnPrimary { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandPrimaryContainer { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandOnPrimaryContainer { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandSecondaryContainer { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandOnSecondaryContainer { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandError { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandErrorContainer { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }
    Behavior on islandShadow { enabled: root.fade; ColorAnimation { duration: root.fadeMs } }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function apply(obj) {
        root.fade = root.loaded
        for (const k in obj) {
            if (k === "base16") { root.base16 = obj[k]; continue }
            if (k === "dark") { root.dark = obj[k]; continue }
            if (k === "mode") { root.mode = obj[k]; continue }
            if (root.hasOwnProperty(k)) root[k] = obj[k]
        }
        root.loaded = true
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onLoaded: {
            try { root.apply(JSON.parse(file.text())) }
            catch (e) { console.warn("Colors.json parse failed: " + e) }
        }
    }
    // hush replaces files with a rename; reload after a short debounce so a burst of events
    // (Colors.json then state.json) costs one parse.
    Timer { id: reloadTimer; interval: 100; onTriggered: file.reload() }
    // Primary trigger: state.json is written after Colors.json is final.
    FileView {
        path: Quickshell.env("HOME") + "/.config/hush/state.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
    }
}

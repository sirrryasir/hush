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

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function apply(obj) {
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

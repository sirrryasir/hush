pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Mic / camera in use: a PipeWire node of class Stream/Input/Audio (mic) or Stream/Input/Video (camera)
// that is running, i.e. linked to a source in the graph (Quickshell exposes no node state, so an
// unlinked, idle or corked stream does not count).
Singleton {
    id: root
    readonly property var nodes: Pipewire.nodes.values
    readonly property var groups: Pipewire.linkGroups.values
    PwObjectTracker { objects: root.nodes }

    function linked(n) {
        for (let i = 0; i < root.groups.length; i++) {
            const g = root.groups[i]
            if (g && (g.source === n || g.target === n)) return true
        }
        return false
    }
    function inUse(cls) {
        for (let i = 0; i < root.nodes.length; i++) {
            const n = root.nodes[i]
            if (n && n.ready && n.properties && n.properties["media.class"] === cls && linked(n)) return true
        }
        return false
    }
    readonly property bool micInUse: inUse("Stream/Input/Audio")
    readonly property bool cameraInUse: inUse("Stream/Input/Video")
}

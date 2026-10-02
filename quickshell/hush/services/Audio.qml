pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink/source state. changed(kind) fires for real changes only, never during the
// first 2 s after startup (pipewire settling would otherwise pop an OSD on launch).
Singleton {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    signal changed(string kind)
    property bool ready: false

    function setVolume(v) { if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, v)) }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    Timer { interval: 2000; running: true; onTriggered: root.ready = true }
    onVolumeChanged: if (ready) changed("volume")
    onMutedChanged: if (ready) changed("volume")
    onMicMutedChanged: if (ready) changed("mic")
}

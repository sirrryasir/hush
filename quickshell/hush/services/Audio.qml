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
    // A default-device switch (a Bluetooth headset connecting or dropping) swaps the node: its
    // volume reads 0 until bound, then jumps to the device's level. That is not a user change,
    // so the OSD stays quiet until the new node is bound and has settled.
    readonly property bool sinkLive: ready && !!sink && sink.ready && !sinkSettle.running
    readonly property bool sourceLive: ready && !!source && source.ready && !sourceSettle.running
    Timer { id: sinkSettle; interval: 500 }
    Timer { id: sourceSettle; interval: 500 }
    onSinkChanged: sinkSettle.restart()
    onSourceChanged: sourceSettle.restart()
    Connections { target: root.sink; function onReadyChanged() { sinkSettle.restart() } }
    Connections { target: root.source; function onReadyChanged() { sourceSettle.restart() } }
    onVolumeChanged: if (sinkLive) changed("volume")
    onMutedChanged: if (sinkLive) changed("volume")
    onMicMutedChanged: if (sourceLive) changed("mic")
}

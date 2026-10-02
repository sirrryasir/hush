pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The player the island should show: first playing, else first controllable, else null.
Singleton {
    id: root
    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => p.isPlaying) ?? ps.find(p => p.canControl) ?? null
    }
    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist ?? "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl ?? "") : ""
    readonly property bool playing: player ? player.isPlaying : false
    readonly property real length: player && player.lengthSupported ? Math.max(0, player.length) : 0
    property real position: 0

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (player && player.canGoNext) player.next() }
    function previous() { if (player && player.canGoPrevious) player.previous() }

    function sync() { position = player && player.positionSupported ? player.position : 0 }
    onPlayerChanged: sync()
    onPlayingChanged: sync()

    Timer {
        interval: 1000; repeat: true; running: root.playing
        onTriggered: { if (root.player) root.player.positionChanged(); root.sync() }
    }
}

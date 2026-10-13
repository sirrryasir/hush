import QtQuick
import qs.config
import qs.services as Svc

// Raises a short "now playing" card through the arbiter when the track changes while playing (or playback
// starts on a new track): a transient at OSD priority, held Theme.osdHoldMs (1.1 s), keyed by track
// so a burst of metadata updates coalesces. Settings.island.nowPlayingOsd false turns it off.
Item {
    id: reg
    property var island: null
    readonly property bool enabled: Settings.island.nowPlayingOsd !== false && Settings.modules.media !== false
    readonly property string track: Svc.Media.title + "\u0001" + Svc.Media.artist
    // The last track announced; the first one seen at start-up is never announced.
    property string announced: ""
    property bool primed: false

    Component { id: mediaComp; MediaState { island: reg.island } }
    onIslandChanged: if (island) island.register("media", mediaComp)

    function check() {
        if (!primed) { primed = true; announced = Svc.Media.playing ? track : ""; return }
        // The player went away: the same track starting again is news.
        if (!Svc.Media.player) { announced = ""; return }
        if (!Svc.Media.playing || Svc.Media.title === "" || track === announced) return
        announced = track
        if (!enabled || !island || island !== Svc.Ipc.island) return
        island.arbiter.raise("media", { key: "media" })
    }
    // Title, artist and status arrive as separate D-Bus updates: settle before deciding.
    Timer { id: settle; interval: 150; onTriggered: reg.check() }
    Connections {
        target: Svc.Media
        function onTitleChanged() { settle.restart() }
        function onArtistChanged() { settle.restart() }
        function onPlayingChanged() { settle.restart() }
    }
    Component.onCompleted: settle.restart()
}

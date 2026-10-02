import QtQuick
import qs.services as Svc

// Registers the media state on the island and drives it from the Media singleton.
Item {
    id: reg
    property var island: null
    property bool active: false

    Component { id: mediaComp; MediaState { island: reg.island } }

    function refreshText() { if (island && active) island.restCenterText = Svc.Media.title || island.restCenterText }
    function engage() {
        releaseTimer.stop()
        if (!island || !Svc.Media.player || !Svc.Media.playing) return
        active = true
        island.request("media", 1, 0)
        island.restCenterText = Svc.Media.title
    }
    function disengage() {
        releaseTimer.stop()
        if (!active || !island) return
        active = false
        island.release("media")
        island.restCenterText = Qt.formatDate(new Date(), "ddd d MMM")
    }

    onIslandChanged: if (island) { island.register("media", mediaComp); engage() }

    Connections {
        target: Svc.Media
        function onPlayingChanged() { Svc.Media.playing ? reg.engage() : (Svc.Media.player ? releaseTimer.restart() : reg.disengage()) }
        function onPlayerChanged() { Svc.Media.player ? (Svc.Media.playing ? reg.engage() : null) : reg.disengage() }
        function onTitleChanged() { reg.refreshText() }
    }
    Timer { id: releaseTimer; interval: 3000; onTriggered: reg.disengage() }
}

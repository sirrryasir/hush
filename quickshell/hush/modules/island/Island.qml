import QtQuick
import QtQuick as QQ
import Quickshell
import qs.config
import qs.config as Cfg
import qs.services as Svc
import "states"
import "surfaces" as Surf

// The island body and its state machine. Bare `State` is QtQuick's type, so the hush
// State singleton is reached as Cfg.State.
// `state` is Item's own state property; the names below are declared in `states` so
// assigning any of them is valid. Its built-in stateChanged() notifier is the state-change
// signal (handlers read `island.state`); a second stateChanged(string) cannot coexist with it.
Item {
    id: islandRoot
    state: "rest"
    states: [
        QQ.State { name: "rest" }, QQ.State { name: "hover" }, QQ.State { name: "media" },
        QQ.State { name: "notification" }, QQ.State { name: "osd" }, QQ.State { name: "expanded" },
        QQ.State { name: "mediaSurface" }, QQ.State { name: "calendar" }, QQ.State { name: "notifCenter" }
    ]
    // Surfaces that grow out of the pill (design 2.6); "expanded" is the control center.
    readonly property var surfaces: ["expanded", "mediaSurface", "calendar", "notifCenter"]
    readonly property bool surfaceOpen: surfaces.indexOf(state) >= 0
    property var stateContent: ({})
    property var active: ({ name: "rest", priority: 0 })
    property var queue: []
    property string restCenterText: Qt.formatDate(dateSrc.date, "ddd d MMM")
    // The clock text the rest state shows (tests read it over IPC).
    property string restClock: ""
    property real restWidth: 0
    // The monitor this island lives on (the hover face shows that monitor's workspaces).
    property string screenName: ""
    readonly property color fg: Colors.darkOnSurface
    // Set by IslandWindow while the pill is retracted (fullscreen, auto-hide); IPC reports "hidden".
    property bool hidden: false
    // The shown state's v2 priority (config/Priorities), until the Arbiter drives the island.
    readonly property int priority: surfaceOpen ? Priorities.expanded
        : (({ rest: Priorities.rest, hover: Priorities.hover, media: Priorities.activity, osd: Priorities.osd,
            notification: Priorities.notification })[state] || 0)
    readonly property bool pointerInside: hover.hovered
    readonly property bool armed: surface.armed

    width: body.width; height: body.height
    readonly property real bodyWidth: body.width
    readonly property real bodyHeight: body.height
    // Staging introspection for tests: the state whose shape the pill takes, and whose content shows.
    readonly property string shapeState: surface.shape
    readonly property string shownState: surface.shown
    readonly property real contentOpacity: surface.contentOpacity
    readonly property var item: surface.item

    // A fresh object each time: reassigning the same object does not notify bindings. The new
    // object re-evaluates the Loader's sourceComponent binding, so no explicit reload is needed.
    function register(name, component) { const m = Object.assign({}, stateContent); m[name] = component; stateContent = m }
    // priority: surface 4 > notification 3 > osd 2 > hover 1.5 > media 1 > rest 0. holdMs 0 holds until
    // release(). A request for the active name replaces its priority and hold. A higher request
    // preempts the active state, which is dropped, except media, which waits in the queue (the hover
    // face or a surface over a playing track hands the capsule back). No content: ignored.
    function request(name, priority, holdMs) {
        if (!stateContent[name]) { console.warn("hush island: no content for state " + name); return }
        if (priority >= active.priority || active.name === name) {
            if (active.name === "media" && name !== "media") enqueue("media", active.priority, 0)
            setActive(name, priority, holdMs)
        } else enqueue(name, priority, holdMs)
    }
    function enqueue(name, priority, holdMs) {
        const q = queue.filter(e => e.name !== name)
        q.push({ name: name, priority: priority, holdMs: holdMs })
        q.sort((a, b) => b.priority - a.priority)
        queue = q
    }
    function release(name) {
        if (active.name !== name) { queue = queue.filter(q => q.name !== name); return }
        holdTimer.stop()
        if (queue.length) { const q = queue.slice(); const n = q.shift(); queue = q; setActive(n.name, n.priority, n.holdMs) }
        else setActive("rest", 0, 0)
    }
    function setActive(name, priority, holdMs) {
        active = { name: name, priority: priority }; state = name
        holdTimer.stop(); if (holdMs > 0) { holdTimer.interval = holdMs; holdTimer.start() }
    }

    // --- surfaces ---
    function openSurface(name) { if (surfaces.indexOf(name) >= 0) request(name, 4, 0) }
    function closeSurface() { if (surfaceOpen) release(state) }
    function toggleSurface(name) { state === name ? closeSurface() : openSurface(name) }
    // Super+Backspace and IPC: open the control center, or close whatever surface is open.
    function toggleExpanded() { surfaceOpen ? closeSurface() : openSurface("expanded") }
    // Click mapping (design 2.2, Settings.island.click*): cc | notifs | media | calendar | launcher | none.
    function act(action) {
        const mods = Settings.modules
        switch (action) {
        case "cc": toggleSurface("expanded"); break
        case "notifs":
            if (mods.notifications !== false) toggleSurface("notifCenter")
            else if (Svc.Ipc.drawer) Svc.Ipc.drawer.toggle()
            break
        case "media": if (mods.media !== false) toggleSurface("mediaSurface"); break
        case "calendar": if (mods.calendar !== false) toggleSurface("calendar"); break
        case "launcher": if (Svc.Ipc.launcher) Svc.Ipc.launcher.toggle(); break
        }
    }
    function click(button) {
        const isl = Settings.island
        act(button === Qt.RightButton ? (isl.clickRight || "notifs")
            : button === Qt.MiddleButton ? (isl.clickMiddle || "media") : (isl.clickLeft || "cc"))
    }
    function scroll(dy) {
        if (surfaceOpen || dy === 0 || (Settings.island.scroll || "volume") !== "volume") return false
        Svc.Audio.setVolume(Svc.Audio.volume + (dy > 0 ? 0.05 : -0.05))
        return true
    }
    function showOsd(kind) { if (stateContent["osd"] && surface.item && surface.item.show) surface.item.show(kind) }

    // --- hover (design 2.2) ---
    // Dwell before the face opens, grace before it closes. A glance never starts while the pill is
    // still shrinking (it waits for the spring); when a transient (OSD, notification) ends with the
    // pointer still inside, the face re-arms at once, without dwell or re-entry.
    readonly property bool hoverAllowed: Settings.island.hoverFace !== false
    property bool hoverPending: false
    property string lastState: "rest"
    // The last few state changes and pointer crossings as [name, ms] (tests time the hover rules).
    property var history: []
    function mark(name) { const h = history.slice(-15); h.push([name, Date.now()]); history = h }
    function hoverChanged() {
        mark(hover.hovered ? "@in" : "@out")
        if (hover.hovered) { grace.stop(); if (state !== "hover") armHover() }
        else { dwell.stop(); hoverPending = false; if (state === "hover") grace.restart() }
    }
    function armHover() { if (hoverAllowed && (state === "rest" || state === "media")) dwell.restart() }
    function tryHover() {
        if (!hover.hovered || !hoverAllowed || !(state === "rest" || state === "media")) return
        if (body.shrinking()) { hoverPending = true; shrinkPoll.restart(); return }
        request("hover", 1.5, 0)
    }
    Timer { id: dwell; interval: Settings.motion.hoverDwellMs || 120; onTriggered: islandRoot.tryHover() }
    Timer { id: grace; interval: Settings.motion.leaveGraceMs || 300; onTriggered: if (!hover.hovered) islandRoot.release("hover") }
    Timer { id: shrinkPoll; interval: 16; repeat: true; onTriggered: if (!islandRoot.hoverPending || !body.shrinking()) { stop(); if (islandRoot.hoverPending) { islandRoot.hoverPending = false; islandRoot.tryHover() } } }
    HoverHandler { id: hover; onHoveredChanged: islandRoot.hoverChanged() }

    onStateChanged: {
        const was = lastState; lastState = state
        mark(state)
        if (surfaceOpen) forceActiveFocus()
        if (state === "notifCenter") Svc.Notifs.markSeen()
        // Deferred: a state assignment inside a state change is refused by the StateGroup.
        if (hover.hovered && hoverAllowed && (state === "rest" || state === "media")) {
            if (was === "osd" || was === "notification") Qt.callLater(rearm)
            else armHover()
        }
    }
    function rearm() { if (hover.hovered && hoverAllowed && (state === "rest" || state === "media")) request("hover", 1.5, 0) }

    Timer { id: holdTimer; onTriggered: islandRoot.release(islandRoot.active.name) }
    SystemClock { id: dateSrc; precision: SystemClock.Hours }

    // The shape springs to the staged surface's size; the content cross-fades inside it.
    Pill {
        id: body
        target: surface.shapeSize
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => islandRoot.click(mouse.button)
            onWheel: wheel => { wheel.accepted = islandRoot.scroll(wheel.angleDelta.y) }
        }
        SurfaceLoader {
            id: surface
            anchors.fill: parent
            target: islandRoot.state
            components: islandRoot.stateContent
            armStates: islandRoot.surfaces
            onItemLoaded: item => { if (item && ("island" in item)) item.island = islandRoot }
            // The slow spring for any morph into or out of a panel, the quick one between capsules
            // (the 44 px hover face counts as a capsule).
            property string lastShape: "rest"
            onShapeChanged: {
                body.calm = Sizes.of(shape).height > Sizes.hover.height || Sizes.of(lastShape).height > Sizes.hover.height
                lastShape = shape
            }
        }
    }
    // Esc steps out of a sub-page first (the control center's Wi-Fi/Bluetooth pages), then closes.
    Keys.onEscapePressed: {
        if (!surfaceOpen) return
        if (surface.item && surface.item.back && surface.item.back()) return
        closeSurface()
    }
    Component.onCompleted: {
        register("rest", restComp); register("hover", hoverComp); register("expanded", ccComp)
        register("mediaSurface", mediaSurfaceComp); register("calendar", calendarComp); register("notifCenter", notifCenterComp)
    }
    Component { id: restComp; Rest { island: islandRoot } }
    Component { id: hoverComp; HoverFace { island: islandRoot } }
    OsdRegistrar { island: islandRoot }
    Loader { source: "states/MediaRegistrar.qml"; onLoaded: item.island = islandRoot }
    NotificationRegistrar { island: islandRoot }
    Component {
        id: ccComp
        Surf.ControlCenter {
            onCloseRequested: islandRoot.closeSurface()
            onOpenWallpapers: { islandRoot.closeSurface(); if (Svc.Ipc.wallpapers) Svc.Ipc.wallpapers.toggle() }
        }
    }
    Component { id: mediaSurfaceComp; Surf.Media {} }
    Component { id: calendarComp; Surf.Calendar {} }
    Component { id: notifCenterComp; Surf.NotificationCenter { host: Svc.Notifs } }
}

import QtQuick
import QtQuick as QQ
import Quickshell
import qs.config
import qs.config as Cfg
import "states"

// The island body and its state machine. Bare `State` is QtQuick's type, so the hush
// State singleton is reached as Cfg.State.
// `state` is Item's own state property; the five names below are declared in `states` so
// assigning any of them is valid. Its built-in stateChanged() notifier is the state-change
// signal (handlers read `island.state`); a second stateChanged(string) cannot coexist with it.
Item {
    id: islandRoot
    state: "rest"
    states: [
        QQ.State { name: "rest" }, QQ.State { name: "media" }, QQ.State { name: "notification" },
        QQ.State { name: "osd" }, QQ.State { name: "expanded" }
    ]
    property var stateContent: ({})
    property var active: ({ name: "rest", priority: 0 })
    property var queue: []
    property string restCenterText: Qt.formatDate(dateSrc.date, "ddd d MMM")
    // The clock text the rest state shows (tests read it over IPC).
    property string restClock: ""
    property real restWidth: 0
    readonly property color fg: Colors.darkOnSurface
    // Set by IslandWindow while the pill is retracted (fullscreen, auto-hide); IPC reports "hidden".
    property bool hidden: false
    // The shown state's v2 priority (config/Priorities), until the Arbiter drives the island.
    readonly property int priority: ({ rest: Priorities.rest, media: Priorities.activity, osd: Priorities.osd,
        notification: Priorities.notification, expanded: Priorities.expanded })[state] || 0

    width: body.width; height: body.height
    readonly property real bodyWidth: body.width
    readonly property real bodyHeight: body.height
    // Staging introspection for tests: the state whose shape the pill takes, and whose content shows.
    readonly property string shapeState: surface.shape
    readonly property string shownState: surface.shown
    readonly property real contentOpacity: surface.contentOpacity

    // A fresh object each time: reassigning the same object does not notify bindings. The new
    // object re-evaluates the Loader's sourceComponent binding, so no explicit reload is needed.
    function register(name, component) { const m = Object.assign({}, stateContent); m[name] = component; stateContent = m }
    // priority: expanded 4 > notification 3 > osd 2 > media 1 > rest 0. holdMs 0 holds until release().
    // A request for the active name replaces its priority and hold. A higher request preempts the
    // active state, which is dropped, not re-queued. A state with no registered content is ignored.
    function request(name, priority, holdMs) {
        if (!stateContent[name]) { console.warn("hush island: no content for state " + name); return }
        if (priority >= active.priority || active.name === name) { setActive(name, priority, holdMs) }
        else {
            const q = queue.filter(e => e.name !== name)
            q.push({ name: name, priority: priority, holdMs: holdMs })
            q.sort((a, b) => b.priority - a.priority)
            queue = q
        }
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
    function toggleExpanded() { state === "expanded" ? release("expanded") : request("expanded", 4, 0) }
    function showOsd(kind) { if (stateContent["osd"] && surface.item && surface.item.show) surface.item.show(kind) }

    onStateChanged: if (state === "expanded") forceActiveFocus()

    Timer { id: holdTimer; onTriggered: islandRoot.release(islandRoot.active.name) }
    Timer { id: hoverTimer; interval: Theme.hoverExpandMs; onTriggered: if (islandRoot.state === "rest") islandRoot.request("expanded", 4, 0) }
    SystemClock { id: dateSrc; precision: SystemClock.Hours }

    // The shape springs to the staged surface's size; the content cross-fades inside it.
    Pill {
        id: body
        target: surface.shapeSize
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onEntered: hoverTimer.start(); onExited: hoverTimer.stop()
            onClicked: { hoverTimer.stop(); islandRoot.toggleExpanded() }
        }
        SurfaceLoader {
            id: surface
            anchors.fill: parent
            target: islandRoot.state
            components: islandRoot.stateContent
            onItemLoaded: item => { if (item) item.island = islandRoot }
            // The slow spring for any morph into or out of a panel, the quick one between capsules.
            property string lastShape: "rest"
            onShapeChanged: {
                body.calm = Sizes.of(shape).height > 36 || Sizes.of(lastShape).height > 36
                lastShape = shape
            }
        }
    }
    Keys.onEscapePressed: if (state === "expanded") release("expanded")
    Component.onCompleted: { register("rest", restComp); register("expanded", expandedComp) }
    Component { id: restComp; Rest { island: islandRoot } }
    OsdRegistrar { island: islandRoot }
    Loader { source: "states/MediaRegistrar.qml"; onLoaded: item.island = islandRoot }
    NotificationRegistrar { island: islandRoot }
    Component { id: expandedComp; Expanded { island: islandRoot } }
}

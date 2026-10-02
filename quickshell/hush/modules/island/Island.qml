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
    readonly property color fg: Colors.darkOnSurface

    width: body.width; height: body.height
    readonly property real bodyWidth: body.width
    readonly property real bodyHeight: body.height

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
    function showOsd(kind) { if (stateContent["osd"] && stateLoader.item && stateLoader.item.show) stateLoader.item.show(kind) }

    onStateChanged: if (state === "expanded") forceActiveFocus()

    Timer { id: holdTimer; onTriggered: islandRoot.release(islandRoot.active.name) }
    Timer { id: hoverTimer; interval: Theme.hoverExpandMs; onTriggered: if (islandRoot.state === "rest") islandRoot.request("expanded", 4, 0) }
    SystemClock { id: dateSrc; precision: SystemClock.Hours }

    Rectangle {
        id: body
        readonly property size target: (stateLoader.item && stateLoader.item.size) ? stateLoader.item.size : Theme.islandRest
        width: target.width; height: target.height
        radius: height <= 36 ? height / 2 : Theme.radiusExpanded
        color: "#000000"
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        Behavior on width { SpringAnimation { spring: Theme.springStiffness; damping: Theme.springDamping; epsilon: 0.5 } }
        Behavior on height { SpringAnimation { spring: Theme.springStiffness; damping: Theme.springDamping; epsilon: 0.5 } }
        clip: true
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onEntered: hoverTimer.start(); onExited: hoverTimer.stop()
            onClicked: { hoverTimer.stop(); islandRoot.toggleExpanded() }
        }
        Loader {
            id: stateLoader
            anchors.fill: parent
            sourceComponent: islandRoot.stateContent[islandRoot.state] || islandRoot.stateContent["rest"] || null
            onLoaded: if (item) item.island = islandRoot
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

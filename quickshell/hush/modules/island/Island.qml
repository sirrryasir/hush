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
        QQ.State { name: "mediaSurface" }, QQ.State { name: "calendar" }, QQ.State { name: "notifCenter" },
        QQ.State { name: "launcher" }, QQ.State { name: "wallpapers" }, QQ.State { name: "settings" }
    ]
    // Surfaces that grow out of the pill (design 2.6); "expanded" is the control center. The last
    // three are modal: they take the keyboard and the whole island surface catches clicks.
    readonly property var panels: ["expanded", "mediaSurface", "calendar", "notifCenter"]
    readonly property var modals: ["launcher", "wallpapers", "settings"]
    readonly property var surfaces: panels.concat(modals)
    readonly property bool surfaceOpen: surfaces.indexOf(state) >= 0
    readonly property bool modalOpen: modals.indexOf(state) >= 0
    // The settings module a surface belongs to (Settings.modules.<name> false disables it).
    readonly property var moduleOf: ({ mediaSurface: "media", calendar: "calendar", notifCenter: "notifications",
        launcher: "launcher", wallpapers: "wallpapers", settings: "settings" })
    property var stateContent: ({})
    // The clock text the rest state shows (tests read it over IPC).
    property string restClock: ""
    property real restWidth: 0
    // The monitor this island lives on (the hover face shows that monitor's workspaces).
    property string screenName: ""
    // The screen's top-left in global pixels (the wallpaper grid's --from origin).
    property point screenOrigin: Qt.point(0, 0)
    readonly property color fg: Colors.darkOnSurface
    // Set by IslandWindow while the pill is retracted (fullscreen, auto-hide); IPC reports "hidden".
    property bool hidden: false
    // Retract/reveal crossings are stamped too (tests time the reveal strip from them).
    onHiddenChanged: mark(hidden ? "@hidden" : "@shown")
    // Set by IslandWindow while the retracted island's OSD shows on the fullscreen OSD overlay.
    property bool overlayOsd: false
    // Launcher mode for the next open ("apps", "windows", "calc", "clip").
    property string launcherMode: "apps"

    // The single source of truth for what the pill shows (design 2.3). The island state mirrors
    // arbiter.current (a critical notification shows as "notification"); nothing assigns `state`
    // except syncState().
    readonly property Arbiter arbiter: Arbiter {
        pointerInside: hover.hovered
        // Deferred one turn, so a hand-over (surface lowered, queued notification promoted) is a
        // single state change, not a flash of rest in between.
        onCurrentChanged: Qt.callLater(islandRoot.syncState)
        onHoverArm: Qt.callLater(islandRoot.rearm)
        Component.onCompleted: {
            for (const n of islandRoot.panels) declare(n, Priorities.expanded, {})
            for (const n of islandRoot.modals) declare(n, Priorities.modal, {})
            declare("critical", Priorities.critical, { sticky: true })
            declare("notification", Priorities.notification, { holdMs: Theme.notificationHoldMs })
            declare("osd", Priorities.osd, { holdMs: Theme.osdHoldMs, coalesce: true })
            declare("hover", Priorities.hover, {})
            // "media" is the 1.1 s now-playing card on a track change (media at rest is the
            // activity circle inside the rest state, not a state of its own).
            declare("media", Priorities.osd, { holdMs: Theme.osdHoldMs, coalesce: true })
        }
    }
    readonly property var payload: arbiter.payload
    readonly property int priority: arbiter.currentPriority
    // A notification card under the pointer keeps its hold (sticky critical ones never time out).
    readonly property bool holdPaused: hover.hovered && state === "notification"
    onHoldPausedChanged: arbiter.pause(holdPaused)

    function stateFor(name) { return name === "critical" ? "notification" : (name || "rest") }
    // A state assignment inside a state change is refused by the StateGroup, so a change that lands
    // while one is being handled is deferred to the next turn of the event loop.
    property bool inStateChange: false
    function syncState() {
        const s = stateFor(arbiter.current)
        if (state === s) return
        if (inStateChange) { Qt.callLater(syncState); return }
        state = s
    }
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

    // --- surfaces ---
    // Opening a surface closes any other one and the hover face; transients raised meanwhile wait
    // in the arbiter's queue and play once the surface closes.
    function openSurface(name, opts) {
        if (surfaces.indexOf(name) < 0) return
        const m = moduleOf[name]
        if (m && Settings.modules[m] === false) return
        if (name === "launcher") launcherMode = opts && opts.mode ? opts.mode : "apps"
        // The notification center shows every toast; none should pop again after it closes.
        if (name === "notifCenter") Svc.Notifs.seenAll()
        for (const n of surfaces) if (n !== name) arbiter.lower(n)
        arbiter.lower("hover")
        arbiter.raise(name, opts || {})
    }
    // What the arbiter shows now (state follows it a turn later).
    readonly property bool surfaceCurrent: surfaces.indexOf(arbiter.current) >= 0
    function closeSurface() { if (surfaceCurrent) { mark("@close"); arbiter.lower(arbiter.current) } }
    function toggleSurface(name, opts) { arbiter.current === name ? closeSurface() : openSurface(name, opts) }
    // Super+Backspace and IPC: open the control center, or close whatever surface is open.
    function toggleExpanded() { surfaceCurrent ? closeSurface() : openSurface("expanded") }
    // Click mapping (design 2.2, Settings.island.click*): cc | notifs | media | calendar | launcher | none.
    function act(action) {
        switch (action) {
        case "cc": toggleSurface("expanded"); break
        case "notifs": toggleSurface("notifCenter"); break
        case "media": toggleSurface("mediaSurface"); break
        case "calendar": toggleSurface("calendar"); break
        case "launcher": toggleSurface("launcher"); break
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
    function showOsd(kind) { osdReg.show(kind) }
    // The surface item, once it is the one shown (Loader is asynchronous), else null.
    function surfaceItem(name) { return state === name && surface.shown === name ? surface.item : null }

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
        else { dwell.stop(); hoverPending = false; grace.restart() }
    }
    function armHover() { if (hoverAllowed && state === "rest") dwell.restart() }
    function tryHover() {
        if (!hover.hovered || !hoverAllowed || state !== "rest") return
        if (body.shrinking()) { hoverPending = true; shrinkPoll.restart(); return }
        arbiter.raise("hover")
    }
    Timer { id: dwell; interval: Settings.motion.hoverDwellMs || 120; onTriggered: islandRoot.tryHover() }
    Timer { id: grace; interval: Settings.motion.leaveGraceMs || 300; onTriggered: if (!hover.hovered) islandRoot.arbiter.lower("hover") }
    Timer { id: shrinkPoll; interval: 16; repeat: true; onTriggered: if (!islandRoot.hoverPending || !body.shrinking()) { stop(); if (islandRoot.hoverPending) { islandRoot.hoverPending = false; islandRoot.tryHover() } } }
    HoverHandler { id: hover; onHoveredChanged: islandRoot.hoverChanged() }

    onStateChanged: {
        inStateChange = true
        const was = lastState; lastState = state
        mark(state)
        if (surfaceOpen) forceActiveFocus()
        navTarget = null
        if (state === "notifCenter") Svc.Notifs.markSeen()
        // The hover face resumed from the queue with the pointer already gone: let the grace close it.
        if (state === "hover" && !hover.hovered) grace.restart()
        // After an OSD or notification the arbiter's hoverArm re-arms at once; anything else dwells.
        if (hover.hovered && hoverAllowed && state === "rest" && was !== "osd" && was !== "media" && was !== "notification")
            armHover()
        inStateChange = false
    }
    function rearm() { if (hover.hovered && hoverAllowed && state === "rest") arbiter.raise("hover") }

    // --- keyboard navigation inside surfaces (Task 16) ---
    // Tab / Shift+Tab walk the open surface's controls in reading order, the arrows move to the
    // nearest control in that direction, Enter or Space clicks it, Esc steps back / closes. A ring
    // in the primary colour marks the control. Controls are the surface's enabled, visible
    // MouseAreas (every surface and the control center build their buttons from them), minus
    // full-surface click swallowers. A surface that owns its keys (the launcher) is left alone.
    property Item navTarget: null
    property rect navRect: Qt.rect(0, 0, 0, 0)
    function isControl(it) { return !!it && it.acceptedButtons !== undefined && it.pressAndHoldInterval !== undefined && it.enabled }
    function navCandidates() {
        const root = surface.item
        if (!root || !surfaceOpen || root.wantsKeyboard) return []
        const out = [], W = root.width, H = root.height
        const walk = it => {
            if (!it || !it.visible || it.opacity <= 0.01) return
            if (it !== root && isControl(it) && it.width > 1 && it.height > 1 && !(it.width >= W * 0.9 && it.height >= H * 0.9)) {
                const p = it.mapToItem(root, it.width / 2, it.height / 2)
                if (p.x >= 0 && p.y >= 0 && p.x <= W && p.y <= H) out.push({ item: it, x: p.x, y: p.y })
            }
            for (let i = 0; i < it.children.length; i++) walk(it.children[i])
        }
        walk(root)
        // Reading order: rows (8 px tolerance) top to bottom, then left to right.
        out.sort((a, b) => Math.abs(a.y - b.y) > 8 ? a.y - b.y : a.x - b.x)
        return out
    }
    function setNav(it) {
        navTarget = it
        if (!it) return
        const p = it.mapToItem(body, 0, 0)
        navRect = Qt.rect(p.x, p.y, it.width, it.height)
        mark("@nav")
    }
    function navStep(delta) {
        const c = navCandidates(); if (!c.length) return false
        const i = c.findIndex(e => e.item === navTarget)
        setNav(c[i < 0 ? (delta > 0 ? 0 : c.length - 1) : (i + delta + c.length) % c.length].item)
        return true
    }
    function navMove(dx, dy) {
        const c = navCandidates(); if (!c.length) return false
        const cur = c.find(e => e.item === navTarget)
        if (!cur) { setNav(c[0].item); return true }
        let best = null, bestD = 1e9
        for (const e of c) {
            if (e.item === cur.item) continue
            const ax = (e.x - cur.x) * dx + (e.y - cur.y) * dy          // along the direction
            const ox = Math.abs((e.x - cur.x) * dy) + Math.abs((e.y - cur.y) * dx) // across it
            if (ax <= 2) continue
            const d = ax + 2 * ox
            if (d < bestD) { bestD = d; best = e }
        }
        if (best) setNav(best.item)
        return true
    }
    function navActivate() {
        const it = navTarget
        if (!it || !isControl(it) || !it.visible) return false
        mark("@activate")
        it.clicked(null)
        return true
    }
    Keys.onPressed: event => {
        if (!surfaceOpen) return
        let done = false
        switch (event.key) {
        case Qt.Key_Tab: done = navStep(event.modifiers & Qt.ShiftModifier ? -1 : 1); break
        case Qt.Key_Backtab: done = navStep(-1); break
        case Qt.Key_Left: done = navMove(-1, 0); break
        case Qt.Key_Right: done = navMove(1, 0); break
        case Qt.Key_Up: done = navMove(0, -1); break
        case Qt.Key_Down: done = navMove(0, 1); break
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: done = navActivate(); break
        }
        if (done) event.accepted = true
    }
    SystemClock { id: dateSrc; precision: SystemClock.Hours }

    // The shape springs to the staged surface's size; the content cross-fades inside it.
    Pill {
        id: body
        target: surface.shapeSize
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            Accessible.role: Accessible.Button
            Accessible.name: "Hush island"
            Accessible.description: "Left click: control center. Right click: notifications. Middle click: media."
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
        // Keyboard focus ring (Task 16): drawn over the focused control, inside the pill's clip.
        Rectangle {
            objectName: "focusRing"
            visible: islandRoot.navTarget !== null && islandRoot.surfaceOpen && islandRoot.navTarget.visible
            x: islandRoot.navRect.x - 3; y: islandRoot.navRect.y - 3
            width: islandRoot.navRect.width + 6; height: islandRoot.navRect.height + 6
            radius: Math.min(12, height / 2)
            color: "transparent"; border.width: 2; border.color: Colors.darkPrimary
            z: 20
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
        register("launcher", launcherComp); register("wallpapers", wallpapersComp); register("settings", settingsComp)
    }
    Component { id: restComp; Rest { island: islandRoot } }
    Component { id: hoverComp; HoverFace { island: islandRoot } }
    OsdRegistrar { id: osdReg; island: islandRoot }
    Loader { source: "states/MediaRegistrar.qml"; onLoaded: item.island = islandRoot }
    NotificationRegistrar { island: islandRoot }
    Component {
        id: ccComp
        Surf.ControlCenter {
            onCloseRequested: islandRoot.closeSurface()
            onOpenWallpapers: islandRoot.openSurface("wallpapers")
        }
    }
    Component { id: mediaSurfaceComp; Surf.Media {} }
    Component { id: calendarComp; Surf.Calendar {} }
    Component { id: notifCenterComp; Surf.NotificationCenter { host: Svc.Notifs } }
    Component { id: launcherComp; Surf.Launcher { mode: islandRoot.launcherMode; onClose: islandRoot.closeSurface() } }
    Component {
        id: wallpapersComp
        Surf.Wallpapers { screenOffset: islandRoot.screenOrigin; onClose: islandRoot.closeSurface(); onPicked: islandRoot.closeSurface() }
    }
    Component {
        id: settingsComp
        Surf.Settings {
            warning: Svc.Notifs.passive ? "Another daemon owns org.freedesktop.Notifications; Hush notifications are off." : ""
            onCloseRequested: islandRoot.closeSurface()
            onOpenWallpapers: islandRoot.openSurface("wallpapers")
        }
    }
}

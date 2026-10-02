import QtQuick
import qs.config

// Staged content for the pill (design 2.5). When `target` changes the pill's shape and its content
// move in order: opening (the new size is larger) starts the shell at once while the old content
// fades out; closing fades the content out first and only then hands the shell its new size. New
// content fades in once the shell has been moving for contentInDelayMs. A retarget mid-sequence
// restarts it from wherever the opacity is, so nothing jumps. Reduced motion scales every duration.
Item {
    id: root
    property string target: "rest"
    property var components: ({})
    // The state whose size the pill takes now, and the state whose content is loaded.
    property string shape: "rest"
    property string shown: ""
    readonly property alias item: loader.item
    readonly property alias contentOpacity: content.opacity
    readonly property real k: Settings.island.reducedMotion ? (Settings.motion.reducedScale || 0.4) : 1
    readonly property int outMs: Math.round((Settings.motion.contentOutMs || 50) * k)
    readonly property int inMs: Math.round((Settings.motion.contentInMs || 120) * k)
    readonly property int inDelayMs: Math.round((Settings.motion.contentInDelayMs || 90) * k)
    property double shellAt: 0
    property bool opening: true
    signal itemLoaded(var item)
    // Arming (design 2.2): for armMs after one of armStates becomes the target, every click and
    // scroll on the pill is swallowed, so a tap meant for the old shape never lands on a new button.
    property var armStates: []
    property bool armed: true

    // Declared size of the shape state, or the loaded item's own size once it is that state.
    readonly property size shapeSize: (loader.item && shown === shape && loader.item.size) ? loader.item.size : Sizes.of(shape)

    function startShell() { shape = target; shellAt = Date.now() }
    function stage() {
        if (shown === "") { startShell(); shown = target; content.opacity = 1; return }
        fadeIn.stop(); inDelay.stop()
        // Back to the content already loaded (a reversal mid-sequence): no fade-out, just return.
        if (target === shown) { fadeOut.stop(); if (shape !== target) startShell(); fadeIn.restart(); return }
        opening = Sizes.area(Sizes.of(target)) >= Sizes.area(Sizes.of(shape))
        if (opening && shape !== target) startShell()
        fadeOut.duration = Math.round(outMs * content.opacity)
        fadeOut.restart()
    }
    function swap() {
        shown = target
        if (shape !== target) startShell()
        inDelay.interval = Math.max(0, inDelayMs - (Date.now() - shellAt))
        inDelay.restart()
    }
    onTargetChanged: {
        if (armStates.indexOf(target) >= 0) { armed = false; armTimer.restart() } else { armTimer.stop(); armed = true }
        stage()
    }
    Timer { id: armTimer; interval: Settings.motion.armMs || 500; onTriggered: root.armed = true }
    Component.onCompleted: stage()

    NumberAnimation { id: fadeOut; target: content; property: "opacity"; to: 0; onFinished: root.swap() }
    Timer { id: inDelay; onTriggered: fadeIn.restart() }
    NumberAnimation { id: fadeIn; target: content; property: "opacity"; to: 1; duration: root.inMs }

    // Content keeps its declared size and stays centred, so it never relayouts while the shell moves.
    Item {
        id: content
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: Sizes.snap(root.shapeSizeOfShown.width); height: root.shapeSizeOfShown.height
        opacity: 0
        Loader {
            id: loader
            anchors.fill: parent
            // Incubate off the frame: a panel built synchronously stalls the spring for ~80 ms.
            asynchronous: true
            sourceComponent: root.components[root.shown] || root.components["rest"] || null
            onLoaded: root.itemLoaded(item)
        }
    }
    readonly property size shapeSizeOfShown: (loader.item && loader.item.size) ? loader.item.size : Sizes.of(shown)
    MouseArea {
        anchors.fill: parent; z: 10
        enabled: !root.armed
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }
}

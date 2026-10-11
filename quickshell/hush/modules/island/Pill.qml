import QtQuick
import qs.config

// The island's black shape. Width, height and radius follow their targets through
// SpringAnimation Behaviors: a new target retargets the running spring (velocity is kept, nothing
// restarts). `calm` picks the slow open spring, otherwise the quick one; reduced motion swaps in a
// damping-1 spring that settles in about 80 ms. Target widths sit on the 8 px grid.
Rectangle {
    id: pill
    property size target: Sizes.rest
    property bool calm: false
    readonly property bool reduced: !!Settings.island.reducedMotion
    readonly property var spec: reduced ? (Settings.motion.springReduced || ({ spring: 50, damping: 1 }))
        : calm ? (Settings.motion.springCalm || ({ spring: 6, damping: 0.5, velocity: 0 }))
        : (Settings.motion.springQuick || ({ spring: 12, damping: 0.6, velocity: 0 }))
    readonly property real springK: spec.spring
    readonly property real springD: spec.damping
    // Speed cap in px/s (0 = none; the defaults are uncapped so a panel opens in ~250 ms).
    readonly property real springV: spec.velocity || 0
    // True while any dimension is still travelling (tests and staging read it).
    readonly property bool moving: Math.abs(width - Sizes.snap(target.width)) > 0.5
        || Math.abs(height - target.height) > 0.5

    // True while the shape is still getting smaller (no hover glance may start then).
    // A function, not a binding: the hover face it gates retargets this very shape.
    function shrinking() { return width > Sizes.snap(target.width) + 0.5 || height > target.height + 0.5 }

    width: Sizes.snap(target.width)
    height: target.height
    radius: Sizes.radiusFor(target.height)
    color: "#000000"
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
    clip: true

    Behavior on width { SpringAnimation { spring: pill.springK; damping: pill.springD; velocity: pill.springV; epsilon: 0.25 } }
    Behavior on height { SpringAnimation { spring: pill.springK; damping: pill.springD; velocity: pill.springV; epsilon: 0.25 } }
    Behavior on radius { SpringAnimation { spring: pill.springK; damping: pill.springD; velocity: pill.springV; epsilon: 0.25 } }
}

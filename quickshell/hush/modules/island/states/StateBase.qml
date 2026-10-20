import QtQuick
import qs.config

// One island state. The pill morphs to Sizes.of(name) (or this item's `size`, once it is the item
// shown); the SurfaceLoader owns the cross-fade, so the item itself is always opaque.
Item {
    id: base
    property string name: "rest"
    property size size: Sizes.rest
    property int priority: 0
    property int holdMs: 0
    property var island: null
    anchors.fill: parent
    // Hidden unless it is the staged content: an async Loader keeps the previous item until the next is built.
    visible: island !== null && (island.shownState === undefined || island.shownState === name)
}

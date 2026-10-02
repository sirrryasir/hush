import QtQuick
import qs.config

// One island state. The island reads `size` from the active state and springs its body to it.
Item {
    id: base
    property string name: "rest"
    property size size: Theme.islandRest
    property int priority: 0
    property int holdMs: 0
    property var island: null
    anchors.fill: parent
    visible: island !== null && island.state === name
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
}

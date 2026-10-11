import QtQuick
import qs.config

// Four rising bars for a Wi-Fi signal (0..100): lit bars in `ink`, the rest at 25 %.
Row {
    id: bars
    property int signal: 0
    property color ink: Colors.islandFg
    readonly property int lit: signal >= 75 ? 4 : signal >= 50 ? 3 : signal >= 25 ? 2 : signal > 0 ? 1 : 0
    spacing: 2
    height: 14
    Repeater {
        model: 4
        Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: 3; height: 5 + index * 3; radius: 1
            color: bars.ink
            opacity: index < bars.lit ? 1 : 0.25
        }
    }
}

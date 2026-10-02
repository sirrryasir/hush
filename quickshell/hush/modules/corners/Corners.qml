import QtQuick
import Quickshell

Scope {
    Variants {
        model: Quickshell.screens
        Scope {
            required property var modelData
            CornerLeft { screen: modelData }
            CornerRight { screen: modelData }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import qs.config

// A control-center sub-page: back button, title, optional trailing switch, a scrolling list.
// Rows come from `model` (array of objects); the delegate fields are given by the caller's roles.
Item {
    id: page
    property string title: ""
    // One muted line under the title (Bluetooth: "Blocked by rfkill", "On · <device>").
    property string subtitle: ""
    property var model: []
    property bool busy: false
    property string emptyText: "Nothing found"
    // Trailing switch (the radio on/off), shown when `switchable`.
    property bool switchable: false
    property bool switchOn: false
    // Row delegate for the list (a Component whose root takes `required property var modelData`);
    // null uses the plain icon / label / trailing-text row.
    property Component delegate: null
    readonly property alias listView: list
    signal back()
    signal switched()
    signal rowClicked(var row)
    signal refresh()

    RowLayout {
        id: head
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 36; spacing: 8
        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18; color: Colors.islandSurfaceHigh
            Text { anchors.centerIn: parent; text: "arrow_back"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 20 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.back(); Accessible.role: Accessible.Button; Accessible.name: "Back" }
        }
        Column {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
            Text {
                width: parent.width; text: page.title; color: Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold
            }
            Text {
                objectName: "subPageSubtitle"
                visible: page.subtitle !== ""; width: parent.width; elide: Text.ElideRight
                text: page.subtitle; color: Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18; color: Colors.islandSurfaceHigh
            Text {
                id: rg; anchors.centerIn: parent; text: "refresh"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 20
                RotationAnimator on rotation { running: page.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite; onRunningChanged: if (!running) rg.rotation = 0 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.refresh(); Accessible.role: Accessible.Button; Accessible.name: "Refresh" }
        }
        Rectangle {
            visible: page.switchable
            Layout.preferredWidth: 44; Layout.preferredHeight: 36; radius: 18; color: page.switchOn ? Colors.islandPrimary : Colors.islandSurfaceHighest
            Rectangle {
                width: 24; height: 24; radius: 12; y: 6
                x: page.switchOn ? parent.width - width - 6 : 6
                color: page.switchOn ? Colors.islandOnPrimary : Colors.islandFgVar
                Behavior on x { NumberAnimation { duration: Theme.durationShort } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.switched(); Accessible.role: Accessible.CheckBox; Accessible.name: page.title + " on"; Accessible.checked: page.switchOn }
        }
    }

    ListView {
        id: list
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.top: head.bottom; anchors.topMargin: 12
        clip: true; spacing: 4; model: page.model
        boundsBehavior: Flickable.StopAtBounds
        delegate: page.delegate || defaultRow
    }
    Component {
        id: defaultRow
        Rectangle {
            id: row
            required property var modelData
            width: list.width; height: 40; radius: 12
            color: modelData.active ? Colors.islandPrimaryContainer : Colors.islandSurfaceHigh
            readonly property color ink: modelData.active ? Colors.islandOnPrimaryContainer : Colors.islandFg
            Text {
                id: lead; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: modelData.icon; color: row.ink; font.family: Theme.fontIcon; font.pixelSize: 20
            }
            Text {
                anchors.left: lead.right; anchors.leftMargin: 12; anchors.right: trail.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label; elide: Text.ElideRight; color: row.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
            }
            Text {
                id: trail; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: modelData.trail || ""; color: row.ink; opacity: 0.8
                font.family: modelData.trailIcon ? Theme.fontIcon : Theme.fontUi; font.pixelSize: modelData.trailIcon ? 18 : 12
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.rowClicked(row.modelData); Accessible.role: Accessible.Button; Accessible.name: row.modelData.label }
        }
    }
    Text {
        anchors.centerIn: list; visible: list.count === 0
        text: page.busy ? "Searching" : page.emptyText; color: Colors.islandFg; opacity: 0.7
        font.family: Theme.fontUi; font.pixelSize: 13
    }
}

import QtQuick
import qs.config
import qs.services as Svc

// One network on the Wi-Fi sub-page: signal bars, SSID, lock, and on the right the state (Disconnect
// on the active network, Connecting, Saved). A secured network without a saved profile opens a
// password field in place under the row; failures show inline under it, never as a notification.
Rectangle {
    id: row
    required property var modelData
    required property int index
    // The control center: askSsid (whose password field is open) and wifiClicked(network).
    property var host: null
    readonly property string ssid: modelData.ssid
    readonly property bool active: modelData.active
    readonly property bool asking: host !== null && host.askSsid === ssid
    readonly property bool busy: Svc.Net.connecting === ssid
    readonly property string error: Svc.Net.errorSsid === ssid ? Svc.Net.lastError : ""
    readonly property color ink: active ? Colors.islandOnPrimaryContainer : Colors.islandFg

    width: ListView.view ? ListView.view.width : 0
    height: 44 + (asking ? 44 : 0) + (error !== "" ? 20 : 0)
    radius: 12
    color: active ? Colors.islandPrimaryContainer : Colors.islandSurfaceHigh
    Behavior on height { NumberAnimation { duration: Theme.durationShort } }
    clip: true

    function join() { if (pw.text.length) Svc.Net.connect(row.ssid, pw.text) }
    onAskingChanged: if (asking) { pw.text = ""; pw.forceActiveFocus(); reveal.restart() }
    onErrorChanged: if (error !== "") reveal.restart()
    // Keep the grown row (field, error line) inside the list once its height has settled.
    Timer { id: reveal; interval: Theme.durationShort + 30; onTriggered: if (row.ListView.view) row.ListView.view.positionViewAtIndex(row.index, ListView.Contain) }

    Item {
        id: top
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 44
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: if (row.host) row.host.wifiClicked(row.modelData)
            Accessible.role: Accessible.Button; Accessible.name: row.ssid
        }
        SignalBars {
            id: bars
            objectName: "wifiBars"
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            signal: row.modelData.signal; ink: row.ink
        }
        Text {
            anchors { left: bars.right; leftMargin: 12; right: lock.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            text: row.ssid; elide: Text.ElideRight; color: row.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
        }
        Text {
            id: lock
            anchors { right: stateBox.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            visible: row.modelData.secure; width: visible ? implicitWidth : 0
            text: "lock"; color: row.ink; opacity: 0.7; font.family: Theme.fontIcon; font.pixelSize: 16
        }
        Item {
            id: stateBox
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: row.active ? disc.width : busyText.visible ? busyText.width + 6 : savedText.visible ? savedText.width + 6 : 0
            height: 28
            PillButton {
                id: disc
                objectName: "wifiDisconnect"
                visible: row.active && !row.busy
                anchors.verticalCenter: parent.verticalCenter
                text: "Disconnect"
                onClicked: Svc.Net.disconnect()
            }
            Text {
                id: busyText
                visible: row.busy; anchors.verticalCenter: parent.verticalCenter
                text: "Connecting"; color: row.ink; opacity: 0.8
                font.family: Theme.fontUi; font.pixelSize: 12
            }
            Text {
                id: savedText
                visible: !row.busy && !row.active && !!Svc.Net.saved[row.ssid]; anchors.verticalCenter: parent.verticalCenter
                text: "Saved"; color: row.ink; opacity: 0.7
                font.family: Theme.fontUi; font.pixelSize: 12
            }
        }
    }
    // Password field, in place under the row.
    Item {
        id: ask
        visible: row.asking
        anchors { left: parent.left; right: parent.right; top: top.bottom; leftMargin: 12; rightMargin: 8 }
        height: 36
        Rectangle {
            anchors { left: parent.left; right: joinBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: 32; radius: 10
            color: Colors.islandSurface
            border.width: pw.activeFocus ? 1 : 0; border.color: Colors.islandPrimary
            TextInput {
                id: pw
                objectName: "wifiPassword"
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "•"
                color: Colors.islandFg; selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                font.family: Theme.fontUi; font.pixelSize: Theme.textControl
                clip: true
                Accessible.role: Accessible.EditableText; Accessible.name: "Password for " + row.ssid
                Keys.onReturnPressed: row.join()
                Keys.onEnterPressed: row.join()
                Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    visible: pw.text.length === 0
                    text: "Password"; color: Colors.islandFgVar; font: pw.font
                }
            }
        }
        PillButton {
            id: joinBtn
            objectName: "wifiJoin"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: row.busy ? "Joining" : "Join"; primary: true
            enabledLook: pw.text.length > 0 && !row.busy
            onClicked: row.join()
        }
    }
    Text {
        objectName: "wifiError"
        visible: row.error !== ""
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 6 }
        text: row.error; elide: Text.ElideRight
        color: Colors.islandError; font.family: Theme.fontUi; font.pixelSize: 11
    }
}

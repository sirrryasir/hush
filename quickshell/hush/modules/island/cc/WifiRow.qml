import QtQuick
import qs.config
import qs.services as Svc

// One network on the Wi-Fi sub-page: signal bars, SSID, lock, and on the right the state (Disconnect
// on the active network, Connecting, Saved, a Forget button on a saved profile that asks twice). The
// joined network carries a detail line (signal, band, security, IPv4). A secured network without a
// saved profile opens a password field in place under the row; failures show inline under it, never
// as a notification. The same row renders the two entries under the list: "Join hidden network"
// (the field asks the name, then the password) and the Hotspot toggle.
Rectangle {
    id: row
    required property var modelData
    required property int index
    // The control center: askSsid (whose password field is open), hiddenKey and wifiClicked(network).
    property var host: null
    readonly property string kind: modelData.hidden ? "hidden" : modelData.hotspot ? "hotspot" : "net"
    // The hidden entry's name once typed; the row then behaves like that network's.
    property string hiddenSsid: ""
    readonly property string ssid: kind === "hidden" ? hiddenSsid : (modelData.ssid || "")
    readonly property string title: kind === "hidden" ? (hiddenSsid || "Join hidden network") : kind === "hotspot" ? "Hotspot" : ssid
    readonly property bool active: kind === "hotspot" ? Svc.Net.hotspot : modelData.active === true
    readonly property bool asking: host !== null && host.askSsid !== "" && host.askSsid === (kind === "hidden" ? host.hiddenKey : ssid)
    readonly property bool busy: ssid !== "" && Svc.Net.connecting === ssid
    readonly property string error: ssid !== "" && Svc.Net.errorSsid === ssid ? Svc.Net.lastError : ""
    readonly property bool saved: kind === "net" && !!Svc.Net.saved[ssid]
    // Forget clicked once; the second click within 2 s deletes the profile (PowerRow's confirm).
    property bool armed: false
    readonly property color ink: active ? Colors.islandOnPrimaryContainer : Colors.islandFg

    width: ListView.view ? ListView.view.width : 0
    height: 44 + (asking ? 44 : 0) + (error !== "" ? 20 : 0)
    radius: 12
    color: active ? Colors.islandPrimaryContainer : Colors.islandSurfaceHigh
    Behavior on height { NumberAnimation { duration: Theme.durationShort } }
    clip: true

    function join() {
        if (!pw.text.length) return
        if (kind === "hidden" && hiddenSsid === "") { hiddenSsid = pw.text; pw.text = ""; return }
        Svc.Net.connect(row.ssid, pw.text, kind === "hidden")
    }
    function forget() {
        if (!armed) { armed = true; disarm.restart(); return }
        armed = false; disarm.stop(); Svc.Net.forget(ssid)
    }
    Timer { id: disarm; interval: 2000; onTriggered: row.armed = false }
    onAskingChanged: if (asking) { pw.text = ""; hiddenSsid = ""; pw.forceActiveFocus(); reveal.restart() }
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
            Accessible.role: Accessible.Button; Accessible.name: row.title
        }
        Item {
            id: lead
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: row.kind === "net" ? bars.width : glyph.width; height: 20
            SignalBars {
                id: bars
                objectName: "wifiBars"
                visible: row.kind === "net"; anchors.verticalCenter: parent.verticalCenter
                signal: row.modelData.signal || 0; ink: row.ink
            }
            Text {
                id: glyph
                visible: row.kind !== "net"; anchors.verticalCenter: parent.verticalCenter
                text: row.kind === "hotspot" ? "wifi_tethering" : "wifi_find"; color: row.ink
                font.family: Theme.fontIcon; font.pixelSize: 20
            }
        }
        Column {
            anchors { left: lead.right; leftMargin: 12; right: lock.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width; text: row.title; elide: Text.ElideRight; color: row.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
            }
            Text {
                objectName: "wifiDetail"
                visible: row.kind === "net" && row.active
                width: parent.width; elide: Text.ElideRight; color: row.ink; opacity: 0.75
                text: (row.modelData.signal || 0) + " % · " + (row.modelData.band || "") + " · " + (row.modelData.security || "Open")
                    + (Svc.Net.ip4 ? " · " + Svc.Net.ip4 : "")
                font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
        Text {
            id: lock
            anchors { right: trail.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            visible: row.kind === "net" && row.modelData.secure; width: visible ? implicitWidth : 0
            text: "lock"; color: row.ink; opacity: 0.7; font.family: Theme.fontIcon; font.pixelSize: 16
        }
        Row {
            id: trail
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 6
            PillButton {
                objectName: "wifiDisconnect"
                visible: row.kind === "net" && row.active && !row.busy
                text: "Disconnect"
                onClicked: Svc.Net.disconnect()
            }
            Text {
                visible: row.busy; anchors.verticalCenter: parent.verticalCenter
                text: "Connecting"; color: row.ink; opacity: 0.8
                font.family: Theme.fontUi; font.pixelSize: 12
            }
            Text {
                visible: row.saved && !row.busy && !row.active; anchors.verticalCenter: parent.verticalCenter
                text: "Saved"; color: row.ink; opacity: 0.7
                font.family: Theme.fontUi; font.pixelSize: 12
            }
            PillButton {
                objectName: "wifiForget"
                visible: row.saved && !row.busy
                glyph: "delete"; text: row.armed ? "Forget" : ""
                color: row.armed ? Colors.islandErrorContainer : Colors.islandSurfaceHighest
                Accessible.name: row.armed ? "Confirm forget" : "Forget"
                onClicked: row.forget()
            }
            PillButton {
                objectName: "hotspotToggle"
                visible: row.kind === "hotspot"
                text: Svc.Net.hotspot ? "Stop" : "Start"; primary: !Svc.Net.hotspot
                onClicked: Svc.Net.toggleHotspot()
            }
        }
    }
    // Password field (the network name first, for the hidden entry), in place under the row.
    Item {
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
                readonly property bool nameStep: row.kind === "hidden" && row.hiddenSsid === ""
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: nameStep ? TextInput.Normal : TextInput.Password; passwordCharacter: "•"
                color: Colors.islandFg; selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                font.family: Theme.fontUi; font.pixelSize: Theme.textControl
                clip: true
                Accessible.role: Accessible.EditableText; Accessible.name: nameStep ? "Network name" : "Password for " + row.ssid
                Keys.onReturnPressed: row.join()
                Keys.onEnterPressed: row.join()
                Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    visible: pw.text.length === 0
                    text: pw.nameStep ? "Network name" : "Password"; color: Colors.islandFgVar; font: pw.font
                }
            }
        }
        PillButton {
            id: joinBtn
            objectName: "wifiJoin"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: row.busy ? "Joining" : pw.nameStep ? "Next" : "Join"; primary: true
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

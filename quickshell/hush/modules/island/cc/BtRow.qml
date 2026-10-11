import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services as Svc

// One device on the Bluetooth sub-page: glyph, name, a state line (Connected · battery, Paired,
// Pairing, Connecting, Not paired) and the actions for that state: Disconnect, Connect + Forget, Pair.
// Reads the device object directly, so the row follows bluez without waiting for a list refresh.
Rectangle {
    id: row
    required property var modelData
    readonly property var dev: modelData.dev
    readonly property bool connected: !!dev && dev.connected
    readonly property bool paired: !!dev && dev.paired
    readonly property bool busy: !!dev && (dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting)
    readonly property int battery: connected && dev.batteryAvailable ? Math.round(dev.battery * 100) : -1
    readonly property color ink: connected ? Colors.islandOnPrimaryContainer : Colors.islandFg
    readonly property string stateText: !dev ? "" : dev.pairing ? "Pairing"
        : dev.state === BluetoothDeviceState.Connecting ? "Connecting" : dev.state === BluetoothDeviceState.Disconnecting ? "Disconnecting"
        : connected ? (battery >= 0 ? "Connected · " + battery + " %" : "Connected") : paired ? "Paired" : "Not paired"

    width: ListView.view ? ListView.view.width : 0
    height: 48; radius: 12
    color: connected ? Colors.islandPrimaryContainer : Colors.islandSurfaceHigh

    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: if (!row.busy) Svc.Bt.toggleDevice(row.dev)
        Accessible.role: Accessible.Button; Accessible.name: row.modelData.name
    }
    Text {
        id: lead
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        text: row.connected ? "bluetooth_connected" : "bluetooth"; color: row.ink
        font.family: Theme.fontIcon; font.pixelSize: 20
        RotationAnimator on rotation { running: row.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite; onRunningChanged: if (!running) lead.rotation = 0 }
    }
    Column {
        anchors { left: lead.right; leftMargin: 12; right: actions.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Text {
            width: parent.width; text: row.modelData.name; elide: Text.ElideRight; color: row.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.textControl; font.weight: Font.Medium
        }
        Text {
            objectName: "btState"
            width: parent.width; text: row.stateText; elide: Text.ElideRight; color: row.ink; opacity: 0.75
            font.family: Theme.fontUi; font.pixelSize: 11
        }
    }
    Row {
        id: actions
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 6
        visible: !row.busy
        PillButton { objectName: "btDisconnect"; visible: row.connected; text: "Disconnect"; onClicked: Svc.Bt.disconnectDevice(row.dev) }
        PillButton { objectName: "btConnect"; visible: row.paired && !row.connected; text: "Connect"; primary: true; onClicked: Svc.Bt.connectDevice(row.dev) }
        PillButton { objectName: "btPair"; visible: !row.paired; text: "Pair"; primary: true; onClicked: Svc.Bt.pairDevice(row.dev) }
        PillButton { objectName: "btForget"; visible: row.paired; glyph: "delete"; Accessible.name: "Forget"; onClicked: Svc.Bt.forgetDevice(row.dev) }
    }
}

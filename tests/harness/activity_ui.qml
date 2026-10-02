import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import "modules/island/rest"

// Harness for the rest-pill live activities: the real ActivityCircle and StatusRing on a black pill,
// with the service inputs overridden by plain properties (no IPC to the services).
// qs -p tests/harness/activity_ui.qml ipc call activityui set <rec> <timer> <secs> <media> <mic> <cam> <plugged>
ShellRoot {
    PanelWindow {
        WlrLayershell.namespace: "hush-harness-activity"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        margins.top: 60
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 240; implicitHeight: 60
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent; height: 36; width: row.width + 28; radius: 18; color: "#000000"
            Row {
                id: row; anchors.centerIn: parent; spacing: 10
                ActivityCircle { id: act; objectName: "act"; visible: shown; anchors.verticalCenter: parent.verticalCenter
                    recording: false; timerOn: false; timerSecs: 0; mediaOn: false; mediaProgress: 0.4; artUrl: "" }
                Text { text: "12:34"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                StatusRing { id: ring; anchors.verticalCenter: parent.verticalCenter
                    mic: false; camera: false; plugged: false; charging: false }
            }
        }
    }
    IpcHandler {
        target: "activityui"
        function set(rec: bool, tm: bool, secs: int, media: bool, mic: bool, cam: bool, plugged: bool): void {
            act.recording = rec; act.timerOn = tm; act.timerSecs = secs; act.mediaOn = media
            ring.mic = mic; ring.camera = cam; ring.plugged = plugged; ring.charging = plugged
        }
        function mode(): string { return act.mode }
        function shown(): bool { return act.shown }
        function timeText(): string { return act.timeText }
        function glyph(): string { return ring.glyph }
        function width(): int { return act.width }
    }
}

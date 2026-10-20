import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Harness: the Devices service alone, reading a fake udisksctl on PATH.
// Run: qs -p tests/harness/device.qml
ShellRoot {
    IpcHandler {
        target: "harness-device"
        function names(): string { return Devices.list.map(d => d.name).join("|") }
        function detail(): string { const d = Devices.list[0]; return d ? d.size + " · " + d.fs + " · " + (d.mount ? "mounted" : "not mounted") : "" }
        function mount(): void { Devices.mount(Devices.list[0]) }
    }
}

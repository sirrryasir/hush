pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Where the Hush repo lives. HUSH_ROOT wins; otherwise the shell dir is a symlink into
// <repo>/quickshell/hush, so its physical grandparent is the repo root.
Singleton {
    id: root
    property string repo: Quickshell.env("HUSH_ROOT") || ""
    readonly property bool ready: root.repo !== ""
    readonly property string themes: root.repo + "/themes"
    // Before the root resolves, fall back to the installed entry point.
    readonly property string hush: root.ready ? root.repo + "/bin/hush" : Quickshell.env("HOME") + "/.local/bin/hush"

    Process {
        running: !root.ready
        command: ["readlink", "-f", Quickshell.shellDir + "/../.."]
        stdout: StdioCollector { onStreamFinished: if (text.trim().length) root.repo = text.trim() }
    }
}

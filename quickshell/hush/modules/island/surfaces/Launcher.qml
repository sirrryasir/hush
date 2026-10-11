import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import "launcher"

// Launcher surface (design 2.6): a search field over a result list, 520x300 inside the island.
// Modes: "apps" (apps and windows merged, the default), "windows", "calc" and "clip", chosen by the
// `mode` property or by a prefix typed in the field ("=" calc, ";" clipboard, "@" windows).
// Up/Down/Tab/Ctrl+N/P move, Enter runs, Esc emits close(). The Hyprland focus grab belongs to the
// island window, which reads wantsKeyboard.
FocusScope {
    id: root
    property size size: Sizes.launcher
    property bool wantsKeyboard: true
    property string mode: "apps"
    property string query: ""
    property int currentIndex: 0
    property var recency: ({})
    signal close()

    readonly property string effectiveMode: query.startsWith("=") ? "calc" : query.startsWith(";") ? "clip"
        : query.startsWith("@") ? "windows" : mode
    readonly property string needle: (effectiveMode !== mode || query.length && "=;@".indexOf(query[0]) >= 0) ? query.slice(1) : query
    readonly property var results: compute()
    readonly property int count: results.length
    readonly property string firstName: count > 0 ? results[0].name : ""
    readonly property string currentName: count > 0 && currentIndex < count ? results[currentIndex].name : ""
    readonly property bool clipAvailable: clip.available
    readonly property bool clipLoaded: clip.loaded
    readonly property int clipLines: clip.lines.length

    function setQuery(q) { query = q; currentIndex = 0; input.text = q }
    function move(d) { if (count > 0) currentIndex = (currentIndex + d + count) % count }
    function focusInput() { input.forceActiveFocus() }
    function activate(i) {
        const item = results[i === undefined ? currentIndex : i]
        if (!item) return
        if (item.remember) bump(item.name)
        root.close()
        item.run()
    }

    // Subsequence match with bonuses for a prefix hit, word starts and consecutive runs.
    function fuzzy(q, s) {
        if (!s) return -1
        s = s.toLowerCase()
        if (q.length === 0) return 0
        let score = 0, si = 0, prev = -2
        for (let qi = 0; qi < q.length; qi++) {
            const at = s.indexOf(q[qi], si)
            if (at < 0) return -1
            score += 1
            if (at === prev + 1) score += 3
            if (at === 0 || " -_./".indexOf(s[at - 1]) >= 0) score += 5
            prev = at; si = at + 1
        }
        if (s.startsWith(q)) score += 15
        if (s === q) score += 10
        return score - s.length * 0.05
    }
    function bump(name) {
        let r = Object.assign({}, recency)
        r[name] = (r[name] || 0) + 1
        const keys = Object.keys(r)
        if (keys.length > 200) {
            const kept = {}
            keys.sort((a, b) => r[b] - r[a]).slice(0, 200).forEach(k => kept[k] = r[k])
            r = kept
        }
        recency = r
        recencyFile.setText(JSON.stringify(r))
    }
    function compute() {
        const m = effectiveMode
        if (m === "calc") return calc.items(needle)
        if (m === "clip") return clip.items(needle.trim().toLowerCase())
        const q = needle.trim().toLowerCase()
        let pool = []
        if (m !== "windows") pool = pool.concat(apps.items())
        pool = pool.concat(windows.items())
        if (m === "apps") pool = pool.filter(it => it.kind === "app" || q.length > 0)
        const out = []
        for (const it of pool) {
            let s = fuzzy(q, it.name)
            const h = fuzzy(q, it.keywords || it.hint) * 0.5
            if (h > s) s = h
            if (s < 0) continue
            s += Math.log(1 + (recency[it.name] || 0)) * 4 + (it.kind === "window" && q.length === 0 ? 100 : 0)
            out.push({ item: it, score: s })
        }
        out.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name))
        return out.slice(0, 50).map(o => o.item)
    }

    Apps { id: apps }
    Windows { id: windows }
    Calc { id: calc; query: root.effectiveMode === "calc" ? root.needle.trim() : "" }
    Clip { id: clip; active: root.effectiveMode === "clip" }

    Process { running: true; command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/hush"] }
    FileView {
        id: recencyFile
        atomicWrites: true
        path: Quickshell.env("HOME") + "/.cache/hush/launcher-recency.json"
        printErrors: false
        onLoaded: { try { root.recency = JSON.parse(text()) || {} } catch (e) { root.recency = {} } }
    }

    Component.onCompleted: input.forceActiveFocus()
    onVisibleChanged: if (visible) input.forceActiveFocus()

    Item {
        anchors.fill: parent; anchors.margins: 16

        Item {
            id: field
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 36
            Text {
                id: glyph
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                text: root.effectiveMode === "calc" ? "calculate" : root.effectiveMode === "clip" ? "content_paste"
                    : root.effectiveMode === "windows" ? "select_window" : "search"
                font.family: Theme.fontIcon; font.pixelSize: 20; color: Colors.islandFgVar
            }
            TextInput {
                id: input
                Accessible.role: Accessible.EditableText; Accessible.name: "Search"
                anchors { left: glyph.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
                font.family: Theme.fontUi; font.pixelSize: Theme.textLauncher
                color: Colors.islandFg
                selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                clip: true
                focus: true
                onTextEdited: { root.query = text; root.currentIndex = 0 }
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) root.close()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate()
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) root.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) root.move(-1)
                    else return
                    event.accepted = true
                }
                Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: root.mode === "windows" ? "Switch to a window" : root.mode === "clip" ? "Search the clipboard"
                        : root.mode === "calc" ? "Calculate" : "Search apps, @ windows, = calc, ; clipboard"
                    font: input.font; color: Colors.islandFgVar
                }
            }
        }
        Rectangle {
            id: rule
            anchors { left: parent.left; right: parent.right; top: field.bottom; topMargin: 8 }
            height: 1; color: Qt.rgba(1, 1, 1, 0.12)
        }
        ListView {
            id: list
            objectName: "resultList"
            anchors { left: parent.left; right: parent.right; top: rule.bottom; topMargin: 6; bottom: parent.bottom }
            clip: true
            model: root.results
            currentIndex: root.currentIndex
            highlightMoveDuration: 80
            boundsBehavior: Flickable.StopAtBounds
            delegate: ResultRow {
                required property var modelData
                required property int index
                width: list.width
                entry: modelData
                selected: index === root.currentIndex
                onClicked: root.activate(index)
                onHovered: root.currentIndex = index
            }
            Text {
                objectName: "emptyText"
                anchors.centerIn: parent; visible: list.count === 0
                text: root.effectiveMode !== "clip" ? "No matches" : !root.clipLoaded ? "Loading clipboard" : !root.clipAvailable ? "cliphist not installed"
                    : root.clipLines === 0 ? "Clipboard is empty" : "No matches"
                font.family: Theme.fontUi; font.pixelSize: Theme.textLauncher; color: Colors.islandFgVar
            }
        }
    }
}

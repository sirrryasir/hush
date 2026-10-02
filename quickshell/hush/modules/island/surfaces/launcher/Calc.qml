import QtQuick
import Quickshell
import Quickshell.Io

// "=expr": qalc when installed, otherwise a small arithmetic parser (digits, + - * / % ^, parens, dot).
Item {
    id: root
    property bool hasQalc: false
    // The text after "=", bound by the launcher; the qalc run is debounced from here, never from items().
    property string query: ""
    property string expr: ""
    property string qalcResult: ""

    function items(e) {
        e = e.trim()
        if (e.length === 0) return []
        let value
        if (hasQalc) {
            value = expr === e ? qalcResult : ""
        } else {
            value = evaluate(e)
        }
        if (value === "" || value === null) return []
        return [{
            kind: "calc", remember: false, icon: "accessories-calculator",
            name: value, hint: "= " + e + "  ·  Enter copies",
            run: () => Quickshell.execDetached(["wl-copy", "--", value])
        }]
    }

    function evaluate(src) {
        if (!/^[0-9+\-*/%^().\s]+$/.test(src)) return ""
        let i = 0
        const s = src.replace(/\s+/g, "")
        function peek() { return s[i] }
        function num() {
            const m = /^[0-9]*\.?[0-9]+|^[0-9]+\.?/.exec(s.slice(i))
            if (!m) throw "bad"
            i += m[0].length
            return parseFloat(m[0])
        }
        function atom() {
            if (peek() === "-") { i++; return -atom() }
            if (peek() === "+") { i++; return atom() }
            if (peek() === "(") { i++; const v = sum(); if (s[i++] !== ")") throw "paren"; return v }
            return num()
        }
        function power() { const b = atom(); if (peek() === "^") { i++; return Math.pow(b, power()) } return b }
        function product() {
            let v = power()
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = s[i++]; const r = power()
                v = op === "*" ? v * r : op === "/" ? v / r : v % r
            }
            return v
        }
        function sum() {
            let v = product()
            while (peek() === "+" || peek() === "-") { const op = s[i++]; const r = product(); v = op === "+" ? v + r : v - r }
            return v
        }
        try {
            const v = sum()
            if (i !== s.length || !isFinite(v)) return ""
            return String(Math.round(v * 1e10) / 1e10)
        } catch (err) { return "" }
    }

    onQueryChanged: { qalcResult = ""; if (hasQalc && query.length) debounce.restart() }
    Timer { id: debounce; interval: 100; onTriggered: { root.expr = root.query; proc.command = ["qalc", "-t", root.query]; proc.running = true } }
    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: root.qalcResult = text.trim() }
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v qalc"]
        onExited: code => root.hasQalc = code === 0
    }
}

import QtQml

// The island's single source of truth for what is shown. Pure QML: no
// Quickshell imports, so tests/qml/tst_arbiter.qml runs it under plain qmltestrunner.
//
//   declare(name, priority, { sticky, holdMs, coalesce })
//   raise(name, payload)   payload.key, when set, identifies one item of a source
//   lower(name[, key])     drops the source (or one keyed item), current or queued
//   pause(on)              holds the current transient's timer (a hovered notification); off
//                          re-arms it from its full hold
//
// Rules:
// - The current entry is the highest-priority raised one. A raise above the current one
//   preempts it; a preempted entry waits in the queue and resumes when the slot frees.
// - An equal-priority raise from a different source replaces the current one; a replaced
//   transient is dropped (a newer OSD supersedes an older one), a persistent one waits.
// - Lower raises wait in `queue`, ordered by priority then FIFO, deduped by name + payload.key.
// - A transient (holdMs > 0, not sticky) auto-lowers holdMs after it became current; with
//   coalesce, every raise of the current source re-times it from that raise.
// - Sticky sources never auto-lower. Persistent sources (holdMs 0) stay until lowered.
// - When a transient ends while pointerInside is true, hoverArm() fires (after the next
//   queued entry is promoted) so hover can resume.
QtObject {
    id: root

    property bool pointerInside: false
    readonly property string current: _cur ? _cur.name : ""
    readonly property var payload: _cur ? _cur.payload : ({})
    readonly property int currentPriority: _cur ? _cur.priority : 0
    // Names waiting, in the order they will be shown.
    readonly property var queue: _queue.map(e => e.name)

    signal shown(string name, var payload)
    signal hidden(string name)
    // The entry is gone for good (lowered, timed out or superseded), not merely preempted.
    signal ended(string name, var payload)
    signal hoverArm()

    property var _decls: ({})
    property var _cur: null
    property var _queue: []
    property int _seq: 0
    property bool _paused: false

    property Timer _hold: Timer {
        repeat: false
        onTriggered: root._expire()
    }

    function declare(name, priority, opts) {
        const o = opts || {};
        const d = Object.assign({}, root._decls);
        d[name] = {
            priority: priority,
            sticky: !!o.sticky,
            holdMs: o.holdMs || 0,
            coalesce: !!o.coalesce
        };
        root._decls = d;
    }

    function raise(name, payload) {
        const d = root._decls[name];
        if (!d) {
            console.warn("Arbiter: raise of undeclared source", name);
            return;
        }
        const p = payload === undefined ? ({}) : payload;
        const key = _keyOf(p);
        const c = root._cur;
        // The same item again: update it in place.
        if (c && c.name === name && c.key === key) {
            c.payload = p;
            root._cur = Object.assign({}, c);
            if (d.coalesce)
                _arm(d);
            root.shown(name, p);
            return;
        }
        // Dedupe against the queue.
        const qi = root._queue.findIndex(e => e.name === name && e.key === key);
        if (qi >= 0) {
            const q = root._queue.slice();
            q[qi] = Object.assign({}, q[qi], { payload: p });
            root._queue = q;
            return;
        }
        const e = { name: name, key: key, payload: p, priority: d.priority, seq: ++root._seq };
        if (!c) {
            _show(e);
        } else if (d.priority > c.priority || (d.priority === c.priority && c.name !== name)) {
            const keep = d.priority > c.priority || !_transient(root._decls[c.name]);
            _leave(keep ? "preempt" : "drop");
            _show(e);
        } else {
            _enqueue(e);
        }
    }

    function lower(name, key) {
        const byKey = key !== undefined;
        root._queue = root._queue.filter(e => !(e.name === name && (!byKey || e.key === String(key))));
        const c = root._cur;
        if (c && c.name === name && (!byKey || c.key === String(key)))
            _end();
    }

    function pause(on) {
        if (root._paused === !!on)
            return;
        root._paused = !!on;
        if (root._paused)
            root._hold.stop();
        else if (root._cur)
            _arm(root._decls[root._cur.name]);
    }

    function reset() {
        root._hold.stop();
        root._paused = false;
        root._cur = null;
        root._queue = [];
        root._decls = ({});
        root.pointerInside = false;
    }

    // --- internals
    function _keyOf(p) {
        return p && p.key !== undefined && p.key !== null ? String(p.key) : "";
    }
    function _transient(d) {
        return d && !d.sticky && d.holdMs > 0;
    }
    function _arm(d) {
        root._hold.stop();
        if (_transient(d) && !root._paused) {
            root._hold.interval = d.holdMs;
            root._hold.start();
        }
    }
    function _enqueue(e) {
        const q = root._queue.slice();
        let i = 0;
        while (i < q.length && (q[i].priority > e.priority || (q[i].priority === e.priority && q[i].seq < e.seq)))
            i++;
        q.splice(i, 0, e);
        root._queue = q;
    }
    function _show(e) {
        root._cur = e;
        _arm(root._decls[e.name]);
        root.shown(e.name, e.payload);
    }
    // Take the current entry off the slot without promoting anything.
    function _leave(how) {
        const c = root._cur;
        root._hold.stop();
        root._cur = null;
        if (how === "preempt")
            _enqueue(c);
        root.hidden(c.name);
        if (how !== "preempt")
            root.ended(c.name, c.payload);
    }
    // The current entry ends (lowered or timed out): re-arm hover, then play the next one.
    function _end() {
        const c = root._cur;
        const wasTransient = _transient(root._decls[c.name]);
        _leave("drop");
        if (!root._cur && root._queue.length) {
            const q = root._queue.slice();
            const next = q.shift();
            root._queue = q;
            _show(next);
        }
        // After promotion, so a hover raised from the handler queues under real work.
        if (wasTransient && root.pointerInside)
            root.hoverArm();
    }
    function _expire() {
        if (root._cur)
            _end();
    }
}

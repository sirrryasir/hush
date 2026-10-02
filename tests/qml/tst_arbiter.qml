import QtQuick
import QtTest
import "../../quickshell/hush/modules/island"

// Table-driven tests for the island Arbiter (design 2.3). Each row is a script of steps
// followed by the expected current source, queue and (optionally) event log / payload.
// Steps: ["d", name, priority, opts] declare, ["r", name, payload] raise, ["l", name, key?]
// lower, ["w", ms] wait, ["p", bool] pointerInside.
TestCase {
    id: tc
    name: "Arbiter"

    property var log: []
    property var ended: []

    Arbiter {
        id: arb
        onShown: (n, p) => tc.log.push("+" + n)
        onHidden: n => tc.log.push("-" + n)
        onHoverArm: tc.log.push("arm")
        onEnded: (n, p) => tc.ended.push(n + (p && p.key ? ":" + p.key : ""))
    }

    // Common declarations, priorities as in config/Priorities.qml.
    readonly property var decls: [
        ["d", "modal", 90, {}],
        ["d", "expanded", 80, {}],
        ["d", "critical", 70, { sticky: true, holdMs: 60 }],
        ["d", "notification", 60, { holdMs: 150 }],
        ["d", "osd", 50, { holdMs: 150, coalesce: true }],
        ["d", "osd2", 50, { holdMs: 150, coalesce: true }],
        ["d", "activity", 30, {}],
        ["d", "hover", 40, {}]
    ]

    function init() {
        arb.reset();
        tc.log = [];
        tc.ended = [];
    }

    function run(steps) {
        const all = tc.decls.concat(steps);
        for (const s of all) {
            switch (s[0]) {
            case "d": arb.declare(s[1], s[2], s[3]); break;
            case "r": arb.raise(s[1], s[2]); break;
            case "l": s.length > 2 ? arb.lower(s[1], s[2]) : arb.lower(s[1]); break;
            case "w": wait(s[1]); break;
            case "p": arb.pointerInside = s[1]; break;
            }
        }
    }

    function test_rules_data() {
        return [
            { tag: "empty is rest", steps: [], current: "", queue: [] },
            { tag: "single raise shows", steps: [["r", "activity"]], current: "activity", queue: [],
              log: ["+activity"] },
            { tag: "higher priority wins", steps: [["r", "activity"], ["r", "expanded"]],
              current: "expanded", queue: ["activity"], log: ["+activity", "-activity", "+expanded"] },
            { tag: "lower raise does not preempt", steps: [["r", "expanded"], ["r", "activity"]],
              current: "expanded", queue: ["activity"], log: ["+expanded"] },
            { tag: "lower transient queued, resumes after current lowers",
              steps: [["r", "expanded"], ["r", "notification", { key: "a" }], ["l", "expanded"]],
              current: "notification", queue: [], log: ["+expanded", "-expanded", "+notification"] },
            { tag: "queue is FIFO within a priority",
              steps: [["r", "expanded"], ["r", "notification", { key: "a" }], ["r", "notification", { key: "b" }],
                      ["l", "expanded"]],
              current: "notification", queue: ["notification"], payloadKey: "a" },
            { tag: "queue orders by priority first",
              steps: [["r", "modal"], ["r", "activity"], ["r", "osd"], ["r", "notification", { key: "a" }]],
              current: "modal", queue: ["notification", "osd", "activity"] },
            { tag: "dedupe by payload.key in queue",
              steps: [["r", "expanded"], ["r", "notification", { key: "a", v: 1 }],
                      ["r", "notification", { key: "a", v: 2 }], ["l", "expanded"]],
              current: "notification", queue: [], payloadKey: "a", payloadV: 2 },
            { tag: "same key on current updates in place, no queue",
              steps: [["r", "notification", { key: "a", v: 1 }], ["r", "notification", { key: "a", v: 2 }]],
              current: "notification", queue: [], payloadV: 2,
              log: ["+notification", "+notification"] },
            { tag: "raise of same name updates payload",
              steps: [["r", "activity", { v: 1 }], ["r", "activity", { v: 7 }]],
              current: "activity", queue: [], payloadV: 7 },
            { tag: "equal priority different source replaces, transient dropped",
              steps: [["r", "osd", { v: 1 }], ["r", "osd2", { v: 2 }]],
              current: "osd2", queue: [], log: ["+osd", "-osd", "+osd2"] },
            { tag: "release of a queued item",
              steps: [["r", "expanded"], ["r", "activity"], ["r", "osd"], ["l", "activity"]],
              current: "expanded", queue: ["osd"] },
            { tag: "release of one keyed queued item",
              steps: [["r", "expanded"], ["r", "notification", { key: "a" }], ["r", "notification", { key: "b" }],
                      ["l", "notification", "a"], ["l", "expanded"]],
              current: "notification", queue: [], payloadKey: "b" },
            { tag: "preempted persistent resumes",
              steps: [["r", "activity"], ["r", "modal"], ["l", "modal"]],
              current: "activity", queue: [], log: ["+activity", "-activity", "+modal", "-modal", "+activity"] },
            { tag: "preempted transient resumes",
              steps: [["r", "notification", { key: "a" }], ["r", "critical", { key: "c" }], ["l", "critical"]],
              current: "notification", queue: [], payloadKey: "a" },
            { tag: "transient auto-lowers after holdMs",
              steps: [["r", "notification", { key: "a" }], ["w", 300]],
              current: "", queue: [], log: ["+notification", "-notification"] },
            { tag: "transient timeout plays the next queued",
              steps: [["r", "osd"], ["r", "activity"], ["w", 300]],
              current: "activity", queue: [], log: ["+osd", "-osd", "+activity"] },
            { tag: "sticky never auto-lowers",
              steps: [["r", "critical", { key: "c" }], ["w", 250]],
              current: "critical", queue: [] },
            { tag: "undeclared raise ignored", steps: [["r", "nope"]], current: "", queue: [] },
            { tag: "lower of unknown is a no-op", steps: [["r", "activity"], ["l", "nope"]],
              current: "activity", queue: [] },
            { tag: "hover re-arm when a transient ends with pointer inside",
              steps: [["p", true], ["r", "osd"], ["l", "osd"]],
              current: "", queue: [], log: ["+osd", "-osd", "arm"] },
            { tag: "no re-arm when pointer outside",
              steps: [["r", "osd"], ["l", "osd"]], current: "", queue: [], log: ["+osd", "-osd"] },
            { tag: "no re-arm when a persistent source ends",
              steps: [["p", true], ["r", "expanded"], ["l", "expanded"]],
              current: "", queue: [], log: ["+expanded", "-expanded"] },
            { tag: "re-arm fires after the next queued is promoted",
              steps: [["p", true], ["r", "osd"], ["r", "activity"], ["l", "osd"]],
              current: "activity", queue: [], log: ["+osd", "-osd", "+activity", "arm"] }
        ];
    }

    function test_rules(row) {
        run(row.steps);
        compare(arb.current, row.current, "current");
        compare(JSON.stringify(arb.queue), JSON.stringify(row.queue), "queue");
        if (row.log !== undefined)
            compare(JSON.stringify(tc.log), JSON.stringify(row.log), "events");
        if (row.payloadKey !== undefined)
            compare(arb.payload.key, row.payloadKey, "payload.key");
        if (row.payloadV !== undefined)
            compare(arb.payload.v, row.payloadV, "payload.v");
    }

    // Coalesce re-times from the last raise: 150 ms hold, raised at 0 and ~100, alive at ~200.
    function test_coalesce_retimes() {
        run([["r", "osd", { v: 1 }], ["w", 100], ["r", "osd", { v: 2 }], ["w", 100]]);
        compare(arb.current, "osd", "still shown 200 ms after the first raise");
        compare(arb.payload.v, 2);
        tryCompare(arb, "current", "", 500);
    }

    // Without coalesce, a repeat raise updates the payload but keeps the original deadline.
    function test_no_coalesce_keeps_deadline() {
        run([["r", "notification", { key: "a" }], ["w", 100], ["r", "notification", { key: "a", v: 3 }], ["w", 100]]);
        compare(arb.current, "", "gone 200 ms after the first raise");
    }

    function test_hover_handler_can_raise() {
        const h = function () { arb.raise("hover"); };
        arb.hoverArm.connect(h);
        run([["p", true], ["r", "osd"], ["l", "osd"]]);
        arb.hoverArm.disconnect(h);
        compare(arb.current, "hover");
    }

    // Pause holds a transient past its deadline; resuming re-arms the full hold.
    function test_pause_holds() {
        run([["r", "notification", { key: "a" }]]);
        arb.pause(true);
        wait(250);
        compare(arb.current, "notification", "paused past the 150 ms hold");
        arb.pause(false);
        wait(80);
        compare(arb.current, "notification", "re-armed from the full hold");
        tryCompare(arb, "current", "", 400);
    }

    // ended fires for expiry and lowering, not for preemption (the entry resumes).
    function test_ended_not_on_preempt() {
        run([["r", "notification", { key: "a" }], ["r", "expanded"], ["l", "expanded"]]);
        compare(JSON.stringify(tc.ended), JSON.stringify(["expanded"]));
        compare(arb.current, "notification", "preempted notification resumes");
        tryCompare(arb, "current", "", 400);
        compare(JSON.stringify(tc.ended), JSON.stringify(["expanded", "notification:a"]));
    }

    // Queue resume: a notification raised under a surface plays as soon as the surface lowers.
    function test_queue_resume() {
        run([["r", "expanded"], ["r", "notification", { key: "n1" }], ["r", "notification", { key: "n2" }]]);
        compare(JSON.stringify(arb.queue), JSON.stringify(["notification", "notification"]));
        arb.lower("expanded");
        compare(arb.current, "notification");
        compare(arb.payload.key, "n1");
    }
}

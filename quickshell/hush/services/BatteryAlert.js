.pragma library
// The low-battery threshold to announce now: the lowest one at or above `percent` that is below the
// last one announced (`alerted`; 101 after a charge), or -1. Dropping past two at once announces the lower.
function next(alerts, percent, alerted) {
    const hit = alerts.filter(a => percent <= a && a < alerted)
    return hit.length ? Math.min(...hit) : -1
}

// "1 h 05 min" / "12 min" from seconds; "" when UPower has no estimate yet.
function left(secs) {
    if (!(secs > 0)) return ""
    const m = Math.round(secs / 60), h = Math.floor(m / 60)
    return h ? h + " h " + String(m % 60).padStart(2, "0") + " min" : m + " min"
}

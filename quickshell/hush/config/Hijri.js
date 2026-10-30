.pragma library
// Hijri date from the tabular Islamic calendar (Kuwaiti algorithm). Can differ by a day from a
// moon-sighting or Umm al-Qura date; QCalendar's IslamicCivil is C++ only, so this stays in JS.
const MONTHS = ["Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani", "Jumada al-Ula", "Jumada al-Akhirah",
    "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]

function convert(date) {
    const jdn = Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86400000) + 2440588
    let l = jdn - 1948440 + 10632
    const n = Math.floor((l - 1) / 10631)
    l = l - 10631 * n + 354
    const j = Math.floor((10985 - l) / 5316) * Math.floor(50 * l / 17719) + Math.floor(l / 5670) * Math.floor(43 * l / 15238)
    l = l - Math.floor((30 - j) / 15) * Math.floor(17719 * j / 50) - Math.floor(j / 16) * Math.floor(15238 * j / 43) + 29
    const m = Math.floor(24 * l / 709)
    return { day: l - Math.floor(709 * m / 24), month: m, year: 30 * n + j - 30 }
}

// The local Date of day hd in Hijri month hm (1..12) of year hy; months past 12 or below 1 roll the year.
function toDate(hy, hm, hd) {
    hy += Math.floor((hm - 1) / 12); hm = ((hm - 1) % 12 + 12) % 12 + 1
    const jdn = hd + Math.ceil(29.5 * (hm - 1)) + (hy - 1) * 354 + Math.floor((3 + 11 * hy) / 30) + 1948439
    const u = new Date((jdn - 2440588) * 86400000)
    return new Date(u.getUTCFullYear(), u.getUTCMonth(), u.getUTCDate())
}

function monthName(m) { return MONTHS[m - 1] }

function monthLength(hy, hm) { return Math.round((toDate(hy, hm + 1, 1) - toDate(hy, hm, 1)) / 86400000) }

// The Hijri months a Gregorian span covers: "Rabi al-Thani – Jumada al-Ula 1448", or one name, or
// "Dhu al-Hijjah 1447 – Muharram 1448" across a year.
function span(from, to) {
    const a = convert(from), b = convert(to)
    if (a.year === b.year && a.month === b.month) return MONTHS[a.month - 1] + " " + a.year
    if (a.year === b.year) return MONTHS[a.month - 1] + " – " + MONTHS[b.month - 1] + " " + b.year
    return MONTHS[a.month - 1] + " " + a.year + " – " + MONTHS[b.month - 1] + " " + b.year
}

// "19 Jumada al-Ula 1448"; withYear false gives "19 Jumada al-Ula". Named months, never "Jumada I":
// a Roman I reads as a divider bar in tracked capitals.
function format(date, withYear) {
    const h = convert(date)
    return h.day + " " + MONTHS[h.month - 1] + (withYear === false ? "" : " " + h.year)
}

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

// "19 Jumada al-Ula 1448"; withYear false gives "19 Jumada al-Ula". Named months, never "Jumada I":
// a Roman I reads as a divider bar in tracked capitals.
function format(date, withYear) {
    const h = convert(date)
    return h.day + " " + MONTHS[h.month - 1] + (withYear === false ? "" : " " + h.year)
}

import QtQuick
import Quickshell
import qs.config
import qs.services

// Calendar surface: a month grid (Monday first) with today in the primary colour, other-month days
// muted, prev/next month navigation. Click a day to select it (ring); days with reminders carry a dot.
// Under the grid: the selected day's reminders (time, text, remove; the first two) and one line to add
// one: a time (HH:MM) and a text, Enter or the + button.
Item {
    id: cal
    property size size: Sizes.calendar
    readonly property date today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property date selected: today
    readonly property var dayItems: Reminders.onDay(selected)
    // For tests: the day numbers of the visible grid that belong to the viewed month, and today's cell text.
    readonly property string todayText: grid.todayText
    readonly property string monthTitle: Qt.locale().monthName(viewMonth, Locale.LongFormat) + " " + viewYear

    function shift(d) {
        const m = viewMonth + d
        viewYear += Math.floor(m / 12); viewMonth = ((m % 12) + 12) % 12
    }
    function hhmm(ms) { const d = new Date(ms); return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes() }
    // Adds a reminder on the selected day at "HH:MM"; false for a bad time, an empty text or a past time.
    function addReminder(time, text) {
        const m = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(time.trim())
        if (!m) return false
        const d = selected
        return Reminders.add(new Date(d.getFullYear(), d.getMonth(), d.getDate(), +m[1], +m[2]).getTime(), text)
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property int cellH: 24

    Item {
        anchors.fill: parent; anchors.margins: 16

        Row {
            id: head
            width: parent.width; height: 28
            Text {
                width: parent.width - 56; height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: cal.monthTitle; color: Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Repeater {
                model: [{ g: "chevron_left", d: -1 }, { g: "chevron_right", d: 1 }]
                delegate: Rectangle {
                    required property var modelData
                    width: 28; height: 28; radius: 14
                    color: hit.containsMouse ? Colors.islandSurfaceHigh : "transparent"
                    Text {
                        anchors.centerIn: parent; text: modelData.g; color: Colors.islandFgVar
                        font.family: Theme.fontIcon; font.pixelSize: 20
                    }
                    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: cal.shift(modelData.d); Accessible.role: Accessible.Button; Accessible.name: modelData.d < 0 ? "Previous month" : "Next month" }
                }
            }
        }

        Grid {
            id: grid
            anchors.top: head.bottom; anchors.topMargin: 6
            width: parent.width; columns: 7
            readonly property real cw: width / 7
            // Monday-first: offset of the 1st, then six rows of dates from the grid's first cell.
            readonly property date first: new Date(cal.viewYear, cal.viewMonth, 1)
            readonly property int lead: (first.getDay() + 6) % 7
            property string todayText: ""
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                delegate: Text {
                    required property string modelData
                    width: grid.cw; height: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: modelData; color: Colors.islandFgVar; opacity: 0.7
                    font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
                }
            }
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property date d: new Date(cal.viewYear, cal.viewMonth, 1 - grid.lead + index)
                    readonly property bool inMonth: d.getMonth() === cal.viewMonth
                    readonly property bool isToday: d.getTime() === cal.today.getTime()
                    readonly property bool isSelected: d.getTime() === cal.selected.getTime()
                    // Reads Reminders.items so the dot follows adds and removes.
                    readonly property bool hasReminder: Reminders.items.length > 0 && Reminders.onDay(d).length > 0
                    objectName: hasReminder ? "reminderDot" : ""
                    onIsTodayChanged: if (isToday) grid.todayText = String(d.getDate())
                    Component.onCompleted: if (isToday) grid.todayText = String(d.getDate())
                    width: grid.cw; height: cal.cellH
                    Rectangle {
                        anchors.centerIn: parent; width: Math.min(parent.width, parent.height) - 2; height: width; radius: width / 2
                        color: Colors.islandPrimary; visible: parent.isToday
                    }
                    Rectangle {
                        anchors.centerIn: parent; width: Math.min(parent.width, parent.height) - 2; height: width; radius: width / 2
                        color: "transparent"; border.width: 1.5; border.color: Colors.islandPrimary
                        visible: parent.isSelected && !parent.isToday
                    }
                    Text {
                        anchors.centerIn: parent; text: parent.d.getDate()
                        color: parent.isToday ? Colors.islandOnPrimary : Colors.islandFg
                        opacity: parent.isToday || parent.inMonth ? 1 : 0.32
                        font.family: Theme.fontUi; font.pixelSize: 13
                        font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                    Rectangle {
                        visible: parent.hasReminder
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                        width: 4; height: 4; radius: 2
                        color: parent.isToday ? Colors.islandOnPrimary : Colors.islandPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        Accessible.role: Accessible.Button; Accessible.name: "Select " + parent.d.toDateString()
                        onClicked: cal.selected = parent.d
                    }
                }
            }
        }

        Column {
            anchors.bottom: parent.bottom; width: parent.width; spacing: 4
            Repeater {
                model: cal.dayItems.slice(0, 2)
                delegate: Item {
                    required property var modelData
                    objectName: "reminderRow"
                    width: parent.width; height: 22
                    Text {
                        id: rt
                        anchors.verticalCenter: parent.verticalCenter; text: cal.hhmm(modelData.at)
                        color: Colors.islandPrimary; font.family: Theme.fontMono; font.pixelSize: 12
                    }
                    Text {
                        anchors { left: rt.right; leftMargin: 10; right: rm.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: modelData.text; elide: Text.ElideRight; color: Colors.islandFg
                        font.family: Theme.fontUi; font.pixelSize: 12
                    }
                    Item {
                        id: rm
                        objectName: "reminderRemove"
                        anchors.right: parent.right; width: 22; height: 22
                        Text { anchors.centerIn: parent; text: "close"; color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 16 }
                        MouseArea { anchors.fill: parent; onClicked: Reminders.remove(modelData.id); Accessible.role: Accessible.Button; Accessible.name: "Remove reminder" }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 34; radius: 17; color: Colors.islandSurfaceHigh
                Text {
                    id: alarm
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "alarm"; color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18
                }
                TextInput {
                    id: timeIn
                    objectName: "reminderTime"
                    anchors { left: alarm.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 40; text: "09:00"; color: Colors.islandPrimary; clip: true
                    font.family: Theme.fontMono; font.pixelSize: 13
                    selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                    Accessible.role: Accessible.EditableText; Accessible.name: "Reminder time"
                    KeyNavigation.tab: textIn
                }
                TextInput {
                    id: textIn
                    objectName: "reminderText"
                    anchors { left: timeIn.right; leftMargin: 10; right: add.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    color: Colors.islandFg; clip: true
                    font.family: Theme.fontUi; font.pixelSize: 13
                    selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                    Accessible.role: Accessible.EditableText; Accessible.name: "Reminder text"
                    Text { visible: !parent.text; text: "Remind me to…"; color: Colors.islandFgVar; opacity: 0.6; font: parent.font }
                    onAccepted: add.submit()
                }
                Item {
                    id: add
                    objectName: "reminderAdd"
                    anchors.right: parent.right; width: 34; height: 34
                    function submit() { if (cal.addReminder(timeIn.text, textIn.text)) textIn.text = "" }
                    Text { anchors.centerIn: parent; text: "add"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 20 }
                    MouseArea { anchors.fill: parent; onClicked: add.submit(); Accessible.role: Accessible.Button; Accessible.name: "Add reminder" }
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Calendar surface: a month grid (Monday first) with today in the primary colour,
// other-month days muted, prev/next month navigation, and an "Upcoming" list from
// `khal list today 7d` when khal is installed (the list is hidden otherwise).
Item {
    id: cal
    property size size: Sizes.calendar
    readonly property date today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property var upcoming: []
    readonly property bool hasUpcoming: upcoming.length > 0
    // For tests: the day numbers of the visible grid that belong to the viewed month, and today's cell text.
    readonly property string todayText: grid.todayText
    readonly property string monthTitle: Qt.locale().monthName(viewMonth, Locale.LongFormat) + " " + viewYear

    function shift(d) {
        const m = viewMonth + d
        viewYear += Math.floor(m / 12); viewMonth = ((m % 12) + 12) % 12
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Process {
        id: khal
        command: ["sh", "-c", "command -v khal >/dev/null 2>&1 && khal list today 7d 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: cal.upcoming = text.split("\n").map(l => l.trim()).filter(l => l.length > 0).slice(0, 6)
        }
    }
    Timer { interval: 600000; running: true; repeat: true; onTriggered: khal.running = true }

    readonly property int cellH: hasUpcoming ? 26 : 32

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
                    onIsTodayChanged: if (isToday) grid.todayText = String(d.getDate())
                    Component.onCompleted: if (isToday) grid.todayText = String(d.getDate())
                    width: grid.cw; height: cal.cellH
                    Rectangle {
                        anchors.centerIn: parent; width: Math.min(parent.width, parent.height) - 2; height: width; radius: width / 2
                        color: Colors.islandPrimary; visible: parent.isToday
                    }
                    Text {
                        anchors.centerIn: parent; text: parent.d.getDate()
                        color: parent.isToday ? Colors.islandOnPrimary : Colors.islandFg
                        opacity: parent.isToday || parent.inMonth ? 1 : 0.32
                        font.family: Theme.fontUi; font.pixelSize: 13
                        font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        Column {
            visible: cal.hasUpcoming
            anchors.bottom: parent.bottom; width: parent.width; spacing: 1
            Text {
                text: "Upcoming"; color: Colors.islandFgVar; opacity: 0.7
                font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
            }
            Repeater {
                model: cal.upcoming.slice(0, 3)
                delegate: Text {
                    required property string modelData
                    width: parent.width; elide: Text.ElideRight; text: modelData; color: Colors.islandFg
                    font.family: Theme.fontUi; font.pixelSize: 12
                }
            }
        }
    }
}

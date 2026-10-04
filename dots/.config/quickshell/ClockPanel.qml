// ClockPanel.qml -- calendar in the grown notch.
//   left   month grid (Monday first, 󰅁 󰅂 or scroll the header to change month, click the title = back to
//          today). Click a day to select it. Marks under a day: coral = public holiday, grey = observance,
//          amber = your reminder / alarm.
//   right  three tabs:
//          Day     (centred) the selected day: number, weekday + month, live time (today) or "in 6 days",
//                  week / day of year, its holidays and your reminders / alarms (hover one: × deletes it);
//                  "+ event, reminder or alarm" opens the Add tab.
//          Upcoming everything coming up (events, reminders, alarms) (click = show that day, × = delete) + "new" (on the selected day)
//          Timer   presets 1-60 min or any minutes; pause / resume / cancel
//          Weather weather now + the next 4 days (Weather.qml; the place is set in Settings > Date & language)
//          Add     the form: text, date (type it, click a day on the left, Today / Tomorrow), time,
//                  Event (time empty = all day; never rings) / Reminder / Alarm, Once / Daily / Yearly;
//                  Enter = add (then shows Upcoming), Esc = back
//          While an alarm or timer rings, the right side shows it with Snooze (timer: +1 min) and Stop.
// Data + firing: Agenda.qml (holidays = India, Google's public calendar; items in agenda.json).
import QtQuick
import Quickshell

Item {
    id: root
    SystemClock { id: clock; precision: SystemClock.Seconds }   // seconds only while the panel is open
    readonly property date now: clock.date
    property int offset: 0                                       // months away from the current one
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    property date selected: new Date()
    readonly property bool adding: tab === "add"
    property string tab: "day"                                   // right side: day | alarms | timer | weather | add
    property string menu: ""                                      // open submenu of the toolbar: "" | rec | shot
    signal done()
    // Record / Screenshot: the notch closes first so it is not in the picture, then the same scripts the keys use
    function capture(kind, mode) {
        const bin = Quickshell.env("HOME") + "/.local/bin/" + (kind === "rec" ? "rice-record" : "rice-shot")
        root.done()
        Quickshell.execDetached(["sh", "-c", "sleep 0.5; exec \"$0\" \"$@\"", bin, mode])
    }
    // (no `busy`: the notch closes on hover-off like every panel, and always reopens on Day)
    readonly property int wantHeight: adding ? 372 : 0                // the add form needs more room
    readonly property int wantWidth: 980                              // wider than the resting notch: five tabs (Day, Next, Timer, Weather, Add)

    // 42 cells starting on the Monday on/before the 1st
    readonly property var cells: {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1)
        const lead = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) out.push(new Date(shown.getFullYear(), shown.getMonth(), 1 - lead + i))
        return out
    }
    readonly property int weeks: cells[35].getMonth() === shown.getMonth() ? 6 : 5
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }
    function dayOfYear(d) { return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1 }
    function daysFromToday(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000)
    }
    function relative(d) {
        const n = daysFromToday(d)
        return n === 1 ? "tomorrow" : n === -1 ? "yesterday" : n > 0 ? "in " + n + " days" : -n + " days ago"
    }
    function pick(d) {
        selected = d
        if (tab === "add") dateBox.input.text = Agenda.key(d)   // adding: a clicked day becomes its date
        else tab = "day"
        offset = (d.getFullYear() - now.getFullYear()) * 12 + d.getMonth() - now.getMonth()
    }
    readonly property bool selToday: sameDay(selected, now)
    readonly property var selHolidays: Agenda.holidaysOn(selected)
    readonly property var selItems: { Agenda.items; return Agenda.itemsOn(selected) }   // re-read when items change

    Row {
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14

        Card {
            id: cal
            width: (parent.width - parent.spacing) * 0.58; height: parent.height
            spacing: 4
            Item {
                width: parent.width; height: 24
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.shown, "MMMM yyyy").toUpperCase()
                    color: root.offset === 0 ? Theme.text : Theme.amber
                    font.family: Theme.font; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(new Date()) }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: [["󰅁", -1], ["󰅂", 1]]
                        delegate: Rectangle {
                            required property var modelData
                            width: 26; height: 22; radius: 2; KeyEdge {}
                            color: nav.containsMouse ? Theme.raised : "transparent"
                            Text { anchors.centerIn: parent; text: modelData[0]; color: Theme.text; font.family: Theme.font; font.pixelSize: 15; font.bold: true }
                            MouseArea { id: nav; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.offset += modelData[1] }
                        }
                    }
                }
                // scroll over the header = change month
                WheelHandler { onWheel: (w) => root.offset += (w.angleDelta.y > 0 ? -1 : 1) }
            }
            Grid {
                columns: 7
                width: parent.width
                readonly property real cw: width / 7
                readonly property real ch: (cal.height - 2 * cal.pad - 24 - 4) / (root.weeks + 1)
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Text {
                        required property var modelData
                        width: parent.cw; height: parent.ch
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: modelData; color: Theme.dim
                        font.family: Theme.font; font.pixelSize: 11
                    }
                }
                Repeater {
                    model: root.cells.slice(0, root.weeks * 7)
                    delegate: Item {
                        id: cell
                        required property var modelData
                        width: parent.cw; height: parent.ch
                        readonly property bool inMonth: modelData.getMonth() === root.shown.getMonth()
                        readonly property bool today: root.sameDay(modelData, root.now)
                        readonly property bool picked: root.sameDay(modelData, root.selected)
                        readonly property var hols: Agenda.holidaysOn(modelData)
                        readonly property bool pub: hols.some(h => h.pub)
                        readonly property var mineList: { Agenda.items; return Agenda.itemsOn(modelData) }
                        readonly property bool events: mineList.some(i => i.kind === "event")
                        readonly property bool alerts: mineList.some(i => i.kind !== "event")
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 6, 34); height: Math.min(parent.height - 2, 26); radius: 2
                            color: cell.today ? Theme.coral : (cm.containsMouse ? Theme.raised : "transparent")
                            border.width: cell.picked && !cell.today ? 1 : 0
                            border.color: Theme.coral
                        }
                        Text {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -2
                            text: cell.modelData.getDate()
                            color: cell.today ? Theme.bg : (!cell.inMonth ? Theme.dim : (cell.pub ? Theme.coral : Theme.text))
                            font.family: Theme.font; font.pixelSize: 12; font.bold: cell.today || cell.pub
                        }
                        Row {   // marks: holiday / observance / your reminder
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 8
                            spacing: 3
                            opacity: cell.inMonth ? 1 : 0.4
                            Rectangle { visible: cell.hols.length > 0; width: 4; height: 4; radius: 2; color: cell.today ? Theme.bg : (cell.pub ? Theme.coral : Theme.muted) }
                            Rectangle { visible: cell.events; width: 4; height: 4; radius: 2; color: cell.today ? Theme.bg : Theme.text }
                            Rectangle { visible: cell.alerts; width: 4; height: 4; radius: 2; color: cell.today ? Theme.bg : Theme.amber }
                        }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(cell.modelData) }
                    }
                }
            }
        }

        Rectangle {
            id: dayCard
            width: (parent.width - parent.spacing) * 0.42; height: parent.height
            radius: 12; color: Theme.surface
            clip: true                                   // a very full day never spills out

            // ---------- the toolbar: pages | switches and capture. Icons only, the name shows on hover ----------
            Row {
                id: tabs
                visible: !Agenda.ringing
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                spacing: 3
                readonly property var ids: ["day", "alarms", "timer", "weather", "add"]
                readonly property var glyphs: ["󰃭", "󰃱", "󱎫", "󰖕", "󰐕"]
                readonly property var names: ["Day", "Next", "Timer", "Weather", "New"]
                Repeater {
                    model: 5
                    delegate: IconKey {
                        required property int index
                        glyph: tabs.glyphs[index]; tip: tabs.names[index]
                        on: root.tab === tabs.ids[index]
                        onClicked: { root.menu = ""; tabs.ids[index] === "add" ? root.openForm() : root.tab = tabs.ids[index] }
                    }
                }
                Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Theme.hover }
                IconKey { glyph: "󰅶"; tip: Modes.awake ? "Keep awake: on" : "Keep awake"; on: Modes.awake; led: true
                          onClicked: { root.menu = ""; Modes.setAwake(!Modes.awake) } }
                IconKey { glyph: "󰊴"; tip: Modes.game ? "Game mode: on" : "Game mode"; on: Modes.game; led: true
                          onClicked: { root.menu = ""; Modes.setGame(!Modes.game) } }
                IconKey { id: recKey; glyph: Recorder.on ? "󰓛" : "󰑋"; tip: Recorder.on ? "Stop recording" : "Record"; hot: Recorder.on; menu: !Recorder.on
                          onClicked: Recorder.on ? Recorder.stop() : (root.menu = root.menu === "rec" ? "" : "rec") }
                IconKey { id: shotKey; glyph: "󰹑"; tip: "Screenshot"; menu: true
                          onClicked: root.menu = root.menu === "shot" ? "" : "shot" }
            }
            // submenu of Record / Screenshot: small, icon + short name
            Rectangle {
                id: sub
                visible: root.menu !== "" && !Agenda.ringing
                z: 30
                readonly property var items: root.menu === "rec"
                    ? [["󰍹", "Screen", "screen"], ["󰩭", "Area", "region"], ["󰕾", "Screen + sound", "sound"]]
                    : [["󰩭", "Area", "area"], ["󰖲", "Window", "window"], ["󰍹", "Screen", "screen"], ["󰏫", "Draw on it", "edit"]]
                readonly property Item anchorKey: root.menu === "rec" ? recKey : shotKey
                x: Math.min(parent.width - width - 8, tabs.x + anchorKey.x + anchorKey.width - width)
                y: tabs.y + 36
                width: 150; height: col.implicitHeight + 8; radius: 3
                color: Theme.surface; border.width: 1; border.color: Theme.hover
                Column {
                    id: col
                    x: 4; y: 4; width: parent.width - 8
                    Repeater {
                        model: sub.items
                        delegate: Rectangle {
                            required property var modelData
                            width: col.width; height: 24; radius: 2
                            color: mi.containsMouse ? Theme.hover : "transparent"
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 8
                                Text { text: modelData[0]; color: Theme.coral; font.family: Theme.font; font.pixelSize: 14 }
                                Text { text: modelData[1]; color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
                            }
                            MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.capture(root.menu, modelData[2]); root.menu = "" } }
                        }
                    }
                }
            }

            // ---------- the selected day (centred) ----------
            Column {
                id: info
                visible: !root.adding && root.tab === "day" && !Agenda.ringing
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(52, (parent.height - height) / 2 + 20)      // centred below the tabs; top when full
                width: parent.width - 36
                spacing: 4
                readonly property bool compact: root.selHolidays.length + root.selItems.length >= 2   // many rows: smaller header
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.selected.getDate()
                    color: root.selToday ? Theme.coral : Theme.text
                    font.family: Theme.font; font.pixelSize: info.compact ? 26 : 40; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(root.selected, root.selected.getFullYear() === root.now.getFullYear() ? "dddd, MMMM" : "dddd, MMMM yyyy")
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.selToday ? "󰥔 " + Qt.formatTime(root.now, "HH:mm:ss") : root.relative(root.selected)
                    color: root.selToday ? Theme.text : Theme.amber
                    font.family: Theme.font; font.pixelSize: root.selToday ? 16 : 13
                }
                Text {   // today's weather, one line (click = the weather tab)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.selToday && Weather.ok && !info.compact
                    text: Weather.icon(Weather.now.code, Weather.now.day) + " " + Weather.deg(Weather.now.temp)
                    color: wl.containsMouse ? Theme.amber : Theme.coral; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                    MouseArea { id: wl; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = "weather" }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !info.compact || root.selHolidays.length + root.selItems.length < 3
                    text: "󰃭 w" + root.isoWeek(root.selected) + " · d" + root.dayOfYear(root.selected) + " · " + Qt.formatDate(root.selected, "yyyy")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
                Item { width: 1; height: 6 }

                // holidays of the day
                Repeater {
                    model: root.selHolidays
                    delegate: Text {
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, info.width); elide: Text.ElideRight
                        text: (modelData.pub ? "󰃰  " : "󰃭  ") + modelData.name
                        color: modelData.pub ? Theme.coral : Theme.muted
                        font.family: Theme.font; font.pixelSize: 12; font.bold: modelData.pub
                    }
                }
                // your reminders / alarms (hover = × to delete)
                Repeater {
                    model: root.selItems
                    delegate: Item {
                        id: it
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(itRow.implicitWidth + 22, info.width); height: 18
                        MouseArea { id: im; anchors.fill: parent; hoverEnabled: true }
                        Row {
                            id: itRow
                            width: Math.min(implicitWidth, it.width - 22)
                            spacing: 6
                            Text { text: root.glyphOf(it.modelData); color: root.tintOf(it.modelData); font.family: Theme.font; font.pixelSize: 13 }
                            Text { text: it.modelData.time || "all day"; color: root.tintOf(it.modelData); font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                            Text {
                                width: Math.min(implicitWidth, info.width - 100); elide: Text.ElideRight
                                text: it.modelData.text + (it.modelData.repeat !== "once" ? "  󰑖" : "")
                                color: Theme.text; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            visible: im.containsMouse || xm.containsMouse
                            text: "󰅖"; color: xm.containsMouse ? Theme.coral : Theme.muted
                            font.family: Theme.font; font.pixelSize: 13
                            MouseArea { id: xm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.remove(it.modelData.id) }
                        }
                    }
                }
                Item { width: 1; height: 4 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.daysFromToday(root.selected) >= 0
                    text: "+ event, reminder or alarm"
                    color: am.containsMouse ? Theme.amber : Theme.muted
                    font.family: Theme.font; font.pixelSize: 12
                    MouseArea { id: am; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openForm() }
                }
            }

            // ---------- weather: now + the next days ----------
            Column {
                id: weatherTab
                visible: !root.adding && root.tab === "weather" && !Agenda.ringing
                x: 18; y: 54
                width: parent.width - 36
                spacing: 6
                Column {   // no place yet / offline
                    visible: !Weather.ok
                    width: parent.width
                    spacing: 10
                    Item { width: 1; height: 30 }
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                        text: !Weather.wanted ? "No place set for the weather yet." : (Weather.error || "Loading…")
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 13
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !Weather.wanted ? "Pick your city in Settings ›" : "Try again ↻"
                        color: wp.containsMouse ? Theme.amber : Theme.coral; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                        MouseArea {
                            id: wp; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Weather.wanted ? Weather.refresh() : Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "region"])
                        }
                    }
                }
                Row {   // now: big icon + temperature, words + details
                    visible: Weather.ok
                    spacing: 14
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.icon(Weather.now.code, Weather.now.day)
                        color: Theme.coral; font.family: Theme.font; font.pixelSize: 44
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text { text: Weather.deg(Weather.now.temp ?? 0); color: Theme.text; font.family: Theme.font; font.pixelSize: 30; font.bold: true }
                        Text { text: Weather.words(Weather.now.code); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: "feels " + Weather.deg(Weather.now.feels ?? 0); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Text { text: "󰖎 " + (Weather.now.humidity ?? "–") + "%   󰖝 " + Math.round(Weather.now.wind ?? 0) + " " + (Weather.now.windUnit || ""); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Text { text: "󰖜 " + (Weather.sun.rise || "–") + "   󰖛 " + (Weather.sun.set || "–"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }
                Item { visible: Weather.ok; width: 1; height: 4 }
                Row {   // the next 4 days
                    visible: Weather.ok
                    width: parent.width
                    Repeater {
                        model: Weather.days.slice(1, 5)
                        delegate: Column {
                            required property var modelData
                            width: weatherTab.width / 4
                            spacing: 3
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.icon(modelData.code, true); color: Theme.text; font.family: Theme.font; font.pixelSize: 20 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.deg(modelData.max) + " " + Weather.deg(modelData.min); color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; visible: modelData.rain !== null && modelData.rain >= 20; text: "󰖗 " + modelData.rain + "%"; color: Theme.amber; font.family: Theme.font; font.pixelSize: 10 }
                        }
                    }
                }
                Text {
                    visible: Weather.ok
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: Weather.w.name + " · " + Qt.formatTime(new Date(Weather.updated), "HH:mm") + " · Open-Meteo"
                    color: Theme.dim; font.family: Theme.font; font.pixelSize: 10
                }
            }

            // ---------- all upcoming reminders / alarms ----------
            Column {
                id: alarmsTab
                visible: !root.adding && root.tab === "alarms" && !Agenda.ringing
                x: 18; y: 54
                width: parent.width - 36
                height: parent.height - y - 14
                spacing: 6
                readonly property var upcoming: {
                    const nowK = Agenda.key(root.now)
                    return Agenda.items.filter(i => i.repeat !== "once" || i.date > nowK
                                                     || (i.date === nowK && (i.kind === "event" || i.last !== nowK)))
                        .sort((a, b) => (Agenda.key(root.nextDate(a)) + a.time).localeCompare(Agenda.key(root.nextDate(b)) + b.time))
                }
                ScrollList {
                    id: upList
                    width: parent.width
                    height: parent.height - 24
                    model: alarmsTab.upcoming
                    delegate: Rectangle {
                        id: up
                        required property var modelData
                        width: ListView.view.width - ListView.view.rightMargin
                        height: 38; radius: 2; KeyEdge {}
                        color: um.containsMouse || ux.containsMouse ? Theme.raised : "transparent"
                        MouseArea {   // click = show that day in the calendar
                            id: um; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: if (up.modelData.repeat !== "daily") root.pick(new Date(up.modelData.date + "T00:00:00"))
                        }
                        Text {
                            id: upIcon
                            x: 8; anchors.verticalCenter: parent.verticalCenter
                            text: root.glyphOf(up.modelData)
                            color: root.tintOf(up.modelData); font.family: Theme.font; font.pixelSize: 16
                        }
                        Column {
                            anchors.left: upIcon.right; anchors.leftMargin: 10
                            anchors.right: upX.left; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: (up.modelData.time || "all day") + "  " + up.modelData.text
                                color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true
                            }
                            Text {
                                text: (up.modelData.repeat === "daily" ? "every day"
                                    : (up.modelData.repeat === "yearly" ? "every year · " : "")
                                      + Qt.formatDate(root.nextDate(up.modelData), "ddd d MMM") + " · " + root.relative(root.nextDate(up.modelData)).replace("0 days ago", "today"))
                                    + " · " + up.modelData.kind
                                color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                            }
                        }
                        Text {
                            id: upX
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            text: "󰅖"; opacity: um.containsMouse || ux.containsMouse ? 1 : 0
                            color: ux.containsMouse ? Theme.coral : Theme.muted
                            font.family: Theme.font; font.pixelSize: 14
                            MouseArea { id: ux; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.remove(up.modelData.id) }
                        }
                    }
                    Text {
                        parent: upList
                        visible: upList.count === 0
                        anchors.centerIn: parent
                        text: "Nothing coming up"
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "+ new event, reminder or alarm"
                    color: nm.containsMouse ? Theme.amber : Theme.muted
                    font.family: Theme.font; font.pixelSize: 12
                    MouseArea { id: nm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openForm() }
                }
            }

            // ---------- countdown timer ----------
            Column {
                id: timerTab
                visible: !root.adding && root.tab === "timer" && !Agenda.ringing
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 20
                width: parent.width - 36
                spacing: 10
                readonly property real remaining: Agenda.timerPaused ? Agenda.timerLeft
                                           : (Agenda.timerEnd > 0 ? Math.max(0, Agenda.timerEnd - root.now.getTime()) : 0)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Agenda.timerOn ? Agenda.fmt(timerTab.remaining) : "0:00"
                    color: Agenda.timerPaused ? Theme.amber : (Agenda.timerOn ? Theme.coral : Theme.dim)
                    font.family: Theme.font; font.pixelSize: 40; font.bold: true
                }
                LedBar {   // progress (retro LED segments; all amber while paused)
                    width: parent.width; segH: 10
                    frac: Agenda.timerTotal > 0 && Agenda.timerOn ? timerTab.remaining / Agenda.timerTotal : 0
                    safeFrac: Agenda.timerPaused ? 0 : 1
                }
                // not running: presets + custom minutes
                Flow {
                    visible: !Agenda.timerOn
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: [1, 5, 10, 15, 25, 30, 45, 60]
                        delegate: Rectangle {
                            required property int modelData
                            width: (timerTab.width - 3 * 6) / 4; height: 28; radius: 2; KeyEdge {}
                            color: pm.containsMouse ? Theme.hover : Theme.raised
                            Text { anchors.centerIn: parent; text: modelData + " min"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.startTimer(modelData * 60, "") }
                        }
                    }
                }
                Row {
                    visible: !Agenda.timerOn
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Box { id: minBox; width: 150; hint: "minutes, e.g. 7.5" }
                    Rectangle {
                        width: 70; height: 32; radius: 2; KeyEdge {}
                        color: sm.containsMouse ? Theme.amber : Theme.coral
                        Text { anchors.centerIn: parent; text: "Start"; color: Theme.bg; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startCustom() }
                    }
                }
                // running / paused
                Row {
                    visible: Agenda.timerOn
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Rectangle {
                        width: 90; height: 30; radius: 2; KeyEdge {}
                        color: pr.containsMouse ? Theme.hover : Theme.raised
                        Text { anchors.centerIn: parent; text: Agenda.timerPaused ? "Resume" : "Pause"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: pr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.timerPaused ? Agenda.resumeTimer() : Agenda.pauseTimer() }
                    }
                    Rectangle {
                        width: 90; height: 30; radius: 2; KeyEdge {}
                        color: cn.containsMouse ? Qt.alpha(Theme.warn, 0.25) : Theme.raised
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.warn; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: cn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.cancelTimer() }
                    }
                }
                Text {
                    visible: Agenda.snoozeAt > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "alarm snoozed until " + Qt.formatTime(new Date(Agenda.snoozeAt), "HH:mm")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                }
            }

            // ---------- ringing: stop / snooze ----------
            Column {
                visible: Agenda.ringing
                anchors.centerIn: parent
                width: parent.width - 36
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Agenda.ringKind === "timer" ? "󱎫" : "󰀠"
                    color: Theme.coral; font.family: Theme.font; font.pixelSize: 44
                    SequentialAnimation on opacity {   // gentle pulse while ringing
                        running: Agenda.ringing; loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Agenda.ringTitle
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 15; font.bold: true
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: Agenda.ringText
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
                Item { width: 1; height: 4 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Rectangle {
                        width: 110; height: 34; radius: 2; KeyEdge {}
                        color: zm.containsMouse ? Theme.hover : Theme.raised
                        Text { anchors.centerIn: parent; text: Agenda.ringKind === "timer" ? "+1 min" : "Snooze 5 min"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.snooze() }
                    }
                    Rectangle {
                        width: 110; height: 34; radius: 2; KeyEdge {}
                        color: tm.containsMouse ? Theme.amber : Theme.coral
                        Text { anchors.centerIn: parent; text: "Stop"; color: Theme.bg; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.stop() }
                    }
                }
            }

            // ---------- add a reminder / alarm ----------
            Column {
                id: form
                visible: root.adding && !Agenda.ringing
                x: 18; y: 54
                width: parent.width - 36
                spacing: 8
                property int kind: 0          // 0 reminder, 1 alarm
                property int rep: 0           // 0 once, 1 daily
                property string error: ""
                Box { id: textBox; hint: "What is it? (e.g. call mom)" }
                Row {   // date: type it, click a day on the left, or Today / Tomorrow
                    spacing: 6
                    Box { id: dateBox; width: 110; hint: "YYYY-MM-DD" }
                    Repeater {
                        model: [["Today", 0], ["Tomorrow", 1]]
                        delegate: Rectangle {
                            required property var modelData
                            width: qd.implicitWidth + 16; height: 32; radius: 2; KeyEdge {}
                            color: qm.containsMouse ? Theme.hover : Theme.raised
                            Text { id: qd; anchors.centerIn: parent; text: modelData[0]; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                            MouseArea {
                                id: qm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate() + modelData[1]))
                            }
                        }
                    }
                }
                Row {
                    spacing: 8
                    Box { id: timeBox; width: 80; hint: "HH:MM" }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: form.width - 88; wrapMode: Text.Wrap
                        text: form.error !== "" ? form.error
                            : (form.rep === 1 ? "every day from " : form.rep === 2 ? "every year from " : "on ") + root.dateLabel(dateBox.input.text)
                              + (form.kind === 0 && timeBox.input.text.trim() === "" ? ", all day" : "")
                        color: form.error !== "" ? Theme.warn : Theme.muted
                        font.family: Theme.font; font.pixelSize: 11
                    }
                }
                Seg { options: ["󰃶 Event", "󰃀 Reminder", "󰀠 Alarm"]; current: form.kind; onPicked: (i) => form.kind = i }
                Seg { options: ["Once", "Daily", "Yearly"]; current: form.rep; onPicked: (i) => form.rep = i }
                Row {
                    spacing: 8
                    Rectangle {
                        width: 80; height: 30; radius: 2; KeyEdge {}
                        color: cx.containsMouse ? Theme.hover : Theme.raised
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: cx; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = "day" }
                    }
                    Rectangle {
                        width: 80; height: 30; radius: 2; KeyEdge {}
                        color: ax.containsMouse ? Theme.amber : Theme.coral
                        Text { anchors.centerIn: parent; text: "Add"; color: Theme.bg; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: ax; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                    }
                }
            }
        }
    }

    component Box: Rectangle {
        id: box
        property alias input: ti
        property string hint: ""
        width: parent.width; height: 32; radius: 2; KeyEdge {}
        color: Theme.raised
        border.width: 1; border.color: ti.activeFocus ? Theme.coral : "transparent"
        TextInput {
            id: ti
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            clip: true; selectByMouse: true
            color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4)
            font.family: Theme.font; font.pixelSize: 13
            Keys.onReturnPressed: box === minBox ? root.startCustom() : root.submit()
            Keys.onEnterPressed: box === minBox ? root.startCustom() : root.submit()
            Keys.onEscapePressed: root.tab = "day"
            Keys.onTabPressed: root.nextField(ti)
            Text { visible: !ti.text; anchors.verticalCenter: parent.verticalCenter; text: box.hint; color: Theme.dim; font: ti.font }
        }
    }

    function startCustom() {
        const m = parseFloat(minBox.input.text.replace(",", "."))
        if (!(m > 0)) { minBox.input.text = ""; minBox.input.forceActiveFocus(); return }
        Agenda.startTimer(Math.round(m * 60), "")
        minBox.input.text = ""
    }
    function nextField(f) { (f === textBox.input ? dateBox.input : f === dateBox.input ? timeBox.input : textBox.input).forceActiveFocus() }
    function openForm() {
        textBox.input.text = ""
        // default time: the next full hour (today) or 09:00 (another day)
        timeBox.input.text = root.selToday ? Agenda.pad((now.getHours() + 1) % 24) + ":00" : "09:00"
        dateBox.input.text = Agenda.key(root.selected)
        form.kind = 0; form.rep = 0; form.error = ""          // default: an event, once
        tab = "add"
        Qt.callLater(() => textBox.input.forceActiveFocus())
    }
    function submit() {
        const kind = ["event", "reminder", "alarm"][form.kind]
        const raw = timeBox.input.text.trim()
        let t = ""                                  // "" = all day (events only)
        if (raw !== "" || kind !== "event") {
            const m = raw.match(/^(\d{1,2})[:.]?(\d{2})$/)
            if (!m || parseInt(m[1]) > 23 || parseInt(m[2]) > 59) { form.error = kind === "event" ? "time like 07:30, or empty = all day" : "time like 07:30"; return }
            t = Agenda.pad(parseInt(m[1])) + ":" + m[2]
        }
        const d = parseDate(dateBox.input.text)
        if (!d) { form.error = "date like 2026-10-02"; return }
        if (kind !== "event" && form.rep === 0 && new Date(Agenda.key(d) + "T" + t + ":00") < new Date()) { form.error = "that time has passed"; return }
        Agenda.add(d, t, textBox.input.text.trim(), kind, ["once", "daily", "yearly"][form.rep])
        tab = "alarms"                              // show it in the list
    }
    function glyphOf(i) { return i.kind === "alarm" ? "󰀠" : i.kind === "event" ? "󰃶" : "󰃀" }
    function tintOf(i) { return i.kind === "event" ? Theme.text : Theme.amber }
    // the next day an item shows (today for daily; this or next year for yearly)
    function nextDate(i) {
        const t = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const d = new Date(i.date + "T00:00:00")
        if (i.repeat === "daily") return d > t ? d : t
        if (i.repeat === "yearly") {
            if (d > t) return d
            const y = new Date(t.getFullYear(), d.getMonth(), d.getDate())
            return y >= t ? y : new Date(t.getFullYear() + 1, d.getMonth(), d.getDate())
        }
        return d
    }
    // "2026-10-02" (also 2026-10-2, 2026/10/02) -> Date, or null
    function parseDate(t) {
        const m = t.trim().match(/^(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})$/)
        if (!m) return null
        const d = new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
        return d.getMonth() === parseInt(m[2]) - 1 ? d : null
    }
    function dateLabel(t) {
        const d = parseDate(t)
        return d ? Qt.formatDate(d, "ddd d MMM") + " (" + relative(d).replace("in 0 days", "today").replace("0 days ago", "today") + ")" : "…"
    }
}

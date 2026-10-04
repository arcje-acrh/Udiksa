// ClockDemo.qml -- DEMO of the redesigned general panel:
//   a rail of small buttons on the left: modes (keep awake, game mode, record, screenshot) and creators (timer,
//   alarm, reminder, event); the calendar as a tall tile; one big tile with the date, its weather and its events.
//   Record / screenshot / timer / alarm / reminder / event open a small popover next to the rail.
// Open with `qs ipc call notch open clockA`. Temporary: the final version replaces ClockPanel.qml.
import QtQuick
import Quickshell

Item {
    id: root
    readonly property int wantWidth: 980
    readonly property int wantHeight: 232
    signal done()

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    property int offset: 0
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    property date selected: new Date()
    property string page: "day"            // the today card: day | next | weather
    property string menu: ""               // open submenu: "" | rec | shot

    readonly property var cells: {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1), lead = (first.getDay() + 6) % 7, out = []
        for (let i = 0; i < 42; i++) out.push(new Date(shown.getFullYear(), shown.getMonth(), 1 - lead + i))
        return out
    }
    readonly property int weeks: cells[35].getMonth() === shown.getMonth() ? 6 : 5
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function glyphOf(i) { return i.kind === "alarm" ? "󰀠" : i.kind === "event" ? "󰃶" : "󰃀" }
    function nextDate(i) {
        const t = new Date(now.getFullYear(), now.getMonth(), now.getDate()), d = new Date(i.date + "T00:00:00")
        if (i.repeat === "daily") return d > t ? d : t
        if (i.repeat === "yearly") { if (d > t) return d; const y = new Date(t.getFullYear(), d.getMonth(), d.getDate()); return y >= t ? y : new Date(t.getFullYear() + 1, d.getMonth(), d.getDate()) }
        return d
    }
    readonly property var upcoming: {
        const nowK = Agenda.key(now)
        return Agenda.items.filter(i => i.repeat !== "once" || i.date > nowK || (i.date === nowK && (i.kind === "event" || i.last !== nowK)))
            .sort((a, b) => (Agenda.key(nextDate(a)) + a.time).localeCompare(Agenda.key(nextDate(b)) + b.time))
    }
    readonly property var dayRows: {
        const out = []
        for (const h of Agenda.holidaysOn(selected)) out.push({ g: "󰃤", t: h.name, when: "", c: Theme.coral })
        Agenda.items
        for (const i of Agenda.itemsOn(selected)) out.push({ g: glyphOf(i), t: i.text, when: i.time || "all day", c: i.kind === "event" ? Theme.text : Theme.amber })
        return out
    }
    // what the day card lists: that day first, the rest of the space filled with what comes up next (muted)
    function listRows(max) {
        const out = dayRows.slice(0, max)
        const todayK = Agenda.key(selected)
        for (const i of upcoming) {
            if (out.length >= max) break
            if (Agenda.key(nextDate(i)) === todayK) continue
            out.push({ g: glyphOf(i), t: i.text, when: Qt.formatDate(nextDate(i), "ddd d") + (i.time ? " " + i.time : ""), c: Theme.muted })
        }
        for (let n = 1; n <= 60 && out.length < max; n++) {          // then the coming holidays
            const d = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + n)
            for (const h of Agenda.holidaysOn(d)) if (out.length < max) out.push({ g: "󰃤", t: h.name, when: Qt.formatDate(d, "ddd d MMM"), c: Theme.muted })
        }
        return out
    }
    function capture(kind, mode) {
        const bin = Quickshell.env("HOME") + "/.local/bin/" + (kind === "rec" ? "rice-record" : "rice-shot")
        root.done()
        Quickshell.execDetached(["sh", "-c", "sleep 0.5; exec \"$0\" \"$@\"", bin, mode])
    }

    // what the status line under the date shows
    readonly property var nextAlarm: upcoming.find(i => i.kind === "alarm") || null
    readonly property var nextReminder: upcoming.find(i => i.kind === "reminder") || null
    property string formError: ""
    function addItem(kind, text, timeRaw) {
        let t = ""
        if (timeRaw !== "" || kind !== "event") {
            const m = timeRaw.match(/^(\d{1,2})[:.]?(\d{2})$/)
            if (!m || parseInt(m[1]) > 23 || parseInt(m[2]) > 59) { formError = "time like 07:30"; return false }
            t = Agenda.pad(parseInt(m[1])) + ":" + m[2]
        }
        if (kind !== "event" && sameDay(selected, now) && new Date(Agenda.key(selected) + "T" + t + ":00") < new Date()) { formError = "that time has passed"; return false }
        Agenda.add(selected, t, text.trim(), kind, "once")
        formError = ""
        return true
    }
    onMenuChanged: formError = ""

    Item {
        id: area
        x: 22; y: 14; width: parent.width - 44; height: parent.height - 28
        readonly property int g: 10
        readonly property int railW: 74
        readonly property int calW: 296
        readonly property int rx: railW + g + calW + g

        // ---------------- rail: small buttons, modes on the left, creators on the right ----------------
        Row {
            id: rail
            x: 0; y: 0; spacing: 4
            Column {
                spacing: 4
                IconKey { width: 35; height: 46.5; glyphSize: 17; glyph: "󰅶"; on: Modes.awake; led: true
                          onClicked: { root.menu = ""; Modes.setAwake(!Modes.awake) } }
                IconKey { width: 35; height: 46.5; glyphSize: 17; glyph: "󰊴"; on: Modes.game; led: true
                          onClicked: { root.menu = ""; Modes.setGame(!Modes.game) } }
                IconKey { id: recKey; width: 35; height: 46.5; glyphSize: 17; glyph: Recorder.on ? "󰓛" : "󰑋"; hot: Recorder.on; menu: !Recorder.on
                          onClicked: Recorder.on ? Recorder.stop() : (root.menu = root.menu === "rec" ? "" : "rec") }
                IconKey { id: shotKey; width: 35; height: 46.5; glyphSize: 17; glyph: "󰹑"; menu: true
                          onClicked: root.menu = root.menu === "shot" ? "" : "shot" }
            }
            Column {
                spacing: 4
                IconKey { id: tmKey; width: 35; height: 46.5; glyphSize: 17; glyph: "󱎫"; on: Agenda.timerOn; led: true
                          onClicked: root.menu = root.menu === "timer" ? "" : "timer" }
                IconKey { id: alKey; width: 35; height: 46.5; glyphSize: 17; glyph: "󰀠"; on: root.menu === "alarm"
                          onClicked: root.menu = root.menu === "alarm" ? "" : "alarm" }
                IconKey { id: rmKey; width: 35; height: 46.5; glyphSize: 17; glyph: "󰃀"; on: root.menu === "reminder"
                          onClicked: root.menu = root.menu === "reminder" ? "" : "reminder" }
                IconKey { id: evKey; width: 35; height: 46.5; glyphSize: 17; glyph: "󰃶"; on: root.menu === "event"
                          onClicked: root.menu = root.menu === "event" ? "" : "event" }
            }
        }

        // ---------------- calendar tile (tall) ----------------
        Card {
            id: calCard
            x: area.railW + area.g; y: 0
            width: area.calW; height: area.height
            pad: 10; spacing: 2
            Item {
                width: parent.width; height: 22
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.shown, "MMMM yyyy").toUpperCase()
                    color: root.offset === 0 ? Theme.text : Theme.amber
                    font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.offset = 0; root.selected = new Date() } }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 0
                    Repeater {
                        model: [["󰅁", -1], ["󰅂", 1]]
                        delegate: Item { required property var modelData; width: 22; height: 22
                            Text { anchors.centerIn: parent; text: modelData[0]; color: nv.containsMouse ? Theme.text : Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                            MouseArea { id: nv; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.offset += modelData[1] } }
                    }
                }
                WheelHandler { onWheel: (w) => root.offset += (w.angleDelta.y > 0 ? -1 : 1) }
            }
            Grid {
                columns: 7; width: parent.width
                readonly property real cw: width / 7
                readonly property real ch: (calCard.height - 2 * calCard.pad - 24) / (root.weeks + 1)
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Text { required property var modelData; width: parent.cw; height: parent.ch
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: modelData; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10 }
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
                        readonly property bool pub: Agenda.holidaysOn(modelData).some(h => h.pub)
                        readonly property bool marks: { Agenda.items; return Agenda.itemsOn(modelData).length > 0 || Agenda.holidaysOn(modelData).length > 0 }
                        Rectangle {
                            anchors.centerIn: parent; width: Math.min(parent.width - 6, 30); height: Math.min(parent.height - 1, 22); radius: 2
                            color: cell.today ? Theme.coral : (cm.containsMouse ? Theme.raised : "transparent")
                            border.width: cell.picked && !cell.today ? 1 : 0; border.color: Theme.coral
                        }
                        Text {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: cell.marks ? -2 : 0
                            text: cell.modelData.getDate()
                            color: cell.today ? Theme.bg : (!cell.inMonth ? Theme.dim : (cell.pub ? Theme.coral : Theme.text))
                            font.family: Theme.font; font.pixelSize: 12; font.bold: cell.today
                        }
                        Rectangle { visible: cell.marks; width: 3; height: 3; radius: 1.5; x: (parent.width - 3) / 2; y: parent.height / 2 + 6
                                    color: cell.today ? Theme.bg : (cell.pub ? Theme.coral : Theme.amber) }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected = cell.modelData }
                    }
                }
            }
        }

        // ---------------- date + weather (centred, sized to its content) ----------------
        Card {
            id: dayCard
            x: area.rx; y: 0
            width: area.width - x; height: 104
            pad: 10; spacing: 0
            readonly property bool isToday: root.sameDay(root.selected, root.now)
            readonly property var wx: {
                if (!Weather.ok) return null
                if (isToday) return { icon: Weather.icon(Weather.now.code, Weather.now.day), t: Weather.deg(Weather.now.temp), w: Weather.words(Weather.now.code) }
                const d = Weather.days.find(x => x.date === Agenda.key(root.selected))
                return d ? { icon: Weather.icon(d.code, true), t: Weather.deg(d.max) + " " + Weather.deg(d.min), w: Weather.words(d.code) } : null
            }
            Item {
                width: parent.width; height: dayCard.height - 2 * dayCard.pad
                Row {
                    anchors.centerIn: parent
                    spacing: 26
                    Row {   // the date
                        anchors.verticalCenter: parent.verticalCenter; spacing: 14
                        Text { anchors.verticalCenter: parent.verticalCenter; text: root.selected.getDate(); color: dayCard.isToday ? Theme.coral : Theme.text
                               font.family: Theme.font; font.pixelSize: 52; font.bold: true }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: Qt.formatDate(root.selected, "dddd").toUpperCase(); color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 2 }
                            Text { text: Qt.formatDate(root.selected, "MMMM") + (root.selected.getFullYear() !== root.now.getFullYear() ? " " + root.selected.getFullYear() : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.bold: true }
                            Text { text: dayCard.isToday ? "󰥔 " + Qt.formatTime(root.now, "HH:mm:ss") : (root.selected < root.now ? "past" : "in " + Math.max(1, Math.round((root.selected - root.now) / 86400000)) + " days")
                                   color: dayCard.isToday ? Theme.muted : Theme.amber; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                    Rectangle { visible: dayCard.wx !== null; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 44; color: Theme.hover }
                    Row {   // the weather of that day
                        visible: dayCard.wx !== null
                        anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        Text { anchors.verticalCenter: parent.verticalCenter; text: dayCard.wx ? dayCard.wx.icon : ""; color: Theme.coral; font.family: Theme.font; font.pixelSize: 32 }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: dayCard.wx ? dayCard.wx.t : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 18; font.bold: true }
                            Text { text: dayCard.wx ? dayCard.wx.w : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }

        // ---------------- events: that day first, then what comes next ----------------
        Card {
            id: evCard
            x: area.rx; y: dayCard.height + area.g
            width: 330; height: area.height - y
            pad: 10; spacing: 0
            Item {
                width: parent.width; height: evCard.height - 2 * evCard.pad
                Column {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width; spacing: 3
                    Repeater {
                        model: root.listRows(4)
                        delegate: Row { required property var modelData; spacing: 8
                            Text { width: 14; text: modelData.g; color: modelData.c; font.family: Theme.font; font.pixelSize: 12 }
                            Text { width: 88; text: modelData.when; elide: Text.ElideRight; color: modelData.c; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                            Text { width: evCard.width - 2 * evCard.pad - 126; text: modelData.t; elide: Text.ElideRight; color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }

        // ---------------- what is set: timer, alarm, reminder ----------------
        Card {
            id: setCard
            x: evCard.x + evCard.width + area.g; y: evCard.y
            width: area.width - x; height: evCard.height
            pad: 10; spacing: 0
            readonly property real timerLeft: Agenda.timerPaused ? Agenda.timerLeft : (Agenda.timerEnd > 0 ? Math.max(0, Agenda.timerEnd - root.now.getTime()) : 0)
            Item {
                width: parent.width; height: setCard.height - 2 * setCard.pad
                Column {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width; spacing: 6
                    Row { spacing: 10
                        Text { width: 16; text: "󱎫"; color: Agenda.timerOn ? Theme.coral : Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                        Text { text: Agenda.timerOn ? Agenda.fmt(setCard.timerLeft) : "–"; color: Agenda.timerPaused ? Theme.amber : (Agenda.timerOn ? Theme.coral : Theme.dim); font.family: Theme.font; font.pixelSize: 13; font.bold: true } }
                    Row { spacing: 10
                        Text { width: 16; text: "󰀠"; color: root.nextAlarm ? Theme.amber : Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                        Text { text: root.nextAlarm ? root.nextAlarm.time : "–"; color: root.nextAlarm ? Theme.text : Theme.dim; font.family: Theme.font; font.pixelSize: 13; font.bold: true } }
                    Row { spacing: 10
                        Text { width: 16; text: "󰃀"; color: root.nextReminder ? Theme.amber : Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                        Text { width: setCard.width - 2 * setCard.pad - 26; elide: Text.ElideRight; text: root.nextReminder ? root.nextReminder.text : "–"; color: root.nextReminder ? Theme.text : Theme.dim; font.family: Theme.font; font.pixelSize: 13; font.bold: true } }
                }
            }
        }

        // ---------------- popover next to the rail: record / screenshot lists, timer, add forms ----------------
        Rectangle {
            id: sub
            visible: root.menu !== ""
            z: 30
            readonly property bool isForm: root.menu === "alarm" || root.menu === "reminder" || root.menu === "event"
            readonly property bool isList: root.menu === "rec" || root.menu === "shot"
            readonly property var items: root.menu === "rec"
                ? [["󰍹", "Screen", "screen"], ["󰩭", "Area", "region"], ["󰕾", "Screen + sound", "sound"]]
                : [["󰩭", "Area", "area"], ["󰖲", "Window", "window"], ["󰍹", "Screen", "screen"], ["󰏫", "Draw on it", "edit"]]
            readonly property Item key: ({ rec: recKey, shot: shotKey, timer: tmKey, alarm: alKey, reminder: rmKey, event: evKey })[root.menu] || recKey
            readonly property point at: key.mapToItem(area, 0, 0)
            x: area.railW + 6
            y: Math.max(0, Math.min(at.y, area.height - height))
            width: isList ? 150 : 214
            height: (isList ? col.implicitHeight : (isForm ? formCol.implicitHeight : timerCol.implicitHeight)) + 16
            radius: 3
            color: Theme.surface; border.width: 1; border.color: Theme.hover
            onVisibleChanged: if (visible && isForm) { txt.text = ""; tim.text = ""; txt.forceActiveFocus() }

            Column {   // record / screenshot
                id: col
                visible: sub.isList
                x: 4; y: 4; width: parent.width - 8
                Repeater {
                    model: sub.isList ? sub.items : []
                    delegate: Rectangle {
                        required property var modelData
                        width: col.width; height: 24; radius: 2
                        color: mi.containsMouse ? Theme.hover : "transparent"
                        Row { anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 8
                            Text { text: modelData[0]; color: Theme.coral; font.family: Theme.font; font.pixelSize: 14 }
                            Text { text: modelData[1]; color: Theme.text; font.family: Theme.font; font.pixelSize: 11 } }
                        MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.capture(root.menu, modelData[2]); root.menu = "" } }
                    }
                }
            }
            Column {   // timer
                id: timerCol
                visible: root.menu === "timer"
                x: 8; y: 8; width: parent.width - 16; spacing: 6
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Agenda.timerOn ? Agenda.fmt(dayCard.timerLeft) : "0:00"
                       color: Agenda.timerPaused ? Theme.amber : (Agenda.timerOn ? Theme.coral : Theme.dim); font.family: Theme.font; font.pixelSize: 26; font.bold: true }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
                    Repeater {
                        model: Agenda.timerOn ? [] : [5, 10, 25, 45]
                        delegate: IconKey { required property int modelData; width: 42; height: 26; glyph: modelData + "m"; onClicked: { Agenda.startTimer(modelData * 60, ""); root.menu = "" } }
                    }
                    IconKey { visible: Agenda.timerOn; width: 60; height: 26; glyph: Agenda.timerPaused ? "󰐊" : "󰏤"; onClicked: Agenda.timerPaused ? Agenda.resumeTimer() : Agenda.pauseTimer() }
                    IconKey { visible: Agenda.timerOn; width: 60; height: 26; glyph: "󰓛"; onClicked: { Agenda.cancelTimer(); root.menu = "" } }
                }
            }
            Column {   // alarm / reminder / event
                id: formCol
                visible: sub.isForm
                x: 8; y: 8; width: parent.width - 16; spacing: 6
                Row { spacing: 8
                    Text { text: ({ alarm: "󰀠", reminder: "󰃀", event: "󰃶" })[root.menu] || ""; color: Theme.amber; font.family: Theme.font; font.pixelSize: 15 }
                    Text { text: Qt.formatDate(root.selected, "ddd d MMM"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle { width: parent.width; height: 28; radius: 4; color: Theme.raised; border.width: 1; border.color: txt.activeFocus ? Theme.coral : "transparent"
                    TextInput { id: txt; anchors.fill: parent; anchors.margins: 6; verticalAlignment: TextInput.AlignVCenter; clip: true; color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4)
                                font.family: Theme.font; font.pixelSize: 12; onAccepted: tim.forceActiveFocus(); KeyNavigation.tab: tim
                                Text { visible: txt.text === ""; text: "what"; color: Theme.dim; font: txt.font } } }
                Row { spacing: 6
                    Rectangle { width: 74; height: 28; radius: 4; color: Theme.raised; border.width: 1; border.color: tim.activeFocus ? Theme.coral : "transparent"
                        TextInput { id: tim; anchors.fill: parent; anchors.margins: 6; verticalAlignment: TextInput.AlignVCenter; clip: true; color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4)
                                    font.family: Theme.font; font.pixelSize: 12; onAccepted: addBtn.clicked()
                                    Text { visible: tim.text === ""; text: root.menu === "event" ? "all day" : "07:30"; color: Theme.dim; font: tim.font } } }
                    IconKey { id: addBtn; width: 42; height: 28; glyph: "󰐕"; onClicked: { if (root.addItem(root.menu, txt.text, tim.text.trim())) root.menu = "" } }
                }
                Text { visible: root.formError !== ""; text: root.formError; color: Theme.amber; font.family: Theme.font; font.pixelSize: 11 }
            }
        }
    }
}

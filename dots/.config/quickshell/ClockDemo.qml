// ClockDemo.qml -- DEMO of the redesigned general panel:
//   left, a rail of four buttons the full height (keep awake, game mode, record, screenshot);
//   then the calendar; then a column split in two: on top the date + events card and the weather card, below four
//   buttons (timer, alarm, reminder, event) that each open their own notch panel with the advanced options (ClockPage.qml).
//   Record / screenshot open a small list next to the rail.
// Open with `qs ipc call notch open clockA`. Temporary: the final version replaces ClockPanel.qml.
import QtQuick
import Quickshell

Item {
    id: root
    readonly property int wantWidth: 980
    readonly property int wantHeight: 232
    signal done()
    signal page(string id)               // open another notch panel (clockTimer, clockAlarm, clockReminder, clockEvent)

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

    readonly property var nextAlarm: upcoming.find(i => i.kind === "alarm") || null
    readonly property var nextReminder: upcoming.find(i => i.kind === "reminder") || null
    readonly property int eventsToday: { Agenda.items; return Agenda.itemsOn(now).filter(i => i.kind === "event").length }
    readonly property real timerLeft: Agenda.timerPaused ? Agenda.timerLeft : (Agenda.timerEnd > 0 ? Math.max(0, Agenda.timerEnd - now.getTime()) : 0)

    // a wide button of the lower row: an icon, and its value once something is set
    component OptButton: Rectangle {
        id: ob
        property string glyph: ""
        property string value: ""
        property bool lit: false
        signal clicked()
        height: 44; radius: 2
        color: ma.containsMouse ? Theme.hover : Theme.raised
        border.width: 1; border.color: Theme.hover
        KeyEdge {}
        Row {
            anchors.centerIn: parent; spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; text: ob.glyph; color: ob.lit ? Theme.coral : Theme.muted; font.family: Theme.font; font.pixelSize: 18 }
            Text { visible: ob.value !== ""; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, ob.width - 56); elide: Text.ElideRight
                   text: ob.value; color: ob.lit ? Theme.coral : Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ob.clicked() }
    }

    Item {
        id: area
        x: 22; y: 14; width: parent.width - 44; height: parent.height - 28
        readonly property int g: 10
        readonly property int railW: 36
        readonly property int calW: 296
        readonly property int rx: railW + g + calW + g
        readonly property int topH: 150

        // ---------------- rail: four buttons, the full height ----------------
        Column {
            id: rail
            x: 0; y: 0; width: area.railW; spacing: 6
            readonly property real bh: (area.height - 3 * spacing) / 4
            IconKey { width: parent.width; height: rail.bh; glyphSize: 17; glyph: "󰅶"; on: Modes.awake; led: true
                      onClicked: { root.menu = ""; Modes.setAwake(!Modes.awake) } }
            IconKey { width: parent.width; height: rail.bh; glyphSize: 17; glyph: "󰊴"; on: Modes.game; led: true
                      onClicked: { root.menu = ""; Modes.setGame(!Modes.game) } }
            IconKey { id: recKey; width: parent.width; height: rail.bh; glyphSize: 17; glyph: Recorder.on ? "󰓛" : "󰑋"; hot: Recorder.on; menu: !Recorder.on
                      onClicked: Recorder.on ? Recorder.stop() : (root.menu = root.menu === "rec" ? "" : "rec") }
            IconKey { id: shotKey; width: parent.width; height: rail.bh; glyphSize: 17; glyph: "󰹑"; menu: true
                      onClicked: root.menu = root.menu === "shot" ? "" : "shot" }
        }

        // ---------------- calendar ----------------
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

        // ---------------- top left: the date and its events ----------------
        Card {
            id: dateCard
            x: area.rx; y: 0
            width: 350; height: area.topH
            pad: 10; spacing: 0
            readonly property bool isToday: root.sameDay(root.selected, root.now)
            Item {
                width: parent.width; height: dateCard.height - 2 * dateCard.pad
                Column {
                    anchors.centerIn: parent; spacing: 7
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
                        Text { anchors.verticalCenter: parent.verticalCenter; text: root.selected.getDate(); color: dateCard.isToday ? Theme.coral : Theme.text
                               font.family: Theme.font; font.pixelSize: 52; font.bold: true }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: Qt.formatDate(root.selected, "dddd").toUpperCase(); color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 2 }
                            Text { text: Qt.formatDate(root.selected, "MMMM") + (root.selected.getFullYear() !== root.now.getFullYear() ? " " + root.selected.getFullYear() : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.bold: true }
                            Text { text: dateCard.isToday ? "󰥔 " + Qt.formatTime(root.now, "HH:mm:ss") : (root.selected < root.now ? "past" : "in " + Math.max(1, Math.round((root.selected - root.now) / 86400000)) + " days")
                                   color: dateCard.isToday ? Theme.muted : Theme.amber; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                    Repeater {
                        model: root.listRows(3)
                        delegate: Row { required property var modelData; anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            Text { text: modelData.g; color: modelData.c; font.family: Theme.font; font.pixelSize: 11 }
                            Text { text: modelData.when; visible: modelData.when !== ""; color: modelData.c; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                            Text { text: modelData.t; width: Math.min(implicitWidth, dateCard.width - 160); elide: Text.ElideRight; color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }

        // ---------------- top right: the weather ----------------
        Card {
            id: wxCard
            x: dateCard.x + dateCard.width + area.g; y: 0
            width: area.width - x; height: area.topH
            pad: 10; spacing: 0
            readonly property var wx: {
                if (!Weather.ok) return null
                if (root.sameDay(root.selected, root.now)) return { icon: Weather.icon(Weather.now.code, Weather.now.day), t: Weather.deg(Weather.now.temp), w: Weather.words(Weather.now.code) }
                const d = Weather.days.find(x => x.date === Agenda.key(root.selected))
                return d ? { icon: Weather.icon(d.code, true), t: Weather.deg(d.max) + " " + Weather.deg(d.min), w: Weather.words(d.code) } : null
            }
            Item {
                width: parent.width; height: wxCard.height - 2 * wxCard.pad
                Text { visible: !Weather.ok; anchors.centerIn: parent; text: !Weather.wanted ? "no place set" : (Weather.error || "loading…"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                Column {
                    visible: Weather.ok
                    anchors.centerIn: parent; spacing: 9
                    Row {
                        visible: wxCard.wx !== null
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: wxCard.wx ? wxCard.wx.icon : ""; color: Theme.coral; font.family: Theme.font; font.pixelSize: 30 }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 0
                            Text { text: wxCard.wx ? wxCard.wx.t : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 18; font.bold: true }
                            Text { text: wxCard.wx ? wxCard.wx.w : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        }
                    }
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
                        Repeater {
                            model: Weather.days.slice(1, 5)
                            delegate: Row { required property var modelData; spacing: 10
                                Text { width: 30; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                                Text { width: 24; text: Weather.icon(modelData.code, true); color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                                Text { text: Weather.deg(modelData.max) + " " + Weather.deg(modelData.min); color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }

        // ---------------- below: four date options, each opens its own panel ----------------
        Row {
            x: area.rx; y: area.topH + area.g; spacing: area.g
            readonly property real bw: (area.width - area.rx - 3 * area.g) / 4
            OptButton { width: parent.bw; glyph: "󱎫"; lit: Agenda.timerOn; value: Agenda.timerOn ? Agenda.fmt(root.timerLeft) : ""; onClicked: root.page("clockTimer") }
            OptButton { width: parent.bw; glyph: "󰀠"; lit: root.nextAlarm !== null; value: root.nextAlarm ? root.nextAlarm.time : ""; onClicked: root.page("clockAlarm") }
            OptButton { width: parent.bw; glyph: "󰃀"; lit: root.nextReminder !== null; value: root.nextReminder ? root.nextReminder.text : ""; onClicked: root.page("clockReminder") }
            OptButton { width: parent.bw; glyph: "󰃶"; lit: root.eventsToday > 0; value: root.eventsToday > 0 ? "" + root.eventsToday : ""; onClicked: root.page("clockEvent") }
        }

        // ---------------- record / screenshot: a small list next to the rail ----------------
        Rectangle {
            id: sub
            visible: root.menu !== ""
            z: 30
            readonly property var items: root.menu === "rec"
                ? [["󰍹", "Screen", "screen"], ["󰩭", "Area", "region"], ["󰕾", "Screen + sound", "sound"]]
                : [["󰩭", "Area", "area"], ["󰖲", "Window", "window"], ["󰍹", "Screen", "screen"], ["󰏫", "Draw on it", "edit"]]
            readonly property Item key: root.menu === "rec" ? recKey : shotKey
            readonly property point at: key.mapToItem(area, 0, 0)
            x: area.railW + 6
            y: Math.max(0, Math.min(at.y, area.height - height))
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
                        Row { anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 8
                            Text { text: modelData[0]; color: Theme.coral; font.family: Theme.font; font.pixelSize: 14 }
                            Text { text: modelData[1]; color: Theme.text; font.family: Theme.font; font.pixelSize: 11 } }
                        MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.capture(root.menu, modelData[2]); root.menu = "" } }
                    }
                }
            }
        }
    }
}

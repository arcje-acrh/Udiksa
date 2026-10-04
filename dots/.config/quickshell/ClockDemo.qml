// ClockDemo.qml -- DEMO of the redesigned general panel (calendar, today, quick switches, timer), three arrangements:
//   A  three columns: calendar | today | quick (2x2) over the timer
//   B  calendar left; today on top, quick + timer in a row under it
//   C  calendar | today | a narrow column on the right: quick (2x2) over a small timer
// Open with `qs ipc call notch open clockA|clockB|clockC`. Temporary: the picked one replaces ClockPanel.qml.
import QtQuick
import Quickshell

Item {
    id: root
    property string variant: "A"
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

    Item {
        id: area
        x: 22; y: 14; width: parent.width - 44; height: parent.height - 28
        readonly property int g: 10
        readonly property int rightW: root.variant === "C" ? 112 : 300

        // ---------------- calendar ----------------
        Card {
            id: calCard
            x: 0; y: 0
            width: root.variant === "A" ? 306 : 330
            height: area.height
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
                            onClicked: { root.selected = cell.modelData; root.page = "day" } }
                    }
                }
            }
        }

        // ---------------- today (day / next / weather) ----------------
        Card {
            id: dayCard
            x: calCard.width + area.g; y: 0
            width: root.variant === "B" ? area.width - x : area.width - x - (area.rightW + area.g)
            height: root.variant === "B" ? 108 : area.height
            pad: 10; spacing: 0
            readonly property int rowsMax: root.variant === "B" ? 2 : 7
            // page keys, top right, over the content (no title row)
            Row {
                parent: dayCard
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                spacing: 2; z: 5
                Repeater {
                    model: [["󰃭", "day"], ["󰃱", "next"], ["󰖕", "weather"]]
                    delegate: IconKey { required property var modelData; width: 26; height: 22; glyph: modelData[0]; on: root.page === modelData[1]
                                        onClicked: root.page = modelData[1] }
                }
            }
            // day page: the date cluster, then what is planned
            Item {
                visible: root.page === "day"; width: parent.width; height: dayCard.height - 2 * dayCard.pad
                Text {
                    id: bigDay
                    x: 0; y: 0
                    text: root.selected.getDate(); color: root.sameDay(root.selected, root.now) ? Theme.coral : Theme.text
                    font.family: Theme.font; font.pixelSize: 44; font.bold: true
                }
                Column {
                    anchors.left: bigDay.right; anchors.leftMargin: 12; y: 2; spacing: 1
                    Text { text: Qt.formatDate(root.selected, "dddd, MMMM") + (root.selected.getFullYear() !== root.now.getFullYear() ? " " + root.selected.getFullYear() : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                    Text { visible: root.sameDay(root.selected, root.now)
                           text: "󰥔 " + Qt.formatTime(root.now, "HH:mm") + (Weather.ok ? "   " + Weather.icon(Weather.now.code, Weather.now.day) + " " + Weather.deg(Weather.now.temp) : "")
                           color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                    Text { visible: !root.sameDay(root.selected, root.now); text: root.selected < root.now ? "past" : "in " + Math.max(1, Math.round((root.selected - root.now) / 86400000)) + " days"
                           color: Theme.amber; font.family: Theme.font; font.pixelSize: 12 }
                }
                Column {
                    x: 0; y: 52; width: parent.width; spacing: 3
                    Repeater {
                        model: root.listRows(dayCard.rowsMax)
                        delegate: Row { required property var modelData; spacing: 8
                            Text { text: modelData.g; color: modelData.c; font.family: Theme.font; font.pixelSize: 12 }
                            Text { text: modelData.when; visible: modelData.when !== ""; color: modelData.c; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                            Text { text: modelData.t; width: Math.min(implicitWidth, dayCard.width - 130); elide: Text.ElideRight; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                }
            }
            // next page
            Column {
                visible: root.page === "next"; width: parent.width - 100; spacing: 4
                Repeater {
                    model: root.upcoming.slice(0, dayCard.rowsMax)
                    delegate: Row { required property var modelData; spacing: 8
                        Text { text: root.glyphOf(modelData); color: modelData.kind === "event" ? Theme.text : Theme.amber; font.family: Theme.font; font.pixelSize: 12 }
                        Text { text: Qt.formatDate(root.nextDate(modelData), "ddd d") + " " + (modelData.time || ""); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                        Text { text: modelData.text; width: Math.min(implicitWidth, dayCard.width - 190); elide: Text.ElideRight; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                    }
                }
                Text { visible: root.upcoming.length === 0; text: "nothing coming up"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            }
            // weather page
            Column {
                visible: root.page === "weather"; width: parent.width; spacing: 6
                Text { visible: !Weather.ok; text: !Weather.wanted ? "No place set for the weather yet." : (Weather.error || "Loading…"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                Row {
                    visible: Weather.ok; spacing: 12
                    Text { text: Weather.icon(Weather.now.code, Weather.now.day); color: Theme.coral; font.family: Theme.font; font.pixelSize: 32 }
                    Column { spacing: 1
                        Text { text: Weather.deg(Weather.now.temp) + "  " + Weather.words(Weather.now.code); color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
                        Text { text: "feels " + Weather.deg(Weather.now.feels) + " · 󰖎 " + Weather.now.humidity + "%"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }
                Row {
                    visible: Weather.ok && root.variant !== "B"; width: parent.width
                    Repeater {
                        model: Weather.days.slice(1, 5)
                        delegate: Column { required property var modelData; width: (dayCard.width - 2 * dayCard.pad) / 4; spacing: 1
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.icon(modelData.code, true); color: Theme.text; font.family: Theme.font; font.pixelSize: 18 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.deg(modelData.max) + " " + Weather.deg(modelData.min); color: Theme.text; font.family: Theme.font; font.pixelSize: 10 }
                        }
                    }
                }
            }
        }

        // ---------------- quick switches ----------------
        Card {
            id: quickCard
            x: root.variant === "B" ? calCard.width + area.g : area.width - area.rightW
            y: root.variant === "B" ? dayCard.height + area.g : 0
            width: root.variant === "B" ? 300 : area.rightW
            height: root.variant === "B" ? area.height - dayCard.height - area.g : (root.variant === "C" ? 108 : 112)
            pad: 8; spacing: 0
            Grid {
                id: tiles
                columns: root.variant === "B" ? 4 : 2
                spacing: 6
                readonly property real tw: (quickCard.width - 2 * quickCard.pad - (columns - 1) * spacing) / columns
                readonly property real th: root.variant === "B" ? quickCard.height - 2 * quickCard.pad : (quickCard.height - 2 * quickCard.pad - spacing) / 2
                IconKey { width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: "󰅶"; on: Modes.awake; led: true
                          onClicked: { root.menu = ""; Modes.setAwake(!Modes.awake) } }
                IconKey { width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: "󰊴"; on: Modes.game; led: true
                          onClicked: { root.menu = ""; Modes.setGame(!Modes.game) } }
                IconKey { id: recKey; width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: Recorder.on ? "󰓛" : "󰑋"; hot: Recorder.on; menu: !Recorder.on
                          onClicked: Recorder.on ? Recorder.stop() : (root.menu = root.menu === "rec" ? "" : "rec") }
                IconKey { id: shotKey; width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: "󰹑"; menu: true
                          onClicked: root.menu = root.menu === "shot" ? "" : "shot" }
            }
        }

        // ---------------- timer ----------------
        Card {
            id: timerCard
            x: root.variant === "B" ? quickCard.x + quickCard.width + area.g : quickCard.x
            y: root.variant === "B" ? quickCard.y : quickCard.height + area.g
            width: area.width - x
            height: root.variant === "B" ? quickCard.height : area.height - y
            pad: 8; spacing: 0
            readonly property real remaining: Agenda.timerPaused ? Agenda.timerLeft : (Agenda.timerEnd > 0 ? Math.max(0, Agenda.timerEnd - root.now.getTime()) : 0)
            readonly property bool narrow: root.variant === "C"
            Item {
                width: parent.width; height: timerCard.height - 2 * timerCard.pad
                Text {
                    id: tt
                    x: timerCard.narrow ? (parent.width - width) / 2 : 6
                    y: timerCard.narrow ? 4 : (parent.height - height) / 2
                    text: Agenda.timerOn ? Agenda.fmt(timerCard.remaining) : "0:00"
                    color: Agenda.timerPaused ? Theme.amber : (Agenda.timerOn ? Theme.coral : Theme.dim)
                    font.family: Theme.font; font.pixelSize: timerCard.narrow ? 18 : 24; font.bold: true
                }
                Row {
                    spacing: 4
                    anchors.right: parent.right; anchors.rightMargin: timerCard.narrow ? (parent.width - width) / 2 : 0
                    y: timerCard.narrow ? 34 : (parent.height - 26) / 2
                    Repeater {
                        model: Agenda.timerOn ? [] : [5, 10, 25]
                        delegate: IconKey { required property int modelData; width: timerCard.narrow ? 30 : 44; height: 26; glyph: timerCard.narrow ? modelData + "" : modelData + "m"
                                            onClicked: Agenda.startTimer(modelData * 60, "") }
                    }
                    IconKey { visible: Agenda.timerOn; width: timerCard.narrow ? 46 : 44; height: 26; glyph: Agenda.timerPaused ? "󰐊" : "󰏤"
                              onClicked: Agenda.timerPaused ? Agenda.resumeTimer() : Agenda.pauseTimer() }
                    IconKey { visible: Agenda.timerOn; width: timerCard.narrow ? 46 : 44; height: 26; glyph: "󰓛"; onClicked: Agenda.cancelTimer() }
                }
            }
        }

        // ---------------- submenu of Record / Screenshot ----------------
        Rectangle {
            id: sub
            visible: root.menu !== ""
            z: 30
            readonly property var items: root.menu === "rec"
                ? [["󰍹", "Screen", "screen"], ["󰩭", "Area", "region"], ["󰕾", "Screen + sound", "sound"]]
                : [["󰩭", "Area", "area"], ["󰖲", "Window", "window"], ["󰍹", "Screen", "screen"], ["󰏫", "Draw on it", "edit"]]
            readonly property Item key: root.menu === "rec" ? recKey : shotKey
            readonly property point at: key.mapToItem(area, 0, key.height + 4)
            x: Math.max(0, Math.min(area.width - width, at.x + key.width - width))
            y: at.y
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

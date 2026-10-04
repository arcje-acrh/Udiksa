// ClockDemo.qml -- DEMO of the redesigned general panel (calendar, today, quick switches, timer), three arrangements:
//   A  three columns: calendar | today | quick + timer        B  calendar left; today on top, quick + timer under it
//   C  a control strip across the top (quick + timer), calendar and today below it
// Open with `qs ipc call notch open clockA|clockB|clockC`. Temporary: the picked one replaces ClockPanel.qml.
import QtQuick
import Quickshell

Item {
    id: root
    property string variant: "A"
    readonly property int wantWidth: 980
    readonly property int wantHeight: 300
    signal done()
    readonly property bool strip: variant === "C"

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
    function capture(kind, mode) {
        const bin = Quickshell.env("HOME") + "/.local/bin/" + (kind === "rec" ? "rice-record" : "rice-shot")
        root.done()
        Quickshell.execDetached(["sh", "-c", "sleep 0.5; exec \"$0\" \"$@\"", bin, mode])
    }

    // the area inside the notch padding; every card is placed by variant
    Item {
        id: area
        x: 22; y: 14; width: parent.width - 44; height: parent.height - 28
        readonly property int g: 12

        // ---------------- calendar ----------------
        Card {
            id: calCard
            x: 0
            y: root.variant === "C" ? 76 : 0
            width: root.variant === "A" ? 320 : (root.variant === "B" ? 350 : 380)
            height: root.variant === "C" ? area.height - 76 : area.height
            spacing: 2
            Item {
                width: parent.width; height: 24
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.shown, "MMMM yyyy").toUpperCase()
                    color: root.offset === 0 ? Theme.text : Theme.amber
                    font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.offset = 0; root.selected = new Date() } }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    IconKey { width: 24; height: 22; glyph: "󰅁"; onClicked: root.offset-- }
                    IconKey { width: 24; height: 22; glyph: "󰅂"; onClicked: root.offset++ }
                }
                WheelHandler { onWheel: (w) => root.offset += (w.angleDelta.y > 0 ? -1 : 1) }
            }
            Grid {
                columns: 7; width: parent.width
                readonly property real cw: width / 7
                readonly property real ch: (calCard.height - 2 * calCard.pad - 26 - 2) / (root.weeks + 1)
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
                            anchors.centerIn: parent; width: Math.min(parent.width - 6, 32); height: Math.min(parent.height - 1, 24); radius: 2
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

        // ---------------- today ----------------
        Card {
            id: dayCard
            x: root.variant === "A" ? 332 : (root.variant === "B" ? 362 : 392)
            y: root.variant === "C" ? 76 : 0
            width: root.variant === "A" ? 320 : area.width - x
            height: root.variant === "B" ? 156 : (root.variant === "C" ? area.height - 76 : area.height)
            spacing: 4
            Item {
                width: parent.width; height: 26
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.page === "next" ? "NEXT" : (root.page === "weather" ? "WEATHER" : (root.sameDay(root.selected, root.now) ? "TODAY" : Qt.formatDate(root.selected, "ddd d MMM").toUpperCase()))
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Repeater {
                        model: [["󰃭", "Day", "day"], ["󰃱", "Next", "next"], ["󰖕", "Weather", "weather"]]
                        delegate: IconKey { required property var modelData
                            width: 28; height: 24; glyph: modelData[0]; tip: modelData[1]; on: root.page === modelData[2]
                            onClicked: root.page = modelData[2] }
                    }
                }
            }
            // day page
            Item {
                visible: root.page === "day"; width: parent.width; height: dayCard.height - 2 * dayCard.pad - 30
                Text {
                    id: bigDay
                    x: 0; y: 2
                    text: root.selected.getDate(); color: root.sameDay(root.selected, root.now) ? Theme.coral : Theme.text
                    font.family: Theme.font; font.pixelSize: 46; font.bold: true
                }
                Column {
                    anchors.left: bigDay.right; anchors.leftMargin: 14; y: 4; spacing: 3
                    Text { text: Qt.formatDate(root.selected, "dddd, MMMM"); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                    Text { text: "󰥔 " + Qt.formatTime(root.now, "HH:mm"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                           visible: root.sameDay(root.selected, root.now) }
                    Text { visible: !root.sameDay(root.selected, root.now); text: Qt.formatDate(root.selected, "yyyy"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                    Text { visible: Weather.ok && root.sameDay(root.selected, root.now)
                           text: Weather.icon(Weather.now.code, Weather.now.day) + " " + Weather.deg(Weather.now.temp) + " " + Weather.words(Weather.now.code)
                           color: Theme.coral; font.family: Theme.font; font.pixelSize: 12 }
                }
                Rectangle { x: 0; y: 58; width: parent.width; height: 1; color: Theme.hover }
                Column {
                    x: 0; y: 66; width: parent.width; spacing: 5
                    Repeater {
                        model: root.dayRows.slice(0, root.variant === "B" ? 2 : 4)
                        delegate: Row { required property var modelData; spacing: 8
                            Text { text: modelData.g; color: modelData.c; font.family: Theme.font; font.pixelSize: 13 }
                            Text { text: modelData.when; visible: modelData.when !== ""; color: modelData.c; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                            Text { text: modelData.t; width: Math.min(implicitWidth, dayCard.width - 130); elide: Text.ElideRight; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                    Text { visible: root.dayRows.length === 0; text: "nothing planned"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                }
            }
            // next page
            Column {
                visible: root.page === "next"; width: parent.width; spacing: 5
                Repeater {
                    model: root.upcoming.slice(0, root.variant === "B" ? 4 : 7)
                    delegate: Row { required property var modelData; spacing: 8
                        Text { text: root.glyphOf(modelData); color: modelData.kind === "event" ? Theme.text : Theme.amber; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: Qt.formatDate(root.nextDate(modelData), "ddd d") + " " + (modelData.time || ""); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                        Text { text: modelData.text; width: Math.min(implicitWidth, dayCard.width - 170); elide: Text.ElideRight; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
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
                    Text { text: Weather.icon(Weather.now.code, Weather.now.day); color: Theme.coral; font.family: Theme.font; font.pixelSize: 34 }
                    Column { spacing: 2
                        Text { text: Weather.deg(Weather.now.temp) + "  " + Weather.words(Weather.now.code); color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
                        Text { text: "feels " + Weather.deg(Weather.now.feels) + " · 󰖎 " + Weather.now.humidity + "%"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }
                Row {
                    visible: Weather.ok && root.variant !== "B"; width: parent.width
                    Repeater {
                        model: Weather.days.slice(1, 5)
                        delegate: Column { required property var modelData; width: (dayCard.width - 2 * dayCard.pad) / 4; spacing: 2
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
            x: root.variant === "A" ? 664 : (root.variant === "B" ? 362 : 0)
            y: root.variant === "B" ? 168 : 0
            width: root.variant === "A" ? area.width - 664 : (root.variant === "B" ? 300 : 430)
            height: root.variant === "A" ? 92 : (root.variant === "B" ? area.height - 168 : 64)
            spacing: 6
            pad: root.strip ? 10 : 12
            Text { visible: !root.strip; text: "QUICK"; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
            Row {
                id: tiles
                spacing: 6
                readonly property real tw: (quickCard.width - 2 * quickCard.pad - 3 * spacing) / 4
                readonly property int th: root.strip ? 44 : (root.variant === "B" ? 48 : 44)
                IconKey { width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: "󰅶"; tip: "Keep awake"; on: Modes.awake; led: true
                          onClicked: { root.menu = ""; Modes.setAwake(!Modes.awake) } }
                IconKey { width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: "󰊴"; tip: "Game mode"; on: Modes.game; led: true
                          onClicked: { root.menu = ""; Modes.setGame(!Modes.game) } }
                IconKey { id: recKey; width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: Recorder.on ? "󰓛" : "󰑋"; tip: Recorder.on ? "Stop recording" : "Record"; hot: Recorder.on; menu: !Recorder.on
                          onClicked: Recorder.on ? Recorder.stop() : (root.menu = root.menu === "rec" ? "" : "rec") }
                IconKey { id: shotKey; width: tiles.tw; height: tiles.th; glyphSize: 20; glyph: "󰹑"; tip: "Screenshot"; menu: true
                          onClicked: root.menu = root.menu === "shot" ? "" : "shot" }
            }
        }

        // ---------------- timer ----------------
        Card {
            id: timerCard
            x: root.variant === "A" ? 664 : (root.variant === "B" ? 362 + 310 : 440)
            y: root.variant === "A" ? 104 : (root.variant === "B" ? 168 : 0)
            width: area.width - x
            height: root.variant === "A" ? area.height - 104 : (root.variant === "B" ? area.height - 168 : 64)
            spacing: 4
            pad: root.strip ? 10 : 12
            readonly property real remaining: Agenda.timerPaused ? Agenda.timerLeft : (Agenda.timerEnd > 0 ? Math.max(0, Agenda.timerEnd - root.now.getTime()) : 0)
            Text { visible: !root.strip; text: "TIMER"; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
            Row {
                spacing: 12
                height: root.strip ? 44 : (root.variant === "B" ? 56 : 52)
                Text {
                    id: tt
                    anchors.verticalCenter: root.variant === "A" ? undefined : parent.verticalCenter
                    text: Agenda.timerOn ? Agenda.fmt(timerCard.remaining) : "0:00"
                    color: Agenda.timerPaused ? Theme.amber : (Agenda.timerOn ? Theme.coral : Theme.dim)
                    font.family: Theme.font; font.pixelSize: root.variant === "A" ? 32 : 24; font.bold: true
                    width: root.variant === "A" ? timerCard.width - 2 * timerCard.pad : implicitWidth
                    horizontalAlignment: root.variant === "A" ? Text.AlignHCenter : Text.AlignLeft
                    y: root.variant === "A" ? 4 : 0
                }
                Row {
                    visible: root.variant !== "A"
                    anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Repeater {
                        model: Agenda.timerOn ? [] : [5, 10, 25]
                        delegate: IconKey { required property int modelData; width: 38; height: 26; glyph: modelData + "m"; tip: modelData + " min timer"; onClicked: Agenda.startTimer(modelData * 60, "") }
                    }
                    IconKey { visible: Agenda.timerOn; width: 30; height: 26; glyph: Agenda.timerPaused ? "󰐊" : "󰏤"; tip: Agenda.timerPaused ? "Resume" : "Pause"
                              onClicked: Agenda.timerPaused ? Agenda.resumeTimer() : Agenda.pauseTimer() }
                    IconKey { visible: Agenda.timerOn; width: 30; height: 26; glyph: "󰓛"; tip: "Cancel"; onClicked: Agenda.cancelTimer() }
                }
            }
            Row {   // variant A: presets under the time
                visible: root.variant === "A"; spacing: 5
                x: (parent.width - width) / 2
                Repeater {
                    model: Agenda.timerOn ? [] : [5, 10, 25]
                    delegate: IconKey { required property int modelData; width: 44; height: 26; glyph: modelData + "m"; tip: modelData + " min timer"; onClicked: Agenda.startTimer(modelData * 60, "") }
                }
                IconKey { visible: Agenda.timerOn; width: 44; height: 26; glyph: Agenda.timerPaused ? "󰐊" : "󰏤"; tip: Agenda.timerPaused ? "Resume" : "Pause"
                          onClicked: Agenda.timerPaused ? Agenda.resumeTimer() : Agenda.pauseTimer() }
                IconKey { visible: Agenda.timerOn; width: 44; height: 26; glyph: "󰓛"; tip: "Cancel"; onClicked: Agenda.cancelTimer() }
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
            readonly property point at: quickCard.mapToItem(area, tiles.x + quickCard.pad + key.x, tiles.y + quickCard.pad + key.y)
            x: Math.min(area.width - width, at.x + key.width - width + 6)
            y: at.y + key.height + 4
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

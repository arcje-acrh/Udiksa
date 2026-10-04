// ClockPage.qml -- the page of one date option (timer, alarm, reminder, event), in its own notch panel opened from ClockPanel's lower row.
//   kind "timer"     presets + pause / resume / cancel on the left; label + any minutes on the right
//   kind "alarm" | "reminder" | "event"   the form on the left (what, time, day, repeat), what is already set on the right
// The back key returns to the date panel.
import QtQuick
import Quickshell

Item {
    id: root
    property string kind: "timer"
    readonly property int wantWidth: 760
    readonly property int wantHeight: 232
    signal back()

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    readonly property var meta: ({
        timer: { glyph: "󱎫", title: "Timer" }, alarm: { glyph: "󰀠", title: "Alarm" },
        reminder: { glyph: "󰃀", title: "Reminder" }, event: { glyph: "󰃶", title: "Event" } })[kind]
    readonly property real timerLeft: Agenda.timerPaused ? Agenda.timerLeft : (Agenda.timerEnd > 0 ? Math.max(0, Agenda.timerEnd - now.getTime()) : 0)

    // ---- form state (alarm / reminder / event) ----
    property int dayOffset: 0
    property int rep: 0
    property string error: ""
    readonly property date day: new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset)
    function nextDate(i) {
        const t = new Date(now.getFullYear(), now.getMonth(), now.getDate()), d = new Date(i.date + "T00:00:00")
        if (i.repeat === "daily") return d > t ? d : t
        if (i.repeat === "yearly") { if (d > t) return d; const y = new Date(t.getFullYear(), d.getMonth(), d.getDate()); return y >= t ? y : new Date(t.getFullYear() + 1, d.getMonth(), d.getDate()) }
        return d
    }
    readonly property var existing: Agenda.items.filter(i => i.kind === kind)
        .sort((a, b) => (Agenda.key(nextDate(a)) + a.time).localeCompare(Agenda.key(nextDate(b)) + b.time))
    function submit() {
        const raw = tim.text.trim()
        let t = ""
        if (raw !== "" || kind !== "event") {
            const m = raw.match(/^(\d{1,2})[:.]?(\d{2})$/)
            if (!m || parseInt(m[1]) > 23 || parseInt(m[2]) > 59) { error = kind === "event" ? "time like 07:30, or empty = all day" : "time like 07:30"; return }
            t = Agenda.pad(parseInt(m[1])) + ":" + m[2]
        }
        const label = txt.text.trim()
        if (kind !== "alarm" && label === "") { error = "say what it is"; return }
        if (kind !== "event" && rep === 0 && new Date(Agenda.key(day) + "T" + t + ":00") < new Date()) { error = "that time has passed"; return }
        Agenda.add(day, t, label, kind, ["once", "daily", "yearly"][rep])
        error = ""; txt.text = ""; tim.text = ""
    }
    function startCustom() {
        const v = parseFloat(mins.text.replace(",", "."))
        if (!(v > 0)) { error = "minutes like 7.5"; return }
        Agenda.startTimer(Math.round(v * 60), lab.text.trim()); error = ""; mins.text = ""; lab.text = ""
    }

    // a one-line text box
    component Box: Rectangle {
        id: bx
        property alias text: ti.text
        property string hint: ""
        signal accepted()
        function focusIt() { ti.forceActiveFocus() }
        height: 30; radius: 4; color: Theme.raised
        border.width: 1; border.color: ti.activeFocus ? Theme.coral : "transparent"
        TextInput { id: ti; anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9; verticalAlignment: TextInput.AlignVCenter; clip: true
                    color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4); font.family: Theme.font; font.pixelSize: 12; onAccepted: bx.accepted()
                    Text { visible: ti.text === ""; anchors.verticalCenter: parent.verticalCenter; text: bx.hint; color: Theme.dim; font: ti.font } }
    }
    // the header of a card: back key (left card only) + title
    component Head: Item {
        property string title: ""
        property bool backKey: false
        width: parent.width; height: 28
        IconKey { visible: parent.backKey; width: 28; height: 24; glyph: "󰁍"; onClicked: root.back() }
        Text { x: parent.backKey ? 36 : 0; anchors.verticalCenter: parent.verticalCenter; text: parent.title.toUpperCase()
               color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; visible: parent.backKey && root.error !== ""
               text: root.error; color: Theme.amber; font.family: Theme.font; font.pixelSize: 11 }
    }

    Item {
        id: area
        x: 22; y: 14; width: parent.width - 44; height: parent.height - 28
        readonly property int g: 10
        readonly property int leftW: 396

        // ================= left card =================
        Card {
            id: left
            x: 0; y: 0; width: area.leftW; height: area.height
            pad: 10; spacing: 8
            Head { title: root.meta.title; backKey: true }

            // ---- timer ----
            Item {
                visible: root.kind === "timer"; width: parent.width; height: left.height - 2 * left.pad - 36
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: 0
                       text: Agenda.timerOn ? Agenda.fmt(root.timerLeft) : "0:00"
                       color: Agenda.timerPaused ? Theme.amber : (Agenda.timerOn ? Theme.coral : Theme.dim); font.family: Theme.font; font.pixelSize: 38; font.bold: true }
                Grid {
                    visible: !Agenda.timerOn; anchors.horizontalCenter: parent.horizontalCenter; y: 56
                    columns: 4; spacing: 6
                    Repeater {
                        model: [1, 5, 10, 15, 25, 30, 45, 60]
                        delegate: IconKey { required property int modelData; width: 84; height: 32; glyphSize: 13; glyph: modelData + " min"; onClicked: Agenda.startTimer(modelData * 60, "") }
                    }
                }
                Row {
                    visible: Agenda.timerOn; anchors.horizontalCenter: parent.horizontalCenter; y: 62; spacing: 6
                    IconKey { width: 116; height: 36; glyphSize: 18; glyph: Agenda.timerPaused ? "󰐊" : "󰏤"; onClicked: Agenda.timerPaused ? Agenda.resumeTimer() : Agenda.pauseTimer() }
                    IconKey { width: 116; height: 36; glyphSize: 18; glyph: "󰓛"; onClicked: Agenda.cancelTimer() }
                    IconKey { width: 116; height: 36; glyphSize: 13; glyph: "+1 min"; onClicked: Agenda.snooze() }
                }
            }

            // ---- alarm / reminder / event form ----
            Column {
                visible: root.kind !== "timer"; width: parent.width; spacing: 10
                Box { id: txt; width: parent.width; hint: root.kind === "alarm" ? "label (optional)" : "what"; onAccepted: tim.focusIt() }
                Row { spacing: 6; width: parent.width
                    Box { id: tim; width: 84; hint: root.kind === "event" ? "all day" : "07:30"; onAccepted: root.submit() }
                    IconKey { width: 28; height: 30; glyph: "󰅁"; onClicked: root.dayOffset-- }
                    Rectangle { width: parent.width - 84 - 28 - 28 - 18 - 0; height: 30; radius: 4; color: "transparent"
                        Text { anchors.centerIn: parent; text: root.dayOffset === 0 ? "Today" : (root.dayOffset === 1 ? "Tomorrow" : Qt.formatDate(root.day, "ddd d MMM")); color: Theme.text; font.family: Theme.font; font.pixelSize: 12 } }
                    IconKey { width: 28; height: 30; glyph: "󰅂"; onClicked: root.dayOffset++ }
                }
                Row { spacing: 6; width: parent.width
                    Repeater {
                        model: ["once", "daily", "yearly"]
                        delegate: IconKey { required property int index; required property string modelData
                            width: (parent.width - 18 - 78) / 3; height: 32; glyphSize: 12; glyph: modelData; on: root.rep === index; onClicked: root.rep = index }
                    }
                    IconKey { width: 78; height: 32; glyphSize: 17; glyph: "󰐕"; onClicked: root.submit() }
                }
            }
        }

        // ================= right card =================
        Card {
            id: right
            x: area.leftW + area.g; y: 0; width: area.width - x; height: area.height
            pad: 10; spacing: 8
            Head { title: root.kind === "timer" ? "Custom" : "Set"; backKey: false }

            // ---- timer: label + any minutes ----
            Column {
                visible: root.kind === "timer"; width: parent.width; spacing: 8
                Box { id: lab; width: parent.width; hint: "what for (optional)"; onAccepted: mins.focusIt() }
                Row { spacing: 6; width: parent.width
                    Box { id: mins; width: parent.width - 6 - 78; hint: "minutes, e.g. 7.5"; onAccepted: root.startCustom() }
                    IconKey { width: 78; height: 30; glyphSize: 17; glyph: "󰐊"; onClicked: root.startCustom() }
                }
                Grid {
                    columns: 2; spacing: 6; width: parent.width
                    Repeater {
                        model: [["tea", 3], ["eggs", 8], ["focus", 25], ["break", 5]]
                        delegate: IconKey { required property var modelData; width: (parent.width - parent.spacing) / 2; height: 30; glyphSize: 12
                            glyph: modelData[0] + "  " + modelData[1] + " min"; onClicked: Agenda.startTimer(modelData[1] * 60, modelData[0]) }
                    }
                }
                Text { visible: root.error !== "" && root.kind === "timer"; text: root.error; color: Theme.amber; font.family: Theme.font; font.pixelSize: 11 }
            }

            // ---- what is set ----
            Column {
                visible: root.kind !== "timer"; width: parent.width; spacing: 3
                Repeater {
                    model: root.existing.slice(0, 6)
                    delegate: Item { id: row; required property var modelData; width: parent.width; height: 22
                        Row { anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Text { width: 70; text: Qt.formatDate(root.nextDate(row.modelData), "ddd d MMM"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                            Text { width: 40; text: row.modelData.time || "all day"; color: Theme.amber; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                            Text { width: right.width - 2 * right.pad - 70 - 40 - 52; elide: Text.ElideRight; text: row.modelData.text + (row.modelData.repeat !== "once" ? "  󰑖" : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
                        }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "󰅖"; color: xm.containsMouse ? Theme.coral : Theme.muted; font.family: Theme.font; font.pixelSize: 13
                               MouseArea { id: xm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Agenda.remove(row.modelData.id) } }
                    }
                }
                Text { visible: root.existing.length === 0; text: "nothing set"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            }
        }
    }
}

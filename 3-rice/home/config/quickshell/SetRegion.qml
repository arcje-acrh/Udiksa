// SetRegion.qml -- Settings > Region: time + timezone (searchable), network time, language (UTF-8 locales).
// timedatectl / localectl ask for the password through the shell's own prompt (polkit).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    property var td: ({})             // timedatectl show
    property string lang: ""
    property var zones: []
    property var locales: []
    property string zq: ""
    function reload() { tdProc.running = true; locProc.running = true }
    Component.onCompleted: { zoneProc.running = true; reload() }
    Process {
        id: tdProc
        command: ["timedatectl", "show"]
        stdout: StdioCollector { onStreamFinished: { const o = {}; text.trim().split("\n").forEach(l => { const i = l.indexOf("="); o[l.slice(0, i)] = l.slice(i + 1) }); page.td = o } }
    }
    Process {
        id: locProc
        command: ["sh", "-c", "localectl status | sed -n 's/.*LANG=//p'; echo ===; localectl list-locales"]
        stdout: StdioCollector { onStreamFinished: { const p = text.split("===\n"); page.lang = p[0].trim(); page.locales = (p[1] || "").trim().split("\n").filter(l => l) } }
    }
    Process {
        id: zoneProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: page.zones = text.trim().split("\n") }
    }
    Process { id: act; onExited: page.reload() }
    function run(cmd) { act.command = cmd; act.running = true }
    SystemClock { id: clock; precision: SystemClock.Seconds }

    SetGroup { title: "Time" }
    SetRow {
        title: Qt.formatDateTime(clock.date, "HH:mm:ss")
        desc: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy") + "   ·   " + (page.td.Timezone || "")
    }
    SetRow {
        title: "Set time automatically"
        desc: page.td.NTPSynchronized === "yes" ? "From the internet (in sync)." : "From the internet."
        Seg { options: ["On", "Off"]; current: page.td.NTP === "yes" ? 0 : 1; onPicked: (i) => page.run(["timedatectl", "set-ntp", i === 0 ? "true" : "false"]) }
    }
    SetRow {
        title: "Hardware clock"
        desc: page.td.LocalRTC === "yes" ? "Kept in local time, so Windows shows the same time (dual boot)." : "Kept in UTC."
    }
    SetRow {
        title: "Timezone"
        desc: "Search, then click one."
        SetInput { width: 260; placeholder: "e.g. Kolkata, London…"; onTextChanged: page.zq = text }
    }
    Flow {
        width: parent.width
        spacing: 6
        visible: page.zq.length >= 2
        Repeater {
            model: page.zq.length >= 2 ? page.zones.filter(z => z.toLowerCase().indexOf(page.zq.toLowerCase()) >= 0).slice(0, 24) : []
            delegate: SetButton {
                required property var modelData
                text: modelData
                accent: modelData === page.td.Timezone
                onClicked: page.run(["timedatectl", "set-timezone", modelData])
            }
        }
    }

    SetGroup { title: "Language" }
    SetRow {
        title: "System language"
        desc: "Language and formats of apps (" + page.lang + "). Takes effect at the next login. More languages: enable them in /etc/locale.gen and run locale-gen."
        Column {
            spacing: 6
            Repeater {
                model: page.locales
                delegate: SetButton {
                    required property var modelData
                    width: 220
                    text: modelData
                    accent: modelData === page.lang
                    onClicked: page.run(["localectl", "set-locale", "LANG=" + modelData])
                }
            }
        }
    }
}

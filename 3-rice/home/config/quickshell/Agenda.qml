// Agenda.qml -- holidays + your reminders and alarms (used by the calendar, ClockPanel.qml).
//   holidays   India, from Google's public holiday calendar (ICS). Cached in
//              ~/.cache/quickshell/holidays-in.ics, downloaded again when older than 30 days (curl).
//              Each: { name, pub } -- pub = public holiday, otherwise an observance.
//   items      saved in ~/.local/state/quickshell/agenda.json:
//              { id, date "YYYY-MM-DD", time "HH:MM" ("" = all day, events only), text,
//                kind "event"|"reminder"|"alarm" (events are only shown, they never go off), repeat "once"|"daily"|"yearly",
//                last "YYYY-MM-DD" (day it last went off) }
//   firing     a timer checks every 15 s, also while the notch is closed (started from shell.qml).
//              reminder = a notification. alarm = the alarm sound on repeat + an urgent notification with
//              "Stop"; the sound stops on Stop / closing the notification / after 2 min / `qs ipc call agenda stop`.
//              Missed while asleep/off: goes off once when the shell sees it, if at most 12 h late.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string icsPath: home + "/.cache/quickshell/holidays-in.ics"
    readonly property string icsUrl: "https://calendar.google.com/calendar/ical/en.indian%23holiday%40group.v.calendar.google.com/public/basic.ics"
    readonly property string alarmSound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

    function init() {}                           // referenced from shell.qml so the timer runs from login

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function key(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }

    // ---------------- holidays ----------------
    property var holidays: ({})                  // "YYYY-MM-DD" -> [{ name, pub }]
    FileView {
        id: ics
        path: root.icsPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseIcs(text())
    }
    function parseIcs(t) {
        const lines = t.replace(/\r/g, "").replace(/\n[ \t]/g, "").split("\n")   // unfold continued lines
        const out = {}
        let ev = null
        for (const l of lines) {
            if (l === "BEGIN:VEVENT") ev = {}
            else if (l === "END:VEVENT") {
                if (ev && ev.date && ev.name) {
                    (out[ev.date] = out[ev.date] || []).push({ name: ev.name, pub: ev.pub })
                }
                ev = null
            } else if (ev) {
                if (l.startsWith("DTSTART")) {
                    const v = l.split(":")[1] || ""
                    ev.date = v.substr(0, 4) + "-" + v.substr(4, 2) + "-" + v.substr(6, 2)
                } else if (l.startsWith("SUMMARY:")) ev.name = l.substring(8).replace(/\\,/g, ",").replace(/\\;/g, ";")
                else if (l.startsWith("DESCRIPTION:")) ev.pub = l.indexOf("Public holiday") >= 0
            }
        }
        for (const k in out) out[k].sort((a, b) => b.pub - a.pub)
        holidays = out
    }
    // download when missing or older than 30 days (to a temp file, then moved: never a half file)
    Process {
        id: fetch
        running: true
        command: ["sh", "-c",
            "f=\"$1\"; mkdir -p \"$(dirname \"$f\")\"; " +
            "if [ ! -s \"$f\" ] || [ -n \"$(find \"$f\" -mtime +30)\" ]; then " +
            "curl -sfL --max-time 20 -o \"$f.tmp\" \"$2\" && grep -q BEGIN:VEVENT \"$f.tmp\" && mv \"$f.tmp\" \"$f\"; rm -f \"$f.tmp\"; fi",
            "sh", root.icsPath, root.icsUrl]
    }
    Timer { interval: 6 * 3600 * 1000; repeat: true; running: true; onTriggered: fetch.running = true }
    function holidaysOn(d) { return holidays[key(d)] || [] }

    // ---------------- reminders + alarms ----------------
    property var items: []
    FileView {
        id: store
        path: root.home + "/.local/state/quickshell/agenda.json"
        printErrors: false
        watchChanges: true                       // hand edits apply at once
        onFileChanged: reload()
        onLoaded: { try { root.items = JSON.parse(text()) } catch (e) { root.items = [] } }
    }
    Process { id: mkdir; running: true; command: ["mkdir", "-p", root.home + "/.local/state/quickshell"] }
    function save() { store.setText(JSON.stringify(items, null, 2)) }

    // items that show on day d (daily / yearly ones from their start date on), sorted by time
    // (all-day events have time "" and come first)
    function itemsOn(d) {
        const k = key(d)
        return items.filter(i => i.repeat === "daily" ? i.date <= k
                               : i.repeat === "yearly" ? (i.date <= k && i.date.substr(5) === k.substr(5))
                               : i.date === k)
                    .sort((a, b) => a.time.localeCompare(b.time))
    }
    function hasItems(d) { return itemsOn(d).length > 0 }

    function add(date, time, text, kind, repeat) {
        const now = new Date()
        const it = { id: Date.now().toString(36), date: key(date), time: time, text: text || (kind === "alarm" ? "Alarm" : kind === "event" ? "Event" : "Reminder"),
                     kind: kind, repeat: repeat, last: "" }
        // a daily one whose time already passed today starts tomorrow (does not go off right away)
        if (repeat !== "once" && kind !== "event" && it.date <= key(now) && due(it, now) <= now) it.last = key(now)
        items = items.concat([it])
        save()
    }
    function remove(id) { items = items.filter(i => i.id !== id); save() }

    // when item goes off: on the day of `now` (daily), on its date this year (yearly), on its date (once)
    function due(it, now) {
        const hm = (it.time || "00:00").split(":")
        const start = new Date(it.date + "T00:00:00")
        const day = it.repeat === "daily" ? now
                  : it.repeat === "yearly" ? new Date(now.getFullYear(), start.getMonth(), start.getDate())
                  : start
        return new Date(day.getFullYear(), day.getMonth(), day.getDate(), parseInt(hm[0]), parseInt(hm[1]), 0)
    }

    Timer {
        interval: 15000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: root.check()
    }
    function check() {
        const now = new Date()
        let changed = false
        const next = items.map(i => Object.assign({}, i))
        for (const it of next) {
            if (it.kind === "event" || !it.time) continue           // events are only shown, they never go off
            const d = due(it, now)
            const dayKey = key(d)
            if (now >= d && now - d < 12 * 3600 * 1000 && it.last !== dayKey) {
                it.last = dayKey
                changed = true
                fire(it)
            }
        }
        if (changed) { items = next; save() }
    }

    // ---------------- going off ----------------
    // ringing: an alarm or a finished timer. Stop / Snooze (5 min; a timer: +1 min) from the calendar's
    // ringing screen, the notification's buttons (clicking the notification = Stop), or IPC.
    property bool ringing: false
    property string ringKind: ""                 // "alarm" | "timer"
    property string ringTitle: ""
    property string ringText: ""
    function fire(it) {
        if (it.kind === "alarm") ring("alarm", it.time + "  Alarm", it.text)
        else {
            Quickshell.execDetached(["notify-send", "-a", "Reminder", "-i", "appointment-soon",
                                     "󰃀  " + it.time + "  Reminder", it.text])
            Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/message.oga"])
        }
    }
    function ring(kind, title, text) {
        if (ringing) stop()
        ringKind = kind; ringTitle = title; ringText = text; ringing = true
        ringFor.restart()
        beep.restart()
        const second = kind === "timer" ? "more=+1 min" : "snooze=Snooze 5 min"
        alarmNote.command = ["notify-send", "-u", "critical", "-a", kind === "timer" ? "Timer" : "Alarm",
                             "-A", "default=Stop", "-A", "stop=Stop", "-A", second, "--wait",
                             (kind === "timer" ? "󱎫  " : "󰀠  ") + title, text]
        alarmNote.running = true
    }
    function stop() {
        ringing = false; beep.stop(); ringFor.stop(); player.running = false
        for (const n of Notifs.list) if (n.appName === "Alarm" || n.appName === "Timer") n.dismiss()
    }
    function snooze() {                           // alarm: again in 5 min; timer: 1 more minute
        const k = ringKind, t = ringTitle, x = ringText
        stop()
        if (k === "timer") startTimer(60, x)
        else { snoozeTitle = t; snoozeText = x; snoozeAt = Date.now() + 5 * 60000; snoozeTimer.restart() }
    }
    property real snoozeAt: 0
    property string snoozeTitle: ""
    property string snoozeText: ""
    Timer { id: snoozeTimer; interval: 5 * 60000; onTriggered: { root.snoozeAt = 0; root.ring("alarm", root.snoozeTitle + " (snoozed)", root.snoozeText) } }
    function cancelSnooze() { snoozeTimer.stop(); snoozeAt = 0 }

    Process {
        id: alarmNote
        stdout: StdioCollector { id: noteOut }
        onExited: {                               // prints the chosen action; closed = stop
            const a = noteOut.text.trim()
            if (!root.ringing) return
            if (a === "snooze" || a === "more") root.snooze(); else root.stop()
        }
    }
    Timer { id: ringFor; interval: 120000; onTriggered: root.stop() }      // rings at most 2 min
    Timer {
        id: beep
        interval: 1000; repeat: true; triggeredOnStart: true
        running: false
        onTriggered: if (root.ringing && !player.running) player.running = true   // one sound at a time
    }
    Process { id: player; command: ["pw-play", root.alarmSound] }           // killed by stop()

    // ---------------- countdown timer (one at a time; not kept across a shell restart) ----------------
    property real timerEnd: 0                    // ms timestamp while running
    property real timerLeft: 0                   // ms left while paused
    property real timerTotal: 0
    property string timerLabel: ""
    readonly property bool timerOn: timerEnd > 0 || timerLeft > 0
    readonly property bool timerPaused: timerLeft > 0 && timerEnd === 0
    function startTimer(sec, label) {
        timerTotal = sec * 1000; timerLeft = 0; timerLabel = label || ""
        timerEnd = Date.now() + timerTotal
        timerDone.interval = timerTotal; timerDone.restart()
    }
    function pauseTimer() { if (timerEnd > 0) { timerLeft = Math.max(1, timerEnd - Date.now()); timerEnd = 0; timerDone.stop() } }
    function resumeTimer() { if (timerPaused) { timerEnd = Date.now() + timerLeft; timerDone.interval = timerLeft; timerLeft = 0; timerDone.restart() } }
    function cancelTimer() { timerEnd = 0; timerLeft = 0; timerDone.stop() }
    function fmt(ms) {                           // 1:05:09 / 4:07
        const s = Math.max(0, Math.ceil(ms / 1000)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
        return (h ? h + ":" + pad(m) : m) + ":" + pad(x)
    }
    Timer {
        id: timerDone
        onTriggered: {
            const total = root.timerTotal, label = root.timerLabel
            root.timerEnd = 0; root.timerLeft = 0
            root.ring("timer", "Timer done", (label ? label + " · " : "") + root.fmt(total))
        }
    }

    IpcHandler {
        target: "agenda"
        function stop(): void { root.stop() }
        function snooze(): void { root.snooze() }
        function cancel(): void { root.cancelTimer(); root.cancelSnooze() }
        // add("2026-10-02 07:30" or "07:30" = today, "text", "event" | "alarm" | "reminder", "once" | "daily" | "yearly")
        function add(when: string, text: string, kind: string, repeat: string): void {
            const m = when.trim().match(/^(?:(\d{4}-\d{2}-\d{2})\s+)?(\d{1,2}):(\d{2})$/)
            if (!m) return
            root.add(m[1] ? new Date(m[1] + "T00:00:00") : new Date(), root.pad(parseInt(m[2])) + ":" + m[3], text,
                     kind === "alarm" || kind === "event" ? kind : "reminder", repeat === "daily" || repeat === "yearly" ? repeat : "once")
        }
        function timer(minutes: string): void { root.startTimer(Math.round(parseFloat(minutes) * 60), "") }
        function test(kind: string): void { root.fire({ time: Qt.formatTime(new Date(), "HH:mm"), text: "Test " + kind, kind: kind }) }
    }
}

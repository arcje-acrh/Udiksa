// SetPower.qml -- Settings > Battery & sleep (user 2026-09-28): battery state + health, charge limit, when
// the screen locks / turns off / the laptop sleeps (separately on battery and on the charger, like Windows),
// "hibernate after sleeping for", and what the lid and the power button do.
// Back end: `rice-settings power <key> <value>` -> ~/.config/hypr/hypridle.conf (timers, via ~/.local/bin/rice-idle)
// and /usr/local/bin/udiksa-power (lid, power button, hibernate delay -> logind / systemd sleep).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

SetPage {
    id: page

    // ---- the saved values (a local copy so every change shows at once) ----
    property var p: ({})
    readonly property var hp: host && host.hv ? host.hv.power : undefined
    onHpChanged: if (hp) p = JSON.parse(JSON.stringify(hp))
    readonly property bool canHib: p.can_hibernate === true

    // timers go through fixed stops (minutes; 0 = never)
    readonly property var stops: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300]
    readonly property var hibStops: [0, 15, 30, 60, 120, 180, 240, 360, 480, 720]
    function label(m) { return m === 0 ? "never" : m < 60 ? m + " min" : (m / 60) + " h" }
    function nearest(list, m) {
        let best = 0
        list.forEach((x, i) => { if (Math.abs(x - m) < Math.abs(list[best] - m)) best = i })
        return best
    }

    // ---- saving: changes wait 0.6 s (dragging a bar), then run in one go ----
    property var pending: ({})
    function put(key, value) {
        const c = JSON.parse(JSON.stringify(p)); c[key] = value; p = c
        const q = JSON.parse(JSON.stringify(pending)); q[key] = value; pending = q
        saveTimer.restart()
    }
    Timer {
        id: saveTimer; interval: 600
        onTriggered: {
            const args = []
            Object.keys(page.pending).forEach(k => { args.push(k); args.push(String(page.pending[k])) })
            page.pending = ({})
            page.err = ""
            saver.command = ["sh", "-c", "h=$1; shift; while [ $# -gt 1 ]; do \"$h\" power \"$1\" \"$2\" >/dev/null; shift 2; done",
                             "sh", page.host.helper].concat(args)
            saver.running = true
        }
    }
    property string err: ""
    Process {
        id: saver
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.err = text.trim() }
        onExited: page.host.load()
    }

    // ---- battery state (UPower, live) + health (upower -i, on open) ----
    readonly property var bat: UPower.displayDevice
    function hm(sec) { const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60); return h > 0 ? h + " h " + m + " min" : m + " min" }
    readonly property string batLine: !bat ? "" :
        bat.state === UPowerDeviceState.Charging ? "Charging at " + Math.abs(bat.changeRate).toFixed(1) + " W" + (bat.timeToFull > 0 ? ", full in " + hm(bat.timeToFull) : "") + "."
      : bat.state === UPowerDeviceState.Discharging ? "On battery, using " + Math.abs(bat.changeRate).toFixed(1) + " W" + (bat.timeToEmpty > 0 ? ", about " + hm(bat.timeToEmpty) + " left" : "") + "."
      : bat.state === UPowerDeviceState.FullyCharged ? "Full, on the charger."
      : "On the charger, not charging (held at the charge limit)."
    property string health: ""
    Process {
        running: true
        command: ["sh", "-c", "upower -i $(upower -e | grep -m1 battery)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = (k) => { const m = text.match(new RegExp(k + ":\\s+(.+)")); return m ? m[1].trim() : "" }
                page.health = g("capacity") ? g("capacity").replace(/(\.\d)\d*/, "$1") + " of its original capacity (" + g("energy-full") + " of " + g("energy-full-design") + ")"
                    + (g("charge-cycles") && g("charge-cycles") !== "N/A" ? ", " + g("charge-cycles") + " charge cycles" : "") + "." : "Unknown."
            }
        }
    }

    // ---- battery limit (this laptop only obeys 60 / 80 / 100) ----
    property int limit: -1
    Process {
        running: true
        command: ["asusctl", "battery", "info"]
        stdout: StdioCollector { onStreamFinished: { const m = text.match(/(\d+)%/); if (m) page.limit = parseInt(m[1]) } }
    }
    function setLimit(x) { Power.cancelOnce(false); page.limit = x; Quickshell.execDetached(["asusctl", "battery", "limit", String(x)]) }

    // a timer row: key in p, stops, title, description
    component TimerRow: SetRow {
        id: tr
        property string key
        property var list: page.stops
        SetNum {
            value: page.nearest(tr.list, page.p[tr.key] ?? 0)
            from: 0; to: tr.list.length - 1; step: 1
            labels: tr.list.map(m => page.label(m))
            onChanged: (i) => page.put(tr.key, tr.list[i])
        }
    }
    // an action row: key in p, choices
    component ActionRow: SetRow {
        id: ar
        property string key
        property var acts: page.canHib ? ["sleep", "hibernate", "lock", "poweroff", "ignore"] : ["sleep", "lock", "poweroff", "ignore"]
        readonly property var names: ({ sleep: "Sleep", hibernate: "Hibernate", lock: "Lock", poweroff: "Shut down", ignore: "Nothing" })
        Seg {
            options: ar.acts.map(a => ar.names[a])
            current: ar.acts.indexOf(page.p[ar.key] ?? "")
            onPicked: (i) => page.put(ar.key, ar.acts[i])
        }
    }

    readonly property bool hasBat: bat !== null && bat.isPresent      // a desktop has none: the battery rows hide
    SetGroup { title: "Battery"; visible: page.hasBat }
    SetRow {
        visible: page.hasBat
        title: page.bat ? Math.round(page.bat.percentage * 100) + " %" : "No battery"
        desc: page.batLine
    }
    SetRow {
        visible: page.hasBat
        title: "Health"
        desc: page.health
    }
    SetRow {
        visible: Power.asus && page.hasBat
        title: "Battery charge limit"
        desc: Power.oneshotRestore > 0 ? "Charging to 100 % once, then back to " + Power.oneshotRestore + " %." : "This laptop supports 60, 80 or 100 %."
        Row {
            spacing: 8
            Seg { readonly property var vals: [60, 80, 100]; options: vals.map(x => x + " %"); current: vals.indexOf(page.limit); onPicked: (i) => page.setLimit(vals[i]) }
            SetButton {
                text: Power.oneshotRestore > 0 ? "Cancel 100 % once" : "100 % once"
                enabled: Power.oneshotRestore > 0 || (page.limit > 0 && page.limit < 100)
                onClicked: { if (Power.oneshotRestore > 0) { page.limit = Power.oneshotRestore; Power.cancelOnce(true) } else { Power.chargeOnce(page.limit); page.limit = 100 } }
            }
        }
    }

    SetGroup { title: "When idle" }
    TimerRow { key: "lock"; title: "Lock after"; desc: "Minutes without input. It always locks before sleeping, too." }
    TimerRow { key: "off_bat"; title: "Screen off on battery" }
    TimerRow { key: "off_ac"; title: "Screen off on the charger"; desc: "Any key or mouse move turns it back on." }
    TimerRow { key: "sleep_bat"; title: "Sleep on battery" }
    TimerRow { key: "sleep_ac"; title: "Sleep on the charger"; desc: "Playing video or music keeps the laptop awake." }
    TimerRow {
        key: "hib_after"; list: page.hibStops
        visible: page.canHib
        title: "Hibernate after sleeping for"
        desc: "Sleep keeps using a little battery; after this long the laptop saves everything to disk and turns off completely. Opening it restores all your windows."
    }
    SetRow {
        visible: !page.canHib && page.p.can_hibernate !== undefined
        title: "Hibernate"
        desc: "Not set up on this system (needs a swap file: ~/Udiksa/3-rice/system/setup-hibernation.sh)."
    }

    SetGroup { title: "Lid and power button" }
    ActionRow { key: "lid_bat"; title: "Closing the lid on battery" }
    ActionRow { key: "lid_ac"; title: "Closing the lid on the charger" }
    ActionRow { key: "lid_dock"; title: "Closing the lid with a monitor plugged in"; desc: "Nothing = keep working on the monitor." }
    ActionRow { key: "power_key"; title: "Power button"; desc: "Holding it for a few seconds always forces the laptop off." }
    SetRow {
        visible: page.err !== ""
        title: "Not saved"
        desc: page.err
    }
}

// Route.qml -- singleton: where every playing stream goes (laptop speaker / Bluetooth), from `udiksa route`,
// and a memory of the choices. A stream lives only while its tab does (Zen drops it after a long pause and makes
// a new one when you resume), so the choice is remembered per app + page title and re-applied to the new stream
// (pins, saved in ~/.local/state/quickshell/route-pins.json). Event-driven: `pactl subscribe` wakes it when a
// stream appears or changes; the panels also call refresh() from their own timers while open.
// `both` = the volume keys move every output in use (`udiksa volume both`).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    property var data: ({ speaker: null, bt: null, apps: [], sinks: [] })
    property bool both: false
    readonly property var active: data.sinks.filter(s => s.active)
    readonly property bool split: active.length > 1          // apps play on more than one output
    readonly property string bin: Quickshell.env("HOME") + "/.local/lib/udiksa/route"
    readonly property string udiksa: Quickshell.env("HOME") + "/.local/bin/udiksa"
    readonly property var players: Mpris.players.values.filter(p => !/playerctld/i.test((p.dbusName || "") + (p.identity || "")))

    function isJunk(t) { return !t || t === "(null)" || t === "AudioStream" }
    function playerOf(a) {   // the MPRIS player of a stream, matched by desktop entry / identity
        const n = a.app.toLowerCase(), b = a.bin.toLowerCase()
        return players.find(p => {
            const de = (p.desktopEntry || "").toLowerCase(), id = (p.identity || "").toLowerCase()
            return (de && (n === de || b.indexOf(de) >= 0)) || (n && id.indexOf(n) >= 0)
        }) || null
    }
    // every stream with its display title and a memory key. A paused tab loses its title ("(null)" / "AudioStream"):
    // a playing one takes the player's track title, a paused one stays "<app> . paused" and has no key
    readonly property var streams: {
        const out = data.apps.map(a => {
            const junk = isJunk(a.title)
            return { index: a.index, app: a.app, bin: a.bin, sink: a.sink, corked: a.corked, player: playerOf(a),
                     junk: junk, title: junk ? a.app + (a.corked ? " \u00b7 paused" : "") : a.title, key: "" }
        })
        for (const r of out)
            if (r.junk && !r.corked && r.player && r.player.trackTitle && !out.some(o => o.title === r.player.trackTitle)) {
                r.title = r.player.trackTitle; r.junk = false
            }
        for (const r of out) if (!r.junk) r.key = r.app + "|" + r.title
        return out
    }

    // ---- memory: key -> "speaker" | "bt" ----
    property var pins: ({})
    property var idxTarget: ({})       // stream index -> last output we know it was given (carries a pin over a title change)
    property var tried: ({})           // stream index -> output we already asked for (no retry loop)
    FileView {
        id: pinFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/route-pins.json"
        printErrors: false
        onLoaded: { try { root.pins = JSON.parse(text()) } catch (e) {} }
    }
    function savePins() {
        const k = Object.keys(pins)
        if (k.length > 100) { const p = {}; for (const x of k.slice(-100)) p[x] = pins[x]; pins = p }   // ponytail: newest 100
        pinFile.setText(JSON.stringify(pins))
    }
    function apply() {
        let changed = false
        const p = pins, want = {}
        for (const s of streams) {
            if (s.corked) continue
            let t = s.key ? p[s.key] : undefined
            if (!t && s.key && idxTarget[s.index]) { p[s.key] = t = idxTarget[s.index]; changed = true }   // title changed: same tab
            const sink = t === "speaker" ? data.speaker : (t === "bt" ? data.bt : null)
            if (sink && s.sink !== sink && tried[s.index] !== t) { want[s.index] = t }
        }
        for (const i in want) {
            tried[i] = want[i]; idxTarget[i] = want[i]
            Quickshell.execDetached([bin, i, want[i]])
        }
        if (Object.keys(want).length) refreshSoon.restart()
        if (changed) { pins = p; savePins() }
    }
    onStreamsChanged: apply()

    function refresh() { if (!get.running) get.running = true }
    function move(idxs, target) {     // a choice by the user: remembered for those streams' tabs
        for (const s of streams) if (idxs.indexOf(s.index) >= 0) {
            idxTarget[s.index] = target; tried[s.index] = target
            if (s.key) pins[s.key] = target
        }
        savePins()
        set.command = [bin, idxs.join(","), target]; set.running = true
    }
    function setBoth(on) { root.both = on; Quickshell.execDetached([udiksa, "volume", "both", on ? "on" : "off"]) }

    Timer { id: refreshSoon; interval: 600; onTriggered: root.refresh() }
    Process {
        id: get
        command: [root.bin]
        stdout: StdioCollector { onStreamFinished: { try { root.data = JSON.parse(text) } catch (e) {} } }
    }
    Process { id: set; onExited: root.refresh() }
    Process {
        running: true
        command: [root.udiksa, "volume", "both"]
        stdout: StdioCollector { onStreamFinished: root.both = text.trim() === "on" }
    }
    Process {   // a stream appeared or changed (new tab, resumed after a pause, new title): look again soon
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser { onRead: (l) => { if (l.indexOf("sink-input") >= 0 && l.indexOf("remove") < 0) refreshSoon.restart() } }
    }
    Component.onCompleted: refresh()
}

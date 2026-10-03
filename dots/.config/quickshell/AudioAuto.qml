// AudioAuto.qml -- "auto always" for sound output (user 2026-09-27): when headphones / a headset / a Bluetooth or USB
// audio device appears, it becomes the default output at once (WirePlumber otherwise sticks to the last output you
// picked, e.g. the speakers). When it goes away, WirePlumber falls back to the previous output by itself.
// Devices present when the shell starts are left alone (only NEW ones switch).
// On / off: Settings > Sound ("Switch to new headphones"), saved as {"auto": bool} in ~/.local/state/quickshell/audio.json.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    property var known: ({})              // node id -> true
    property bool primed: false
    property bool enabled: true
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/audio.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.enabled = JSON.parse(text()).auto !== false } catch (e) { root.enabled = true } }
    }
    function external(n) {
        const s = ((n.name || "") + " " + (n.description || "") + " " + (n.nickname || "")).toLowerCase()
        return /bluez|usb|headphone|headset|earbud|airpod|buds/.test(s)
    }
    onSinksChanged: {
        const k = {}
        for (const n of sinks) {
            k[n.id] = true
            if (primed && enabled && !known[n.id] && external(n)) Pipewire.preferredDefaultAudioSink = n
        }
        known = k
    }
    Timer { interval: 3000; running: true; onTriggered: { root.primed = true } }   // skip devices found at start-up
}

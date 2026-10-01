// Toasts.qml -- singleton: short messages in the slim notch when something changes by itself (Osd.toast):
//   charger in / out, audio output or microphone switched, keyboard layout switched, VPN (Tailscale) on / off or
//   exit node changed, do not disturb on / off. Off with Settings > Notifications > "Status messages" (Prefs.toasts).
// Low battery (always, unless the levels are 0 in Settings > Battery & sleep): at Prefs.batWarn % an amber message
// + a notification, at Prefs.batCrit % an urgent one. Each fires once until the charger comes back or the level rises.
// Started from shell.qml (Toasts.init()); nothing shows for the first seconds after a (re)start.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Singleton {
    id: root
    function init() {}
    property bool armed: false
    Timer { interval: 3000; running: true; onTriggered: root.armed = true }
    readonly property bool on: armed && Prefs.v.toasts !== false
    function say(icon, text, warn) { if (root.on) Osd.toast(icon, text, warn === true) }

    // ---------- charger ----------
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property int pct: hasBat ? Math.round(bat.percentage * 100) : 100
    readonly property bool onBattery: UPower.onBattery
    onOnBatteryChanged: {
        if (!hasBat) return
        say(onBattery ? "󰂃" : "󰂄", onBattery ? "On battery · " + pct + "%" : "Charging · " + pct + "%")
        if (!onBattery) { warned = false; critWarned = false }
    }

    // ---------- low battery ----------
    property bool warned: false
    property bool critWarned: false
    onPctChanged: checkBattery()
    function checkBattery() {
        if (!armed || !hasBat) return
        const w = Prefs.v.batWarn || 0, c = Prefs.v.batCrit || 0
        if (!onBattery) return
        if (warned && pct > w + 2) warned = false
        if (critWarned && pct > c + 2) critWarned = false
        if (c > 0 && pct <= c && !critWarned) {
            critWarned = true; warned = true
            Osd.toast("󰂃", "Battery at " + pct + "% · plug in now", true)
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Battery", "-i", "battery-caution",
                                     "Battery at " + pct + "%", "Plug in the charger, the laptop will sleep soon."])
        } else if (w > 0 && pct <= w && !warned) {
            warned = true
            Osd.toast("󰁻", "Battery low · " + pct + "%", true)
            Quickshell.execDetached(["notify-send", "-a", "Battery", "-i", "battery-low", "Battery low", pct + "% left."])
        }
    }
    onArmedChanged: checkBattery()

    // ---------- audio devices ----------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    function nodeName(n) { return n ? (n.description || n.nickname || n.name || "") : "" }
    property string lastSink: ""
    property string lastSource: ""
    readonly property string sinkName: nodeName(Pipewire.defaultAudioSink)
    readonly property string sourceName: nodeName(Pipewire.defaultAudioSource)
    onSinkNameChanged: { if (sinkName !== "" && lastSink !== "" && sinkName !== lastSink) say("󰓃", sinkName); if (sinkName !== "") lastSink = sinkName }
    onSourceNameChanged: { if (sourceName !== "" && lastSource !== "" && sourceName !== lastSource) say("󰍬", sourceName); if (sourceName !== "") lastSource = sourceName }

    // ---------- keyboard layout (Hyprland event "activelayout": "<keyboard>,<layout name>") ----------
    property string lastLayout: ""
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            const name = event.data.slice(event.data.lastIndexOf(",") + 1)
            if (name && root.lastLayout !== "" && name !== root.lastLayout) root.say("󰌌", name)
            if (name) root.lastLayout = name
        }
    }

    // ---------- VPN (Tailscale, only where it is installed) ----------
    readonly property bool vpn: Tailscale.installed && Tailscale.running
    readonly property string exitNode: Tailscale.exitNodeId
    // the first answer of `tailscale status` after start is only remembered, not announced
    property string lastVpn: ""
    property string lastExit: "?"
    readonly property string tsBackend: Tailscale.backend
    onTsBackendChanged: if (lastVpn === "" && tsBackend !== "") lastVpn = vpn ? "1" : "0"
    onVpnChanged: {
        if (!Tailscale.installed || Tailscale.backend === "") return
        const s = vpn ? "1" : "0"
        if (lastVpn !== "" && s !== lastVpn) say("󰖂", vpn ? "Tailscale connected" : "Tailscale off")
        lastVpn = s
    }
    onExitNodeChanged: {
        if (vpn && lastExit !== "?" && exitNode !== lastExit) say("󰖂", exitNode !== "" ? "Through an exit node" : "Exit node off")
        lastExit = exitNode
    }

    // ---------- do not disturb ----------
    readonly property bool dnd: Notifs.dnd
    onDndChanged: say(dnd ? "󰂛" : "󰂚", dnd ? "Do not disturb on" : "Notifications on")
}

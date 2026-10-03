// Osd.qml -- singleton: WHAT the key feedback should show. The notch (Notch.qml) draws it inline in the
// slim notch while `shown` is true (Theme.feedbackTime after the last change).
//   * volume / mute and mic mute: noticed automatically from PipeWire (keys, bar scroll, any app)
//   * keyboard light: the firmware changes it itself and the keys never reach Hyprland, so a tiny
//     watcher waits on the kernel's `brightness_hw_changed` notification (no polling)
//   * screen brightness: the Hyprland key binds call `qs ipc call osd brightness` after changing it
//     (sysfs gives no change events for it), and this reads the new value back
//   * Caps Lock / Num Lock: non-consuming Hyprland binds call `qs ipc call osd caps|num`; the state is read
//     from the keyboard LEDs in /sys/class/leds
//   * airplane mode: noticed automatically from `rfkill event` (panel toggle, or anything else)
//   * touchpad on/off: ~/.local/bin/touchpad-toggle (F10) calls `qs ipc call osd touchpad on|off`
//   * short messages ("toasts", toast()): charger, audio device, keyboard layout, VPN, do not disturb, low battery
//     (Toasts.qml), keep awake / game mode (Modes.qml), recording (Recorder.qml), a picked colour with its swatch
//     (`qs ipc call osd colour "#rrggbb"`, ~/.local/bin/rice-pick), any script: `qs ipc call osd say <icon> <text>`
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property string icon: ""
    property real level: 0          // 0..1 of the bar
    property real mark: -1          // bar position where the "extra" range starts (volume above 100 %), -1 = none
    property string label: ""       // right-hand text ("65%", "Muted", "High", ...)
    property bool off: false        // grey out the bar + icon (muted / light off)
    property bool showBar: true
    property bool shown: false
    property bool warn: false        // amber text (low battery, ...)
    property string swatch: ""       // a colour square next to the text (colour picker)
    property int holdFor: Theme.feedbackTime

    function show(icon, level, label, off, showBar, mark) {
        root.icon = icon; root.level = Math.max(0, Math.min(1, level)); root.label = label
        root.mark = mark === undefined ? -1 : mark
        root.off = off; root.showBar = showBar
        root.warn = false; root.swatch = ""; root.holdFor = Theme.feedbackTime
        root.shown = true
        hideTimer.restart()
    }
    // a message without a bar; warn = amber; stays a little longer than key feedback (it is read, not watched)
    function toast(icon, label, warn, swatch) {
        root.show(icon, 1, label, false, false)
        root.warn = warn === true; root.swatch = swatch || ""; root.holdFor = Theme.feedbackTime + 1000
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: root.holdFor; onTriggered: root.shown = false }

    // ---------- volume + mic (PipeWire) ----------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // PipeWire fills in the real values right after start-up / a device switch; ignore those.
    property bool armed: false
    Timer { id: armTimer; interval: 1500; running: true; onTriggered: root.armed = true }
    onSinkChanged: { root.armed = false; armTimer.restart() }
    onSourceChanged: { root.armed = false; armTimer.restart() }

    function showVolume() {
        if (!root.armed || !root.sink || !root.sink.audio) return
        const v = root.sink.audio.volume, m = root.sink.audio.muted
        // the bar spans 0-125 %; the part above 100 % is shown in red (Notch.qml)
        root.show(m ? "󰖁" : (v < 0.34 ? "󰕿" : (v < 0.67 ? "󰖀" : "󰕾")), v / 1.25,
                  m ? "Muted" : Math.round(v * 100) + "%", m, true, 1 / 1.25)
    }
    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.showVolume() }
        function onMutedChanged() { root.showVolume() }
    }
    Connections {
        target: root.source ? root.source.audio : null
        function onMutedChanged() {
            if (!root.armed) return
            const m = root.source.audio.muted
            root.show(m ? "󰍭" : "󰍬", 1, m ? "Mic off" : "Mic on", m, false)
        }
    }

    // ---------- keyboard light (kernel notification, 0..3) ----------
    function showKbd(raw, max) {
        const names = ["Off", "Low", "Medium", "High"]
        root.show("󰌌", raw / max, max === 3 ? names[raw] : Math.round(raw / max * 100) + "%", raw === 0, true)
    }
    Process {
        running: true
        command: ["python3", "-u", "-c", `
import ctypes, select, signal
ctypes.CDLL(None).prctl(1, signal.SIGTERM)   # PR_SET_PDEATHSIG: exit together with Quickshell
p = "/sys/class/leds/asus::kbd_backlight/brightness_hw_changed"
f = open(p)
po = select.poll()
po.register(f, select.POLLPRI | select.POLLERR)
def read():
    f.seek(0)
    try: return f.read().strip()
    except OSError: return None   # no change reported yet since boot
read()                            # arm the notification
while True:
    po.poll()
    v = read()
    if v is not None: print(v)
`]
        stdout: SplitParser {
            onRead: (line) => {
                const raw = parseInt(line)
                if (isNaN(raw)) return
                root.showKbd(raw, 3)
                // switched on: the colour chosen / the theme's accent could not be sent while it was off (that would
                // light it up), so send it now -- only where the laptop's keyboard tool exists (~/.local/bin/rice-kbd)
                if (raw > 0 && root.kbdPrev <= 0)
                    Quickshell.execDetached(["sh", "-c", "[ -x \"$HOME/.local/bin/rice-kbd\" ] && exec \"$HOME/.local/bin/rice-kbd\" lit"])
                root.kbdPrev = raw
            }
        }
    }
    property int kbdPrev: -1                    // last keyboard light level seen (-1 = not seen yet)

    // ---------- screen brightness (asked for by the key binds) ----------
    // brightnessctl -m: "device,class,raw,percent,max". -e2 = the same curve the keys use,
    // so 5% steps look even. `-c backlight` = whatever the panel's backlight is called on this machine.
    Process {
        id: brightProc
        command: ["brightnessctl", "-m", "-e2", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.trim().split(",")[3])
                if (!isNaN(pct)) root.show("󰃠", pct / 100, pct + "%", false, true)
            }
        }
    }

    // Caps / Num Lock: the keyboard LEDs are the truth (hyprctl's per-keyboard state can lag behind).
    // Any keyboard's LED lit = on.
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness | grep -qv '^0$' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: { const on = text.trim() === "1"; root.show(on ? "󰘲" : "󰬶", 1, on ? "Caps Lock on" : "Caps Lock off", !on, false) }
        }
    }
    Process {
        id: numProc
        command: ["sh", "-c", "cat /sys/class/leds/*::numlock/brightness | grep -qv '^0$' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: { const on = text.trim() === "1"; root.show(on ? "󰎠" : "󰎡", 1, on ? "Num Lock on" : "Num Lock off", !on, false) }
        }
    }

    // ---------- airplane mode (rfkill) ----------
    // `rfkill event` prints a line whenever any radio is (un)blocked -- from the notch's Wi-Fi panel,
    // the airplane key, or anything else. Airplane = every radio soft-blocked. The first lines (the
    // current state at start) are ignored.
    property bool rfArmed: false
    Timer { interval: 2000; running: true; onTriggered: root.rfArmed = true }
    Process {
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser { onRead: (line) => { if (root.rfArmed) rfDebounce.restart() } }
    }
    Timer { id: rfDebounce; interval: 150; onTriggered: rfState.running = true }   // one read per burst of lines
    Process {
        id: rfState
        command: ["sh", "-c", "rfkill -n -o SOFT | grep -qv '^blocked' && echo 0 || echo 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = text.trim() === "1"
                root.show(on ? "󰀝" : "󰀞", 1, on ? "Airplane mode on" : "Airplane mode off", !on, false)
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { brightProc.running = true }
        function caps(): void { capsProc.running = true }
        function num(): void { numProc.running = true }
        // display-mode (F9) reports the screen setup it switched to
        function display(label: string): void { root.show("󰍹", 1, label, false, false) }
        // touchpad-toggle (F10) reports "on" / "off"
        function colour(hex: string): void { root.toast("󰏘", hex + "  copied", false, hex) }
        function say(icon: string, text: string): void { root.toast(icon, text, false) }
        function touchpad(state: string): void {
            const on = state === "on"
            root.show(on ? "󰟸" : "󰤳", 1, on ? "Touchpad on" : "Touchpad off", !on, false)
        }
    }
}

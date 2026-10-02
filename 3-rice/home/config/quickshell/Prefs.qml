// Prefs.qml -- singleton: the shell's own small choices (not Hyprland's), saved in ~/.local/state/quickshell/shell.json
// (personal, not in the repo). Missing keys = the defaults below.
//   batWarn / batCrit   low-battery warning levels in % (0 = off)              Settings > Battery & sleep
//   weather             { on, name, lat, lon, units "c"|"f" }          Settings > Date & language
//   art                 style of the decoration beside the notch (SideArt.qml)   Settings > Windows > Bar art
//   corners             { screen, notch }: corner radius in px, -1 = same as the windows   Settings > Windows > Corners
//   toasts              short messages in the notch (charger, audio device, layout, VPN, ...)  Settings > Notifications
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var defaults: ({
        batWarn: 20, batCrit: 10, toasts: true,
        corners: { screen: -1, notch: -1 },
        art: "none",
        weather: { on: true, name: "", lat: 0, lon: 0, units: "c" }
    })
    property var v: JSON.parse(JSON.stringify(defaults))
    property bool loaded: false

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/state/quickshell/shell.json"
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text()), m = JSON.parse(JSON.stringify(root.defaults))
                for (const k in c) m[k] = (typeof m[k] === "object" && m[k] !== null) ? Object.assign(m[k], c[k]) : c[k]
                root.v = m
            } catch (e) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
    // set(["weather", "units"], "f")
    function set(path, value) {
        const c = JSON.parse(JSON.stringify(v))
        let o = c
        for (let i = 0; i < path.length - 1; i++) o = o[path[i]]
        o[path[path.length - 1]] = value
        v = c
        mkdir.running = true
        store.setText(JSON.stringify(c, null, 2))
    }
    Process { id: mkdir; command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"] }
}

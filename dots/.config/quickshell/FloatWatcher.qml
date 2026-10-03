// FloatWatcher.qml -- browser pop-ups (Bitwarden unlock, email / Google / Microsoft sign-in, OAuth,
// "User details" ...) float at THEIR OWN size, centred, and never flash up tiled first.
// (user 2026-09-26: "it windows then snaps to float, this is shit" + "their desired size, not a fixed mobile size")
// How: ~/.config/hypr/conf/rules.lua makes EVERY new browser window open floating + centred (a rule acts before
// the window is shown, so pop-ups are never tiled). This file then sends REAL browser windows back to tiling:
//   * the first window of a browser (your main window when the browser starts) -> tiled at once
//   * a window that settles nearly screen-sized (Ctrl+N new window) -> tiled after ~0.6 s
//   everything else (pop-ups) stays floating at its own size.
// Also, for any app: a window whose title becomes "Extension: (...)" or a sign-in title (Sign in, Log in,
// Authorize, Unlock, Verify, 2FA ...) is floated + centred the first time it gets that title.
// Each window is handled once: if you tile / float it yourself (Super+V) that sticks.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    readonly property var browsers: ["zen", "firefox", "librewolf", "chromium", "google-chrome", "brave-browser"]
    readonly property var popupTitles: /^(Extension: \(|Sign in|Sign In|Log in|Log In|Login|Authorize|Authorise|Authentication|Unlock|Two-factor|2FA|Verify)/
    property var handled: ({})

    function strip(a) { return String(a).replace(/^0x/, "") }
    function sel(addr) { return "window = \"address:0x" + strip(addr) + "\"" }
    function mark(addr) { const h = handled; h[strip(addr)] = true; handled = h }
    function floatIt(addr) {
        mark(addr)
        Hyprland.dispatch("hl.dsp.window.float({ action = \"enable\", " + sel(addr) + " })")
        Hyprland.dispatch("hl.dsp.window.center({ " + sel(addr) + " })")
    }
    function tileIt(addr) { Hyprland.dispatch("hl.dsp.window.float({ action = \"disable\", " + sel(addr) + " })") }

    // other open windows of the same browser (from Quickshell's own window list: no process, instant)
    function othersOf(cls, addr) {
        return Hyprland.toplevels.values.filter(t => t.lastIpcObject && t.lastIpcObject["class"] === cls
                                                   && strip(t.address) !== strip(addr)).length
    }

    // settle check for floating browser windows: nearly screen-sized = a real browser window -> tile
    property var checkQueue: []
    Timer {
        id: settle
        interval: 600
        onTriggered: checker.running = true
    }
    Process {
        id: checker
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(text) } catch (e) { return }
                const mon = Hyprland.focusedMonitor
                const q = root.checkQueue; root.checkQueue = []
                for (const addr of q) {
                    const me = list.find(c => root.strip(c.address) === addr)
                    if (!me || !me.floating || !mon) continue
                    const mw = mon.width / (mon.scale || 1), mh = mon.height / (mon.scale || 1)
                    if (me.size[0] > mw * 0.8 && me.size[1] > mh * 0.75) root.tileIt(addr)
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow") {                 // addr,workspace,class,title
                const p = event.data.split(",")
                if (p.length < 3 || root.browsers.indexOf(p[2]) < 0) return
                const addr = root.strip(p[0])
                if (/Picture.in.Picture/i.test(p.slice(3).join(","))) return
                Hyprland.refreshToplevels()
                if (root.othersOf(p[2], addr) === 0) {        // the browser's first window = the main one
                    root.mark(addr)
                    root.tileIt(addr)
                } else {                                       // a pop-up (or Ctrl+N: checked once it settles)
                    root.mark(addr)
                    root.checkQueue = root.checkQueue.concat([addr])
                    settle.restart()
                }
            } else if (event.name === "windowtitlev2") {       // addr,title
                const d = event.data, comma = d.indexOf(",")
                if (comma < 0) return
                const addr = root.strip(d.substring(0, comma))
                if (root.handled[addr]) return
                if (root.popupTitles.test(d.substring(comma + 1))) root.floatIt(addr)
            }
        }
    }
}

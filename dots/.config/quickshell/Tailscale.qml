// Tailscale.qml -- singleton: Tailscale state + actions for the notch (icon in Status.qml, panel in
// TailscalePanel.qml). Reads `tailscale status --json` and `tailscale debug prefs` (every 15 s, every
// 3 s while the panel is open). No sudo: the user is Tailscale's operator (`tailscale set --operator`).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool installed: true
    property string backend: ""               // Running / Stopped / NeedsLogin / Starting / NoState
    readonly property bool running: backend === "Running"
    property string selfName: ""
    property var selfIPs: []
    property string tailnet: ""
    property bool magicDNS: false
    property var peers: []                    // { id, name, os, ip, online, lastSeen, exitOption, dns }
    property var prefs: ({})
    readonly property string exitNodeId: prefs.ExitNodeID || ""
    readonly property var exitNode: peers.find(p => p.id === exitNodeId) ?? null
    readonly property var exitOptions: peers.filter(p => p.exitOption)
    readonly property int onlineCount: peers.filter(p => p.online).length

    property int watchers: 0                  // panels open
    Timer {
        interval: root.watchers > 0 ? 3000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }
    function refresh() { poll.running = true }

    Process {
        id: poll
        command: ["sh", "-c", "command -v tailscale >/dev/null || { echo NOTINSTALLED; exit; }; tailscale status --json 2>/dev/null; echo '@@PREFS@@'; tailscale debug prefs 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "NOTINSTALLED") { root.installed = false; return }
                const parts = text.split("@@PREFS@@")
                try {
                    const d = JSON.parse(parts[0])
                    root.backend = d.BackendState || ""
                    root.selfName = d.Self ? d.Self.HostName : ""
                    root.selfIPs = d.Self && d.Self.TailscaleIPs ? d.Self.TailscaleIPs : []
                    root.tailnet = d.CurrentTailnet ? d.CurrentTailnet.Name : ""
                    root.magicDNS = d.CurrentTailnet ? !!d.CurrentTailnet.MagicDNSEnabled : false
                    const list = Object.values(d.Peer || {}).map(p => ({
                        id: p.ID, name: p.HostName, os: p.OS, online: !!p.Online,
                        ip: p.TailscaleIPs && p.TailscaleIPs.length ? p.TailscaleIPs[0] : "",
                        lastSeen: p.LastSeen || "", exitOption: !!p.ExitNodeOption,
                        dns: (p.DNSName || "").replace(/\.$/, "")
                    }))
                    list.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
                    root.peers = list
                } catch (e) { root.backend = root.backend || "NoState" }
                try { root.prefs = JSON.parse(parts[1] || "{}") } catch (e) {}
            }
        }
    }

    // ---------- actions (each refreshes afterwards) ----------
    Process { id: act; onExited: root.refresh() }
    function run(args) { act.command = ["tailscale"].concat(args); act.running = true }
    function setUp(on) { run([on ? "up" : "down"]) }
    function setExit(ip) { run(["set", "--exit-node=" + (ip || "")]) }
    function setPref(flag, on) { run(["set", "--" + flag + "=" + (on ? "true" : "false")]) }
    // NeedsLogin: start a login and open the sign-in page in the browser
    function login() {
        Quickshell.execDetached(["sh", "-c", "tailscale login 2>&1 | grep -om1 'https://[^ ]*' | xargs -r xdg-open"])
    }
    function copy(text) { Quickshell.execDetached(["wl-copy", text]) }

    // "18 d ago" style text for a peer's last-seen time
    function ago(iso) {
        if (!iso || iso.startsWith("0001")) return ""
        const s = (Date.now() - new Date(iso).getTime()) / 1000
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min ago"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        return Math.round(s / 86400) + " d ago"
    }
}

// UsagePanel.qml -- what the machine is doing, in the grown notch. Shown three ways: inside the System panel on
// machines without ASUS (embedded: right of the controls), on its own from the ASUS System panel's Monitor > "usage",
// and via the 󰓅 icon when the System panel has nothing to show. Everything is read only while it is visible.
//   left    CPU (load, clock, temperature, one LED column per core), memory, swap, graphics
//   middle  network: download / upload now + the last minute as LED bars
//   right   disks, the 5 busiest programs (top), "System monitor" = btop on its scratchpad (Ctrl+Shift+Esc)
// Graphics: Intel = current / top clock, AMD = busy %, NVIDIA = only off / asleep / awake from /sys (asking the
// card itself would wake it up).
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    readonly property int wantWidth: 1080
    readonly property int wantHeight: 360
    property bool embedded: false          // inside another panel: no outer margins (that panel has them)

    // ---------- sampling: every second (load, memory, network, graphics), every 3 s (disks, top programs) ----------
    property var s: ({})
    property var cores: []                 // 0..1 per core
    property var prevCpu: null
    property var prevNet: null
    property real prevAt: 0
    property var down: []                  // bytes/s, the last 60 samples
    property var up: []
    property var disks: []                 // { name, used, size }
    property var busiest: []               // { cpu, mem, name }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: fast.running = true }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: slow.running = true }

    Process {
        id: fast
        command: ["sh", "-c", `
grep '^cpu' /proc/stat
awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/{print $1, $2}' /proc/meminfo
for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in coretemp|k10temp|zenpower) echo temp $(cat $h/temp1_input); break;; esac; done
awk 'NR>2 && $1 != "lo:" {rx+=$2; tx+=$10} END{print "net", rx, tx}' /proc/net/dev
echo mhz $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{s+=$1;n++}END{if(n) printf "%d", s/n/1000}')
for c in /sys/class/drm/card[0-9] /sys/class/drm/card[0-9][0-9]; do
  [ -e "$c/device/vendor" ] || continue
  case $(cat $c/device/vendor) in
    0x8086) a=$(cat $c/gt_act_freq_mhz 2>/dev/null || cat $c/device/tile0/gt0/freq0/act_freq 2>/dev/null)
            m=$(cat $c/gt_RP0_freq_mhz 2>/dev/null || cat $c/device/tile0/gt0/freq0/rp0_freq 2>/dev/null)
            echo gpu intel $a $m;;
    0x1002) echo gpu amd $(cat $c/device/gpu_busy_percent 2>/dev/null);;
    0x10de) echo gpu nvidia $(cat $c/device/power/runtime_status 2>/dev/null);;
  esac
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = { gpus: [] }, now = Date.now()
                let cpuLines = []
                for (const l of text.split("\n")) {
                    const f = l.trim().split(/\s+/)
                    if (f[0].startsWith("cpu")) cpuLines.push(f)
                    else if (f[0].endsWith(":")) o[f[0].slice(0, -1)] = Number(f[1])
                    else if (f[0] === "temp") o.temp = Math.round(Number(f[1]) / 1000)
                    else if (f[0] === "net") o.net = [Number(f[1]), Number(f[2])]
                    else if (f[0] === "mhz") o.mhz = Number(f[1])
                    else if (f[0] === "gpu") o.gpus.push(f.slice(1))
                }
                // CPU: busy share since the last sample, total + per core
                const cur = cpuLines.map(f => { const v = f.slice(1).map(Number); return { idle: v[3] + v[4], total: v.reduce((a, b) => a + b, 0) } })
                if (root.prevCpu && root.prevCpu.length === cur.length) {
                    const busy = (i) => 1 - (cur[i].idle - root.prevCpu[i].idle) / Math.max(1, cur[i].total - root.prevCpu[i].total)
                    o.cpu = busy(0)
                    const cs = []
                    for (let i = 1; i < cur.length; i++) cs.push(Math.max(0, Math.min(1, busy(i))))
                    root.cores = cs
                }
                root.prevCpu = cur
                // network: bytes per second
                if (o.net && root.prevNet) {
                    const dt = Math.max(0.2, (now - root.prevAt) / 1000)
                    o.rx = Math.max(0, (o.net[0] - root.prevNet[0]) / dt); o.tx = Math.max(0, (o.net[1] - root.prevNet[1]) / dt)
                    root.down = root.down.concat([o.rx]).slice(-60); root.up = root.up.concat([o.tx]).slice(-60)
                }
                if (o.net) { root.prevNet = o.net; root.prevAt = now }
                root.s = o
            }
        }
    }
    Process {
        id: slow
        command: ["sh", "-c", `
df -B1 --output=source,target,size,used -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2
echo ===
top -bn2 -d0.7 -o %CPU -w 200 | awk '/^top -/{n++} n==2 && /^ *[0-9]+ /{c=$12; for (i=13; i<=NF; i++) c=c " " $i; print $9 "\\t" $10 "\\t" c; if (++k == 5) exit}'
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("===\n")
                const seen = {}, ds = []
                for (const l of (parts[0] || "").split("\n")) {
                    const f = l.trim().split(/\s+/)
                    if (f.length < 4 || seen[f[0]] || /^\/(boot|efi|swap|\.snapshots|var|tmp)(\/|$)/.test(f[1])) continue
                    seen[f[0]] = true
                    ds.push({ name: f[1] === "/" ? "System" : f[1].split("/").pop(), used: Number(f[3]), size: Number(f[2]) })
                }
                root.disks = ds.slice(0, 2)
                const n = Math.max(1, root.cores.length)
                root.busiest = (parts[1] || "").split("\n").filter(l => l.trim()).map(l => {
                    const f = l.split("\t")
                    return { cpu: Number(f[0].replace(",", ".")) / n, mem: Number(f[1].replace(",", ".")), name: f[2] }
                })
            }
        }
    }

    // ---------- formatting ----------
    function gb(kb) { return (kb / 1048576).toFixed(1) }
    function size(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : (b / 1e9).toFixed(0) + " GB" }
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? (b / 1024).toFixed(0) + " KB/s" : Math.round(b) + " B/s" }
    readonly property real memFrac: s.MemTotal ? 1 - s.MemAvailable / s.MemTotal : 0
    readonly property real swapFrac: s.SwapTotal ? 1 - s.SwapFree / s.SwapTotal : 0

    component Meter: Column {
        id: mt
        property string label: ""
        property string value: ""
        property real frac: 0
        property bool hot: false            // amber value (high temperature, ...)
        width: parent ? parent.width : 0
        spacing: 4
        Item {
            width: parent.width; height: 16
            Text { text: mt.label; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Text { anchors.right: parent.right; text: mt.value; color: mt.hot ? Theme.amber : Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
        }
        LedBar { width: parent.width; segH: 10; frac: mt.frac; safeFrac: 0.85 }
    }

    Row {
        anchors.fill: parent
        anchors.margins: root.embedded ? 0 : 16; anchors.leftMargin: root.embedded ? 0 : 22; anchors.rightMargin: root.embedded ? 0 : 22
        spacing: 14

        // ================= left: load =================
        Card {
            width: (parent.width - 2 * parent.spacing) * 0.38; height: parent.height
            spacing: 9
            PanelTitle { title: "Load"; action: root.cores.length + " cores" }
            Meter {
                label: "CPU"
                frac: root.s.cpu ?? 0
                value: Math.round((root.s.cpu ?? 0) * 100) + "% · " + ((root.s.mhz ?? 0) / 1000).toFixed(1) + " GHz" + (root.s.temp ? " · " + root.s.temp + " °C" : "")
                hot: (root.s.temp ?? 0) >= 90
            }
            Row {   // one LED column per core, lit from the bottom
                id: coreRow
                width: parent.width; height: 34
                spacing: 3
                readonly property real colW: Math.max(2, (width - (root.cores.length - 1) * spacing) / Math.max(1, root.cores.length))
                Repeater {
                    model: root.cores
                    delegate: Column {
                        required property real modelData
                        spacing: 1
                        Repeater {
                            model: 8
                            delegate: Rectangle {
                                required property int index
                                readonly property bool lit: (7 - index + 0.5) / 8 <= modelData
                                width: coreRow.colW; height: 3; radius: 0.5
                                color: lit ? (index < 2 ? Theme.amber : Theme.coral) : Theme.raised
                            }
                        }
                    }
                }
            }
            Meter { label: "Memory"; frac: root.memFrac; value: root.s.MemTotal ? root.gb(root.s.MemTotal - root.s.MemAvailable) + " / " + root.gb(root.s.MemTotal) + " GB" : "–" }
            Meter { visible: (root.s.SwapTotal ?? 0) > 0; label: "Swap"; frac: root.swapFrac; value: root.s.SwapTotal ? root.gb(root.s.SwapTotal - root.s.SwapFree) + " / " + root.gb(root.s.SwapTotal) + " GB" : "" }
            Repeater {
                model: root.s.gpus || []
                delegate: Meter {
                    required property var modelData
                    readonly property string kind: modelData[0]
                    label: kind === "intel" ? "Graphics (Intel)" : kind === "amd" ? "Graphics (AMD)" : "NVIDIA"
                    frac: kind === "intel" ? Number(modelData[1]) / Math.max(1, Number(modelData[2]))
                        : kind === "amd" ? Number(modelData[1]) / 100 : (modelData[1] === "active" ? 1 : 0)
                    value: kind === "intel" ? modelData[1] + " / " + modelData[2] + " MHz"
                         : kind === "amd" ? modelData[1] + "%" : (modelData[1] === "active" ? "awake" : modelData[1] === "suspended" ? "asleep · 0 W" : (modelData[1] || "–"))
                    hot: kind === "nvidia" && modelData[1] === "active"
                }
            }
        }

        // ================= middle: network =================
        Card {
            width: (parent.width - 2 * parent.spacing) * 0.30; height: parent.height
            spacing: 8
            PanelTitle { title: "Network"; action: "last minute" }
            Row {
                spacing: 18
                Column {
                    Text { text: "󰇚 down"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    Text { text: root.rate(root.s.rx ?? 0); color: Theme.coral; font.family: Theme.font; font.pixelSize: 16; font.bold: true }
                }
                Column {
                    Text { text: "󰕒 up"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    Text { text: root.rate(root.s.tx ?? 0); color: Theme.amber; font.family: Theme.font; font.pixelSize: 16; font.bold: true }
                }
            }
            // the last 60 s as LED bars: download grows up from the middle line, upload down
            Item {
                id: graph
                width: parent.width; height: 196
                readonly property real peak: Math.max(65536, ...root.down, ...root.up)
                readonly property real colW: width / 60
                Rectangle { y: parent.height / 2; width: parent.width; height: 1; color: Theme.raised }
                Repeater {
                    model: root.down.length
                    delegate: Rectangle {
                        required property int index
                        readonly property real v: root.down[index] / graph.peak
                        x: (60 - root.down.length + index) * graph.colW; width: Math.max(1, graph.colW - 1)
                        height: Math.max(1, v * (graph.height / 2 - 2)); y: graph.height / 2 - height
                        color: Qt.alpha(Theme.coral, 0.35 + 0.65 * Math.min(1, v * 2))
                    }
                }
                Repeater {
                    model: root.up.length
                    delegate: Rectangle {
                        required property int index
                        readonly property real v: root.up[index] / graph.peak
                        x: (60 - root.up.length + index) * graph.colW; width: Math.max(1, graph.colW - 1)
                        height: Math.max(1, v * (graph.height / 2 - 2)); y: graph.height / 2 + 1
                        color: Qt.alpha(Theme.amber, 0.35 + 0.65 * Math.min(1, v * 2))
                    }
                }
            }
            Text { text: "top of the graph = " + root.rate(graph.peak); color: Theme.dim; font.family: Theme.font; font.pixelSize: 10 }
        }

        // ================= right: disks + busiest programs =================
        Card {
            width: (parent.width - 2 * parent.spacing) * 0.32; height: parent.height
            spacing: 7
            PanelTitle { title: "Disks" }
            Repeater {
                model: root.disks
                delegate: Meter {
                    required property var modelData
                    label: modelData.name
                    frac: modelData.used / Math.max(1, modelData.size)
                    value: root.size(modelData.used) + " / " + root.size(modelData.size)
                    hot: frac > 0.9
                }
            }
            Item { width: 1; height: 2 }
            PanelTitle {
                title: "Busiest"
                action: "system monitor ›"
                onActionClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/udiksa", "scratch", "sysmon"])
            }
            Repeater {
                model: root.busiest
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    Text { width: parent.width * 0.6; elide: Text.ElideRight; text: modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                    Text { width: parent.width * 0.2; horizontalAlignment: Text.AlignRight; text: modelData.cpu.toFixed(1) + "%"; color: modelData.cpu > 50 ? Theme.amber : Theme.coral; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                    Text { width: parent.width * 0.2; horizontalAlignment: Text.AlignRight; text: modelData.mem.toFixed(1) + "%"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                }
            }
            Text { text: "CPU share of the whole machine · memory share"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10 }
        }
    }
}

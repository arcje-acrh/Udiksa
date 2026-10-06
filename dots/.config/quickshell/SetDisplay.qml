// SetDisplay.qml -- Settings > Display (split from Devices, 2026-09-28): brightness (same -e2 curve as the keys and
// the notch), laptop refresh rate + overdrive (Power.qml, shared with the notch System panel), and an external
// monitor: every screen Hyprland knows, and Extend / Mirror / External only / Laptop only (~/.local/bin/udiksa display,
// the same as F9 / Super+P).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page

    // ---- brightness: the sysfs files, re-read every second ----
    // the first backlight of this machine (intel_backlight, amdgpu_bl0, nvidia_0, ...); none on a desktop
    property string bl: ""
    Process { running: true; command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]; stdout: StdioCollector { onStreamFinished: page.bl = text.trim() } }
    property real bCur: 0
    property real bTop: 1
    FileView { id: bNow; path: page.bl ? page.bl + "actual_brightness" : ""; onLoaded: page.bCur = Number(text().trim()) || 0 }
    FileView { path: page.bl ? page.bl + "max_brightness" : ""; onLoaded: page.bTop = Number(text().trim()) || 1 }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bNow.reload() }
    readonly property int bright: Math.round(100 * Math.sqrt(page.bCur / Math.max(1, page.bTop)))   // shown % = sqrt(raw / max)

    // ---- screens (every 2 s, so plugging one in shows up) ----
    property var mons: []
    property string dmode: ""
    Timer { interval: 2000; running: page.visible; repeat: true; triggeredOnStart: true; onTriggered: monProc.running = true }
    Process {
        id: monProc
        command: ["sh", "-c", "hyprctl monitors all -j; echo @@; cat \"${XDG_RUNTIME_DIR:-/tmp}/display-mode\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("@@")
                try { page.mons = JSON.parse(p[0]) } catch (e) {}
                page.dmode = (p[1] || "").trim()
            }
        }
    }
    readonly property var external: mons.filter(m => !/^(eDP|LVDS|DSI)/.test(m.name))
    readonly property var modes: ["extend", "mirror", "external", "laptop"]
    function setMode(m) { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/udiksa", "display", m]); page.dmode = m }

    // ---- comfort lighting (eye comfort shield): `udiksa comfort`, hyprsunset behind it ----
    property var cf: ({ mode: "off", temp: 4500, from: "20:00", to: "07:00", warm: [] })
    readonly property var cfModes: ["off", "always", "schedule", "sunset"]
    function cfRefresh() { cfInfo.running = true }
    Process {
        id: cfInfo
        command: [Quickshell.env("HOME") + "/.local/lib/udiksa/comfort"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.cf = JSON.parse(text) } catch (e) {} } }
    }
    Process { id: cfSet; onExited: page.cfRefresh() }
    function cfRun(args) { cfSet.command = [Quickshell.env("HOME") + "/.local/lib/udiksa/comfort"].concat(args); cfSet.running = true }
    property int cfTemp: 4500            // the slider's own number; the system's reading never moves it while you drag
    onCfChanged: if (!cfSave.running && !cfShow.running) cfTemp = cf.temp
    Process { id: cfPrev }               // live preview while dragging: no daemon restart, no refresh
    Timer { id: cfShow; interval: 70; onTriggered: { cfPrev.command = [Quickshell.env("HOME") + "/.local/lib/udiksa/comfort", "preview", String(page.cfTemp)]; cfPrev.running = true } }
    Timer { id: cfSave; interval: 600; onTriggered: page.cfRun(["temp", String(page.cfTemp)]) }
    Timer { id: cfEnd; interval: 2500; onTriggered: if (page.cf.mode === "off") page.cfRun(["apply"]) }   // shield off: the preview fades back after a moment
    function cfHour(t) { return parseInt(String(t).split(":")[0]) || 0 }

    SetGroup { title: "Comfort lighting" }
    SetRow {
        title: "Eye comfort shield"
        desc: "Warms the colours of every screen to cut blue light. Always = all day; Schedule = between two times; Sunset = from sunset to sunrise" + (page.cf.mode === "sunset" && page.cf.warm && page.cf.warm.length ? " (today " + page.cf.warm[0] + " – " + page.cf.warm[1] + ")." : ".")
        Seg {
            options: ["Off", "Always", "Schedule", "Sunset"]
            current: page.cfModes.indexOf(page.cf.mode)
            onPicked: (i) => { page.cf = Object.assign({}, page.cf, { mode: page.cfModes[i] }); page.cfRun(["mode", page.cfModes[i]]) }
        }
    }
    SetRow {
        title: "Warmth"
        desc: "Lower = warmer (orange). 6000 K is almost neutral, 4500 K a gentle evening, 3000 K very warm."
        SetNum {
            value: page.cfTemp; from: 2500; to: 6000; step: 100; unit: " K"
            onChanged: (x) => { page.cfTemp = x; cfShow.restart(); cfSave.restart(); cfEnd.restart() }
        }
    }
    SetRow {
        visible: page.cf.mode === "schedule"
        title: "Warm from"
        desc: "The hour the shield turns on in the evening."
        SetNum { value: page.cfHour(page.cf.from); from: 0; to: 23; unit: ":00"; barWidth: 120; onChanged: (x) => page.cfRun(["schedule", ("0" + x).slice(-2) + ":00", page.cf.to]) }
    }
    SetRow {
        visible: page.cf.mode === "schedule"
        title: "Warm until"
        desc: "The hour it turns off in the morning."
        SetNum { value: page.cfHour(page.cf.to); from: 0; to: 23; unit: ":00"; barWidth: 120; onChanged: (x) => page.cfRun(["schedule", page.cf.from, ("0" + x).slice(-2) + ":00"]) }
    }

    SetGroup { title: "Laptop screen"; visible: Power.panel }       // a desktop has none: the whole group hides
    SetRow {
        visible: Power.panel && page.bl !== ""
        title: "Brightness"
        desc: "Same scale as the brightness keys and the notch."
        SetNum { value: page.bright; from: 1; to: 100; unit: " %"; onChanged: (x) => Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-e2", "-n2", "-q", "set", x + "%"]) }
    }
    SetRow {
        // any laptop panel with more than one rate: 60 Hz / its top rate / Auto (Auto needs a battery)
        visible: Power.panelSwitch
        title: "Refresh rate"
        desc: (Power.battery ? "Auto = " + Power.hzHigh + " Hz on the charger, " + Power.hzLow + " Hz on battery (saves power). " : "") + "Now " + Power.hz + " Hz."
        Seg {
            readonly property var vals: Power.battery ? ["low", "high", "auto"] : ["low", "high"]
            options: [Power.hzLow + " Hz", Power.hzHigh + " Hz", "Auto"].slice(0, vals.length)
            current: vals.indexOf(Power.screenSel); onPicked: (i) => Power.setCfg(["screen"], vals[i])
        }
    }
    SetRow {
        visible: Power.overdrive
        title: "Panel overdrive"
        desc: "Sharper motion in games and scrolling; can add slight ghosting."
        Seg { options: ["On", "Off"]; current: Power.cfg.overdrive ? 0 : 1; onPicked: (i) => { Power.setCfg(["overdrive"], i === 0 ? 1 : 0); Power.applyOverdrive() } }
    }

    // ---- external monitor brightness over the cable (DDC/CI, ddcutil): only monitors that answer get the row ----
    property var ddc: ({})                 // { "DP-1": { bus: 5, value: 60, max: 100 } }
    Process {
        running: true
        command: ["sh", "-c", `command -v ddcutil >/dev/null || exit 0
ddcutil detect --terse 2>/dev/null | awk '/I2C bus:/{split($3, a, "-"); b=a[2]} /DRM connector:/{c=$3; sub(/^card[0-9]+-/, "", c); print c, b}' |
while read -r name bus; do v=$(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null) && echo "$name $bus $v"; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {}
                for (const l of text.split("\n")) {       // "DP-1 5 VCP 10 C 60 100"
                    const f = l.trim().split(/\s+/)
                    if (f.length >= 7 && f[2] === "VCP") d[f[0]] = { bus: f[1], value: parseInt(f[5]), max: parseInt(f[6]) || 100 }
                }
                page.ddc = d
            }
        }
    }

    // ---- per-screen setup (saved in the personal layer: ~/.config/hypr/local/monitors.lua via udiksa settings) ----
    readonly property bool builtin: mons.some(m => /^(eDP|LVDS|DSI)/.test(m.name))
    function internal(m) { return /^(eDP|LVDS|DSI)/.test(m.name) }
    function key(m) { return m.description ? "desc:" + m.description : m.name }
    function label(m) { return internal(m) ? "Built-in screen" : ((m.make + " " + m.model).trim() || m.name) }
    // what the screen does now, as the saved shape (so one change keeps the rest)
    function cfgOf(m) {
        const s = saved[key(m)] || {}
        return { mode: m.width + "x" + m.height + "@" + Math.round(m.refreshRate), scale: m.scale, position: s.position || "auto",
                 transform: m.transform || 0, mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "", disabled: !!m.disabled,
                 res: s.res || (m.width + "x" + m.height), zoom: s.zoom || m.scale }
    }
    Process { id: monSet; onExited: monProc.running = true }
    // every change is applied at once and has to be confirmed within 15 s (like Windows), else it is undone --
    // so a resolution the screen cannot show fixes itself. many = { key(m): cfg } for several screens at once.
    property var pendingUndo: null                    // { key: previous cfg } of the change waiting for "Keep"
    property int secsLeft: 0
    Timer { id: countdown; interval: 1000; repeat: true; onTriggered: { page.secsLeft -= 1; if (page.secsLeft <= 0) page.revert() } }
    function applyMany(many, confirm) {
        if (confirm && page.pendingUndo === null) {
            const u = {}
            page.mons.forEach(o => { if (many[key(o)] !== undefined) u[key(o)] = cfgOf(o) })
            page.pendingUndo = u
        }
        if (confirm) { page.secsLeft = 15; countdown.restart() }
        monSet.command = [page.host.helper, "monitor", "many", JSON.stringify(many)]; monSet.running = true
    }
    function save(m, changes) { const c = {}; c[key(m)] = Object.assign(cfgOf(m), changes); applyMany(c, true) }

    // ---- "looks like" resolutions + your zoom, like Windows (saved as res / zoom next to the real mode) ----
    // A smaller size (marked "scaled") keeps the panel at its own, sharp mode and draws everything as big as that
    // size would be: scale = zoom x native width / chosen width. The whole screen is used, nothing is cut off.
    property var saved: ({})                  // ~/.config/hypr/local/monitors.json (personal layer)
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/local/monitors.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.saved = JSON.parse(text()) } catch (e) { page.saved = {} } }
    }
    function best(m) { return nativeRes(m).sort((a, b) => px(b) - px(a))[0] || (m.width + "x" + m.height) }
    function resOf(m) { const s = saved[key(m)]; return s && s.res ? s.res : m.width + "x" + m.height }
    function zoomOf(m) {
        const s = saved[key(m)]; if (s && s.zoom) return s.zoom
        const f = parseInt(best(m)) / parseInt(resOf(m)); return Math.round(m.scale / (nativeRes(m).indexOf(resOf(m)) < 0 ? f : 1) * 100) / 100
    }
    // Hyprland only accepts scales in 1/120 steps that divide the screen into whole pixels (2560x1600: 100, 106.67,
    // 125, 133.33, 160, 166.67, 200 %; 115 % is impossible there and would silently become 106.67 %)
    function validScales(m, upTo) {
        const r = best(m).split("x"), w = parseInt(r[0]), h = parseInt(r[1]), out = []
        for (let n = 120; n <= (upTo || 2) * 120; n++) {
            const lw = w * 120 / n, lh = h * 120 / n
            if (Math.abs(lw - Math.round(lw)) < 1e-6 && Math.abs(lh - Math.round(lh)) < 1e-6) out.push(Math.round(n / 120 * 1e4) / 1e4)
        }
        return out.length ? out : [1, 2]
    }
    function nearestScale(m, s) { return validScales(m, 4).reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a) }
    function pct(v) { const p = v * 100; return (Math.abs(p - Math.round(p)) < 0.05 ? Math.round(p) : p.toFixed(2)) + " %" }
    // mode + scale for "looks like r" at zoom z
    function shape(m, r, z) {
        const own = nativeRes(m).indexOf(r) >= 0
        const hz = rates(m, own ? r : best(m))[0]
        return own ? { mode: r + "@" + hz, scale: z, res: r, zoom: z }
                   : { mode: best(m) + "@" + hz, scale: nearestScale(m, z * parseInt(best(m)) / parseInt(r)), res: r, zoom: z }
    }
    // Keep after a scale / resolution change: the shell is restarted so the notch keeps its physical size (udiksa shell)
    readonly property bool scaleChanged: pendingUndo !== null && mons.some(m => pendingUndo[key(m)] !== undefined && pendingUndo[key(m)].scale !== m.scale)
    function keep() {
        const restart = page.scaleChanged
        countdown.stop(); page.pendingUndo = null
        if (restart) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + Quickshell.env("HOME") + "/.local/bin/udiksa shell --restart\")"])
    }
    function revert() { countdown.stop(); const u = page.pendingUndo; page.pendingUndo = null; if (u) applyMany(u, false) }
    function reset(m) { monSet.command = [page.host.helper, "monitor", "rm", key(m)]; monSet.running = true }
    readonly property var standard: ["3840x2160", "3440x1440", "2560x1600", "2560x1440", "2048x1280", "1920x1200", "1920x1080",
                                     "1680x1050", "1600x900", "1440x900", "1366x768", "1280x800", "1280x720"]
    function px(r) { const p = r.split("x"); return parseInt(p[0]) * parseInt(p[1]) }
    function nativeRes(m) { const r = []; (m.availableModes || []).forEach(x => { const q = x.split("@")[0]; if (r.indexOf(q) < 0) r.push(q) }); return r }
    // what the screen reports + the standard sizes up to its biggest one (those are scaled by the GPU: "scaled")
    function resolutions(m) {
        const own = nativeRes(m), top = own.length ? Math.max.apply(null, own.map(px)) : 0
        const all = own.concat(standard.filter(r => own.indexOf(r) < 0 && px(r) <= top))
        return all.sort((a, b) => px(b) - px(a))
    }
    function rates(m, res) {
        const r = []
        ;(m.availableModes || []).forEach(x => { const p = x.split("@"); if (p[0] === res) { const hz = Math.round(parseFloat(p[1])); if (r.indexOf(hz) < 0) r.push(hz) } })
        return r.length ? r.sort((a, b) => b - a) : [60]                       // a scaled size: 60 Hz
    }
    // ---- several screens: layout (extend / mirror / only one) and where screen 2 sits ----
    readonly property var lit: mons.filter(m => !m.disabled)
    readonly property string layout: mons.length < 2 ? "" : lit.length === 1 ? "only:" + lit[0].name
        : mons.some(m => m.mirrorOf && m.mirrorOf !== "none") ? "mirror" : "extend"
    function setLayout(l) {
        const many = {}, first = mons[0]
        mons.forEach((m, i) => {
            const c = cfgOf(m)
            if (l === "extend") { c.disabled = false; c.mirror = ""; if (i > 0 && (c.position === "auto" || !c.position)) c.position = "auto-right" }
            else if (l === "mirror") { c.disabled = false; c.mirror = i === 0 ? "" : first.name }
            else { c.disabled = ("only:" + m.name) !== l; c.mirror = "" }
            many[key(m)] = c
        })
        applyMany(many, true)
    }

    SetGroup { title: page.mons.length > 1 ? "Screens (" + page.mons.length + ")" : "Screen" }
    SetRow {
        visible: page.pendingUndo !== null
        title: "Keep these display settings?"
        desc: "Going back to the previous ones in " + page.secsLeft + " s." + (page.scaleChanged ? " Keep also resizes the notch (the shell restarts, Settings closes)." : "")
        Row { spacing: 8; SetButton { text: "Revert"; onClicked: page.revert() } SetButton { text: "Keep"; accent: true; onClicked: page.keep() } }
    }
    SetRow {
        visible: page.mons.length > 1
        title: "Use the screens"
        desc: "Extend = one big desktop across them; Mirror = the same picture on all; or only one of them."
        Seg {
            readonly property var vals: ["extend", "mirror"].concat(page.mons.map(m => "only:" + m.name))
            options: ["Extend", "Mirror"].concat(page.mons.map((m, i) => "Only " + (i + 1) + (page.internal(m) ? " (built-in)" : "")))
            current: vals.indexOf(page.layout)
            onPicked: (i) => page.setLayout(vals[i])
        }
    }
    SetRow {
        visible: page.mons.length > 1 && page.layout === "extend"
        title: "Screen 2 is"
        desc: "…of screen 1 (move the mouse across that edge). Each screen below can be placed too."
        Seg {
            readonly property var vals: ["auto-left", "auto-right", "auto-up", "auto-down"]
            options: ["← Left", "Right →", "↑ Above", "↓ Below"]; current: -1
            onPicked: (i) => { if (page.mons.length > 1) page.save(page.mons[1], { position: vals[i], mirror: "", disabled: false }) }
        }
    }
    Repeater {
        model: page.mons
        delegate: Column {
            id: card
            required property var modelData
            required property int index
            readonly property var m: modelData
            readonly property string res: m.width + "x" + m.height
            readonly property var others: page.mons.filter(o => o.name !== m.name && !o.disabled)
            width: parent.width

            SetRow {
                title: page.label(card.m) + "  ·  " + card.m.name
                desc: card.m.disabled ? "Off" : card.m.width + " × " + card.m.height + " at " + Math.round(card.m.refreshRate) + " Hz, scale " + card.m.scale
                      + (card.m.mirrorOf && card.m.mirrorOf !== "none" ? ", mirrors " + card.m.mirrorOf : "")
                Row {
                    spacing: 8
                    SetButton { text: "Automatic"; onClicked: page.reset(card.m) }
                    Seg {
                        visible: page.mons.length > 1
                        options: ["On", "Off"]; current: card.m.disabled ? 1 : 0
                        onPicked: (i) => { if (i === 1 && card.others.length === 0) return; page.save(card.m, { disabled: i === 1 }) }
                    }
                }
            }
            SetRow {
                // an external monitor that accepts DDC/CI (most do; some have it off in their own menu)
                visible: !card.m.disabled && !page.internal(card.m) && page.ddc[card.m.name] !== undefined
                title: "Brightness"
                desc: "Set on the monitor itself, over the cable (DDC/CI)."
                SetNum {
                    readonly property var d: page.ddc[card.m.name] || ({ bus: "", value: 0, max: 100 })
                    value: d.value; from: 0; to: d.max; unit: ""
                    onChanged: (x) => Quickshell.execDetached(["ddcutil", "--noverify", "--bus", String(d.bus), "setvcp", "10", String(x)])
                }
            }
            SetRow {
                visible: !card.m.disabled
                title: "Resolution"
                Flow {
                    width: 620; spacing: 6; layoutDirection: Qt.RightToLeft
                    Repeater {
                        model: page.resolutions(card.m)
                        delegate: SetButton {
                            required property var modelData
                            text: modelData.replace("x", " × ") + (page.nativeRes(card.m).indexOf(modelData) < 0 ? " (scaled)" : "")
                            accent: modelData === page.resOf(card.m)
                            onClicked: page.save(card.m, page.shape(card.m, modelData, page.zoomOf(card.m)))
                        }
                    }
                }
            }
            SetRow {
                visible: !card.m.disabled && !(Power.panelSwitch && page.internal(card.m))   // built-in panel: the Refresh rate switch above
                title: "Refresh rate"
                Seg {
                    readonly property var hz: page.rates(card.m, card.res)
                    options: hz.map(x => x + " Hz"); current: hz.indexOf(Math.round(card.m.refreshRate))
                    onPicked: (i) => page.save(card.m, { mode: card.res + "@" + hz[i] })
                }
            }
            SetRow {
                visible: !card.m.disabled
                title: "Scale"
                desc: "How big everything is drawn (\"zoom\"). Only sizes this screen can show sharply are offered; a typed one goes to the nearest. The notch keeps its size."
                Row {
                    spacing: 8
                    Seg {
                        readonly property var vals: page.validScales(card.m)
                        options: vals.map(v => page.pct(v))
                        current: vals.findIndex(v => Math.abs(v - page.zoomOf(card.m)) < 0.005)
                        onPicked: (i) => page.save(card.m, page.shape(card.m, page.resOf(card.m), vals[i]))
                    }
                    SetInput {                  // any other size: snapped to the nearest one the screen allows
                        width: 80
                        placeholder: "other %"
                        onAccepted: {
                            const p = parseFloat(text)
                            if (p >= 50 && p <= 300) page.save(card.m, page.shape(card.m, page.resOf(card.m), page.nearestScale(card.m, p / 100)))
                            text = ""
                        }
                    }
                }
            }
            SetRow {
                visible: !card.m.disabled
                title: "Rotation"
                Seg {
                    readonly property var vals: [0, 1, 2, 3]
                    options: ["Normal", "90°", "180°", "270°"]; current: vals.indexOf(card.m.transform || 0)
                    onPicked: (i) => page.save(card.m, { transform: vals[i] })
                }
            }
            SetRow {
                visible: !card.m.disabled && card.others.length > 0
                title: "Position"
                desc: "Where this screen sits next to the others (move the mouse across that edge)."
                Seg {
                    readonly property var vals: ["auto-left", "auto-right", "auto-up", "auto-down"]
                    options: ["← Left", "Right →", "↑ Above", "↓ Below"]; current: -1
                    onPicked: (i) => page.save(card.m, { position: vals[i], mirror: "" })
                }
            }
            SetRow {
                visible: !card.m.disabled && card.others.length > 0
                title: "Mirror"
                desc: "Show the same picture as another screen."
                Seg {
                    readonly property var names: [""].concat(card.others.map(o => o.name))
                    options: ["No"].concat(card.others.map(o => page.label(o)))
                    current: names.indexOf(card.m.mirrorOf && card.m.mirrorOf !== "none" ? card.m.mirrorOf : "")
                    onPicked: (i) => page.save(card.m, { mirror: names[i] })
                }
            }
            SetRow {       // the confirm bar again, right under the controls of the screen being changed
                visible: page.pendingUndo !== null && page.pendingUndo[page.key(card.m)] !== undefined
                title: "Keep these settings?"
                desc: "Going back in " + page.secsLeft + " s unless you press Keep." + (page.scaleChanged ? " Keep also resizes the notch (the shell restarts)." : "")
                Row { spacing: 8; SetButton { text: "Revert"; onClicked: page.revert() } SetButton { text: "Keep"; accent: true; onClicked: page.keep() } }
            }
            Item { width: 1; height: card.index < page.mons.length - 1 ? 18 : 0 }
        }
    }
}

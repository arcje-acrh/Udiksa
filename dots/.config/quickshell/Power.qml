// Power.qml -- singleton behind the System panel (SystemPanel.qml): G-Helper-style performance modes,
// GPU mode, screen refresh, keyboard light, fan curves, and a live monitor. No root anywhere.
// It also DETECTS THE HARDWARE (section below): the notch and Settings show only what works on this machine
// (rule: show a control only when it can work; docs/HARDWARE.md explains how to add support for more devices).
//   modes   ASUS: asusctl profile (Quiet / Balanced / Performance) + asusctl armoury (CPU watts, GPU temp
//           target) + asusctl fan-curve. Silent 30/38 W is the firmware minimum (user choice).
//           Any other machine: power-profiles-daemon (power-saver / balanced / performance), no watts or curves.
//   GPU     supergfxctl (Integrated = Eco, Hybrid = Standard, AsusMuxDgpu = Ultimate). supergfxd does
//           NOT use the firmware dgpu_disable switch here, so Eco never affects Windows. With
//           "always_reboot": true in /etc/supergfxd.conf a change is saved there and applied at the next
//           boot (its logout detection fails on systemd 261); the panel shows current + queued mode.
//   screen  any laptop panel: rice-panel-hz switches between 60 Hz and the panel's own top rate
//   auto    on battery: batteryMode (Silent) + 60 Hz; on the charger: acMode + top rate. asusd's own
//           AC/battery profiles are kept in step so the two never fight.
// Settings live in ~/.config/udiksa/performance.json (yours, not in the repo; defaults on first run). Everything is re-applied at start.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth

Singleton {
    id: root

    // ---------- what this machine has (the rice runs anywhere: everything below is detected, and the notch /
    // Settings show a control only when it can work here) ----------
    property bool asus: false                  // asusctl: modes, watts, fans, charge limit, panel overdrive, keyboard colours
    property bool gfx: false                   // supergfxctl: GPU modes (hybrid laptops)
    property var gfxModes: []                  // the GPU modes supergfxctl offers here (AsusMuxDgpu only with a MUX switch)
    property bool slash: false                 // an ASUS Slash LED bar on the lid (~/.local/bin/rice-slash)
    property bool ppd: false                   // power-profiles-daemon: performance modes on any other machine
    property bool overdrive: false             // ASUS panel overdrive (firmware attribute present)
    property bool lid: false                   // a lid switch (laptop)
    property bool touchpad: false              // Hyprland lists a touchpad
    property string kbdName: ""                // a keyboard backlight (/sys/class/leds/*::kbd_backlight), any brand
    property int kbdMax: 0
    property bool fans: false                  // fan speeds readable (hwmon)
    property string panelName: ""              // the built-in screen (eDP / LVDS / DSI)
    property var panelRates: []                // its refresh rates at its current resolution, low -> high
    property bool probed: false
    property bool startWanted: false
    // live (no probe needed)
    readonly property bool battery: UPower.displayDevice !== null && UPower.displayDevice.isPresent && fake.indexOf("nobattery") < 0
    readonly property bool wifi: { if (fake.indexOf("nowifi") >= 0) return false; const ds = Networking.devices.values; for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) return true; return false }
    readonly property bool bt: Bluetooth.defaultAdapter !== null && fake.indexOf("nobt") < 0
    // derived
    readonly property bool hasModes: asus || ppd
    readonly property bool kbd: kbdName !== "" && kbdMax > 0
    readonly property bool panel: panelName !== ""
    readonly property int hzLow: panelRates.indexOf(60) >= 0 ? 60 : (panelRates.length ? panelRates[0] : 60)
    readonly property int hzHigh: panelRates.length ? panelRates[panelRates.length - 1] : 60
    readonly property bool panelSwitch: panel && hzHigh > hzLow     // the 60 Hz / top rate / Auto switch makes sense
    readonly property bool hasSystem: hasModes || gfx || panelSwitch || kbd    // the notch System panel has something to show
    // test only: UDIKSA_FAKE="noasus nogfx noppd nopanel nokbd notouchpad nolid nofans nobattery nowifi nobt" makes the shell act as if
    // that hardware were missing (used to check the "show only what works" rule; never set in normal use)
    readonly property string fake: Quickshell.env("UDIKSA_FAKE") || ""
    Process {
        running: true
        command: ["sh", "-c", `
command -v asusctl >/dev/null && echo asus
command -v supergfxctl >/dev/null && { echo gfx; echo "gfxmodes=$(supergfxctl -s 2>/dev/null | tr -d '[] ')"; }
[ -x "$HOME/.local/bin/rice-slash" ] && "$HOME/.local/bin/rice-slash" | grep -q '"capable": true' && echo slash
systemctl is-active -q power-profiles-daemon && echo ppd
[ -e /sys/class/firmware-attributes/asus-armoury/attributes/panel_overdrive ] && echo overdrive
ls /proc/acpi/button/lid/*/state >/dev/null 2>&1 && echo lid
hyprctl devices -j 2>/dev/null | jq -r '.mice[].name' | grep -qiE 'touchpad|trackpad' && echo touchpad
for l in /sys/class/leds/*::kbd_backlight; do [ -e "$l" ] && { echo "kbd=$(basename "$l") $(cat "$l/max_brightness")"; break; }; done
cat /sys/class/hwmon/hwmon*/fan*_input >/dev/null 2>&1 && echo fans
hyprctl monitors all -j 2>/dev/null | jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)")) | . as $m
  | "panel=\\(.name) " + ([.availableModes[] | select(startswith("\\($m.width)x\\($m.height)@")) | split("@")[1] | rtrimstr("Hz") | tonumber | round] | unique | map(tostring) | join(","))' | head -1
true`]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = root.fake
                const has = (k) => text.split("\n").indexOf(k) >= 0 && f.indexOf("no" + k) < 0
                const val = (k) => { const l = text.split("\n").find(x => x.startsWith(k + "=")); return l ? l.slice(k.length + 1).trim() : "" }
                root.asus = has("asus"); root.gfx = has("gfx"); root.slash = has("slash") && root.asus
                root.gfxModes = root.gfx ? val("gfxmodes").split(",").filter(x => x !== "") : []
                root.ppd = has("ppd"); root.overdrive = has("overdrive") && root.asus
                root.lid = has("lid"); root.touchpad = has("touchpad"); root.fans = has("fans")
                const k = val("kbd").split(" ")
                if (k.length === 2 && f.indexOf("nokbd") < 0) { root.kbdName = k[0]; root.kbdMax = parseInt(k[1]) || 0 }
                const p = val("panel").split(" ")
                if (p.length === 2 && f.indexOf("nopanel") < 0) { root.panelName = p[0]; root.panelRates = p[1].split(",").map(Number).filter(x => x > 0) }
                root.probed = true
                if (root.startWanted) root.start()
            }
        }
    }

    // ---------- settings (saved) ----------
    // ppd without a performance profile (some machines) offers only the first two
    readonly property var modeNames: asus || !ppd || PowerProfiles.hasPerformanceProfile ? ["silent", "balanced", "turbo"] : ["silent", "balanced"]
    readonly property var modeLabels: ({ silent: "Silent", balanced: "Balanced", turbo: "Turbo" })
    readonly property var profileOf: ({ silent: "Quiet", balanced: "Balanced", turbo: "Performance" })
    readonly property var defaults: ({
        auto: true, acMode: "balanced", batteryMode: "silent", manualMode: "balanced",
        screen: "auto", overdrive: 1,
        modes: {
            silent:   { pl1: 30, pl2: 38,  gpuTemp: 75, gpuBoost: 20, fans: { cpu: null, gpu: null } },
            balanced: { pl1: 45, pl2: 65,  gpuTemp: 87, gpuBoost: 20, fans: { cpu: null, gpu: null } },
            turbo:    { pl1: 85, pl2: 110, gpuTemp: 87, gpuBoost: 20, fans: { cpu: null, gpu: null } }
        }
    })
    property var cfg: JSON.parse(JSON.stringify(defaults))
    property bool loaded: false

    FileView {
        id: store
        // your modes, watts and fan curves (personal, not in the repo)
        path: Quickshell.env("HOME") + "/.config/udiksa/performance.json"
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text())
                const merged = JSON.parse(JSON.stringify(root.defaults))
                for (const k in c) if (k !== "modes") merged[k] = c[k]
                if (c.modes) for (const m of root.modeNames) if (c.modes[m]) Object.assign(merged.modes[m], c.modes[m])
                root.cfg = merged
            } catch (e) {}
            root.start()
        }
        onLoadFailed: root.start()          // first run: defaults
    }
    function save() {
        mkdir.running = true
        store.setText(JSON.stringify(cfg, null, 2))
    }
    Process { id: mkdir; command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell", Quickshell.env("HOME") + "/.config/udiksa"] }
    Component.onCompleted: mkdir.running = true
    function setCfg(path, value) {             // setCfg(["modes","silent","pl1"], 30)
        const c = JSON.parse(JSON.stringify(cfg))
        let o = c
        for (let i = 0; i < path.length - 1; i++) o = o[path[i]]
        o[path[path.length - 1]] = value
        cfg = c
        save()
    }

    // ---------- the mode in effect ----------
    // on battery? NOT called unplugged: QML takes a property named "on" + capital for a signal handler and its binding
    // never updated (2026-10-02: Auto stayed at 240 Hz after the charger came out, no low-battery warnings)
    readonly property bool unplugged: UPower.onBattery
    readonly property string mode: cfg.auto ? (unplugged ? cfg.batteryMode : cfg.acMode) : cfg.manualMode
    readonly property var modeCfg: cfg.modes[mode]
    // read asusd's profiles first: `asusctl profile set` WAKES the NVIDIA card (asusd re-applies its
    // tuning), so a profile is only set when it really differs
    // likewise fan-curve commands wake it -> read the current curves first, then compare
    function start() {
        startWanted = true
        if (!probed) return                    // runs again once the probe above has answered
        if (gfx) refreshGpu()
        if (fake !== "") { loaded = true; return }          // test mode: only shows, never applies to the machine
        if (!asus) { loaded = true; applyAll(); return }
        readCurves(() => { profProc.startAfter = true; profProc.running = true })
    }
    property string curProfile: ""
    property string acProfile: ""
    property string batProfile: ""
    Process {
        id: profProc
        property bool startAfter: false
        command: ["asusctl", "profile", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.match(/Active profile:\s*(\w+)/), c = text.match(/AC profile\s+(\w+)/), b = text.match(/Battery profile\s+(\w+)/)
                if (a) root.curProfile = a[1]
                if (c) root.acProfile = c[1]
                if (b) root.batProfile = b[1]
            }
        }
        onExited: if (startAfter) { startAfter = false; root.loaded = true; root.applyAll() }
    }
    onModeChanged: if (loaded) applyMode()
    onUnpluggedChanged: if (loaded) { applyScreen(); applySlash() }

    // pick a mode from the panel: with Auto on, it becomes the mode for the current power source
    function pickMode(m) {
        if (!cfg.auto) setCfg(["manualMode"], m)
        else setCfg([unplugged ? "batteryMode" : "acMode"], m)
    }

    // ---------- applying (one command after another) ----------
    property var queue: []
    function run(cmds) { if (fake !== "") return; queue = queue.concat(cmds); if (!runner.running) next() }
    function next() {
        if (queue.length === 0) return
        runner.command = queue[0]; queue = queue.slice(1); runner.running = true
    }
    Process { id: runner; onExited: root.next() }

    function applyAll() { applyMode(); applyScreen(); if (overdrive) applyOverdrive(); applySlash() }
    // the Slash lid light: dark on battery unless "Also on battery" (rice-slash decides from the power source)
    function applySlash() { if (slash) run([[Quickshell.env("HOME") + "/.local/bin/rice-slash", "apply"]]) }
    function applyMode() {
        if (!asus) {                         // any other machine: power-profiles-daemon (no watts, no fan curves)
            if (ppd && fake === "") PowerProfiles.profile = mode === "silent" ? PowerProfile.PowerSaver
                                           : mode === "turbo" && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance
                                           : PowerProfile.Balanced
            profile = mode
            return
        }
        const m = modeCfg, p = profileOf[mode]
        const cmds = []
        // only real changes (each `profile set` wakes the NVIDIA card); asusd's own charger/battery
        // profiles follow the panel
        if (curProfile !== p) cmds.push(["asusctl", "profile", "set", p])
        if (acProfile !== profileOf[cfg.acMode]) cmds.push(["asusctl", "profile", "set", "-a", profileOf[cfg.acMode]])
        if (batProfile !== profileOf[cfg.batteryMode]) cmds.push(["asusctl", "profile", "set", "-b", profileOf[cfg.batteryMode]])
        curProfile = p; acProfile = profileOf[cfg.acMode]; batProfile = profileOf[cfg.batteryMode]
        cmds.push(
            // asusd only accepts custom limits with "profile tuning" on (for this profile + power
            // source); it then also keeps them and re-applies them whenever the profile is used
            // (turning it on while already on makes asusd re-apply everything = wakes the NVIDIA card)
            ["sh", "-c", "asusctl profile tuning 2>/dev/null | grep -q 'tuning: true' || asusctl profile tuning true"],
            // firmware limits (clamped to what the firmware accepts)
            ["asusctl", "armoury", "set", "ppt_pl1_spl", String(clamp(m.pl1, 30, 85))],
            ["asusctl", "armoury", "set", "ppt_pl2_sppt", String(clamp(Math.max(m.pl2, m.pl1), 38, 110))],
            // setting the GPU temperature target briefly wakes the NVIDIA card -> only when it differs
            ["sh", "-c", "[ \"$(cat /sys/class/firmware-attributes/asus-armoury/attributes/nv_temp_target/current_value)\" = \"$1\" ] || asusctl armoury set nv_temp_target \"$1\"",
             "sh", String(clamp(m.gpuTemp, 75, 87))],
            // Dynamic Boost (watts the firmware may shift from the CPU to the NVIDIA card): same, only when it differs
            // (it can read 0 for a moment while the firmware is busy: then leave it alone)
            ["sh", "-c", "f=/sys/class/firmware-attributes/asus-armoury/attributes/nv_dynamic_boost/current_value; [ -e $f ] || exit 0; v=$(cat $f); [ \"$v\" = 0 ] || [ \"$v\" = \"$1\" ] || asusctl armoury set nv_dynamic_boost \"$1\"",
             "sh", String(clamp(m.gpuBoost ?? 20, 5, 20))]
        )
        for (const fan of ["cpu", "gpu"]) {
            const fw = curves[p] && curves[p][fan] ? curves[p][fan] : null
            const c = customCurve(mode, fan)
            const pcts = c ? c.pcts : null
            const temps = c ? c.temps : null
            if (!pcts && fw && !fw.enabled) continue          // already the firmware curve: nothing to do
            if (pcts && temps) {
                const want = temps.map((t, i) => safePct(t, pcts[i]))
                if (fw && fw.enabled && want.every((v, i) => Math.abs(v - fw.pcts[i]) <= 1)
                    && temps.every((t, i) => t === fw.temps[i])) continue                          // already applied
                cmds.push(["asusctl", "fan-curve", "--mod-profile", p, "--fan", fan, "--data",
                           temps.map((t, i) => t + "c:" + safePct(t, pcts[i]) + "%").join(",")])
                cmds.push(["asusctl", "fan-curve", "--mod-profile", p, "--fan", fan, "--enable-fan-curve", "true"])
                markCurve(p, fan, temps, want, true)
            } else {
                cmds.push(["asusctl", "fan-curve", "--mod-profile", p, "--fan", fan, "--enable-fan-curve", "false"])
                if (fw) markCurve(p, fan, fw.temps, fw.pcts, false)
            }
        }
        run(cmds)
        profile = p
    }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Math.round(v))) }

    // ---------- fan curves ----------
    // Safety floor: a custom curve can never go below this at a given temperature (the firmware's own
    // quietest curve sits above it; overheating protection in the firmware stays active regardless).
    function floorPct(t) { return t >= 95 ? 100 : t >= 90 ? 80 : t >= 85 ? 50 : t >= 80 ? 30 : t >= 75 ? 20 : 0 }
    function safePct(t, p) { return clamp(Math.max(p, floorPct(t)), 0, 100) }
    // firmware curves per profile: { Quiet: { cpu: {temps, pcts}, gpu: {...} }, ... } (read with asusctl)
    property var curves: ({})
    function readCurves(done) {
        if (readCurve.running) return
        readCurve.done = done || null
        readCurve.profiles = ["Quiet", "Balanced", "Performance"]
        readCurve.nextProfile()
    }
    Process {
        id: readCurve
        property var profiles: []
        property string current: ""
        property var done: null
        function nextProfile() {
            if (profiles.length === 0) { const d = done; done = null; if (d) d(); return }
            current = profiles[0]; profiles = profiles.slice(1)
            command = ["asusctl", "fan-curve", "--mod-profile", current]
            running = true
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                const re = /fan:\s*(\w+),\s*pwm:\s*\(([^)]*)\),\s*temp:\s*\(([^)]*)\),\s*enabled:\s*(\w+)/g
                let m
                while ((m = re.exec(text)) !== null) {
                    const pwm = m[2].split(",").map(x => parseInt(x)), temps = m[3].split(",").map(x => parseInt(x))
                    out[m[1].toLowerCase()] = { temps: temps, pcts: pwm.map(x => Math.round(x * 100 / 255)), enabled: m[4] === "true" }
                }
                const c = JSON.parse(JSON.stringify(root.curves)); c[readCurve.current] = out; root.curves = c
            }
        }
        onExited: nextProfile()
    }
    function markCurve(p, fan, temps, pcts, enabled) {
        const c = JSON.parse(JSON.stringify(curves))
        if (c[p] && c[p][fan]) { c[p][fan].temps = temps; c[p][fan].pcts = pcts; c[p][fan].enabled = enabled; curves = c }
    }
    // a mode's custom curve as { temps, pcts }, or null (firmware). Older saves stored only the speeds.
    function customCurve(m, fan) {
        const v = cfg.modes[m].fans[fan]
        if (v == null) return null
        if (Array.isArray(v)) {
            const fw = curves[profileOf[m]] ? curves[profileOf[m]][fan] : null
            return fw ? { temps: fw.temps, pcts: v } : null
        }
        return v
    }
    // save a custom curve (temps + speeds, 8 each) or null = back to the firmware curve
    // m = the mode to change (default: the one in effect; another mode's curve is used when that mode is)
    function setFanCurve(fan, temps, pcts, m) {
        m = m || mode
        if (temps && !pcts) {                    // old call form: speeds only, firmware temperatures
            pcts = temps
            const fw = curves[profileOf[m]] ? curves[profileOf[m]][fan] : null
            temps = fw ? fw.temps : null
        }
        setCfg(["modes", m, "fans", fan], temps && pcts ? { temps: temps, pcts: pcts.map((p, i) => safePct(temps[i], p)) } : null)
        if (m === mode) applyMode()
    }
    // one number of a mode (Settings > GPU edits any mode; it takes effect at once for the mode in use)
    function setModeValue(m, key, v) { setCfg(["modes", m, key], v); if (m === mode) applyMode() }

    // ---------- screen ----------
    // cfg.screen: "low" / "high" / "auto" (older saves: "60" / "240"); low = 60 Hz, high = the panel's top rate
    readonly property string screenSel: cfg.screen === "60" || cfg.screen === "low" ? "low" : cfg.screen === "auto" ? "auto" : "high"
    readonly property int hz: screenSel === "low" ? hzLow : screenSel === "high" ? hzHigh : (unplugged ? hzLow : hzHigh)
    // the laptop's own panel: ~/.local/bin/rice-panel-hz keeps its resolution / scale and changes only the rate
    function applyScreen() { if (panelSwitch) run([[Quickshell.env("HOME") + "/.local/bin/rice-panel-hz", String(hz)]]) }
    onHzChanged: if (loaded) applyScreen()
    function applyOverdrive() { if (overdrive) run([["asusctl", "armoury", "set", "panel_overdrive", String(cfg.overdrive)]]) }

    // ---------- keyboard light ----------
    // levels shown: Off / Low / Med / High, or fewer when the light has fewer steps (e.g. Off / On)
    readonly property int kbdSteps: kbd ? Math.min(kbdMax, 3) + 1 : 0
    readonly property var kbdLabels: kbdSteps === 2 ? ["Off", "On"] : kbdSteps === 3 ? ["Off", "Low", "High"] : ["Off", "Low", "Med", "High"]
    property int kbdLevel: -1              // 0..kbdSteps-1, read when the panel opens
    // ASUS: through rice-kbd so the choice is saved in ~/.config/udiksa/keyboard.json; any other: brightnessctl
    function setKbd(level) {
        kbdLevel = level
        if (asus) run([[Quickshell.env("HOME") + "/.local/bin/rice-kbd", "set", "brightness", ["off", "low", "med", "high"][level]]])
        else run([["brightnessctl", "-q", "-d", kbdName, "set", String(Math.round(level * kbdMax / (kbdSteps - 1)))]])
    }
    function readKbd() { if (kbd) kbdProc.running = true }
    Process {
        id: kbdProc
        command: ["cat", "/sys/class/leds/" + root.kbdName + "/brightness"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); if (!isNaN(v)) root.kbdLevel = Math.round(v * (root.kbdSteps - 1) / root.kbdMax) } }
    }

    // ---------- GPU mode (supergfxctl) ----------
    property string gpuMode: ""                // Integrated / Hybrid / AsusMuxDgpu
    property string gpuPending: ""             // e.g. "Logout required to complete mode change"
    property string gpuQueued: ""              // mode saved in /etc/supergfxd.conf (applies at next boot)
    readonly property bool gpuChangeQueued: gpuQueued !== "" && gpuMode !== "" && gpuQueued !== gpuMode
    property bool gpuDriver: true              // nvidia driver bound to the dGPU
    property string gpuPower: ""               // runtime state of the dGPU: active / suspended
    readonly property bool gpuError: gpuMode === "Hybrid" && !gpuDriver
    readonly property var gpuLabels: ({ Integrated: "Eco", Hybrid: "Standard", AsusMuxDgpu: "Ultimate" })
    function refreshGpu() { if (gfx) gpuProc.running = true }
    Process {
        id: gpuProc
        command: ["sh", "-c",
            "echo mode=$(supergfxctl -g 2>/dev/null); echo pending=$(supergfxctl -p 2>/dev/null); " +
            // the NVIDIA card, found by vendor id (its PCI address differs between models; reading these never wakes it)
            "d=$(for x in /sys/bus/pci/devices/*; do [ \"$(cat $x/vendor)\" = 0x10de ] && case $(cat $x/class) in 0x03*) echo $x; break;; esac; done); " +
            "[ -e \"$d/driver\" ] && echo driver=1 || echo driver=0; " +
            "echo power=$(cat \"$d/power/runtime_status\" 2>/dev/null); " +
            "echo queued=$(sed -n 's/.*\"mode\": *\"\\([A-Za-z]*\\)\".*/\\1/p' /etc/supergfxd.conf)"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const i = l.indexOf("="); if (i < 0) continue
                    const k = l.slice(0, i), v = l.slice(i + 1).trim()
                    if (k === "mode") root.gpuMode = v
                    else if (k === "pending") root.gpuPending = v === "No action required" ? "" : v
                    else if (k === "driver") root.gpuDriver = v === "1" || root.gpuMode === "Integrated"
                    else if (k === "power") root.gpuPower = v
                    else if (k === "queued") root.gpuQueued = v
                }
            }
        }
    }
    Timer { interval: 15000; running: root.gfx; repeat: true; onTriggered: root.refreshGpu() }
    function setGpuMode(m) { run([["supergfxctl", "-m", m]]); Qt.callLater(() => gpuLater.restart()) }
    Timer { id: gpuLater; interval: 1500; onTriggered: root.refreshGpu() }

    // ---------- live monitor (only while the System panel is open) ----------
    property int watchers: 0
    property var stat: ({})
    property var lastCpu: null
    Timer {
        interval: 1500; repeat: true; triggeredOnStart: true
        running: root.watchers > 0
        onTriggered: { sampler.running = true; root.refreshGpu() }
    }
    Process {
        id: sampler
        // hwmon numbers change between boots: find them by name. A hybrid laptop's NVIDIA card is NEVER queried
        // here (nvidia-smi / NVML kept it awake even when only asked while awake) -- its state comes from
        // /sys .../runtime_status in refreshGpu(). nvidia-smi runs only when NVIDIA is the ONLY graphics card
        // (a desktop: always on anyway).
        command: ["sh", "-c", `
ASUS=$1; GFX=$2
for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); case $n in
  coretemp|k10temp|zenpower) echo cpu_temp=$(cat $h/temp1_input);;
  asus) echo cpu_fan=$(cat $h/fan1_input 2>/dev/null); echo gpu_fan=$(cat $h/fan2_input 2>/dev/null);;
  amdgpu) [ -n "$GFX" ] || echo gpu_temp=$(cat $h/temp1_input 2>/dev/null);;
esac
[ -n "$ASUS" ] || for f in $h/fan*_input; do [ -e "$f" ] && echo "fan_$n$(basename $f _input | tr -dc 0-9)=$(cat $f)"; done; done
# a GPU that is always on (desktop, no hybrid switching): its load and temperature
if [ -z "$GFX" ]; then
  b=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); [ -n "$b" ] && echo gpu_load=$b
  g=$(for d in /sys/bus/pci/devices/*; do case $(cat $d/class) in 0x03*) cat $d/vendor;; esac; done)
  [ "$g" = 0x10de ] && command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', ' '{print "gpu_load=" $1 "\\ngpu_temp_c=" $2}'
fi
head -1 /proc/stat
awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print "mem_used=" (t-a) "\\nmem_total=" t}' /proc/meminfo
echo cpu_mhz=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | awk '{s+=$1;n++}END{printf "%d", s/n/1000}')
`, "sh", root.asus ? "1" : "", root.gfx ? "1" : ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = {}
                for (const l of text.split("\n")) {
                    if (l.startsWith("cpu ")) {
                        const v = l.trim().split(/\s+/).slice(1).map(Number)
                        const idle = v[3] + v[4], total = v.reduce((a, b) => a + b, 0)
                        if (root.lastCpu) s.cpu_load = Math.round(100 * (1 - (idle - root.lastCpu.idle) / Math.max(1, total - root.lastCpu.total)))
                        root.lastCpu = { idle: idle, total: total }
                        continue
                    }
                    const i = l.indexOf("="); if (i > 0) s[l.slice(0, i)] = Number(l.slice(i + 1))
                }
                if (s.cpu_temp) s.cpu_temp = Math.round(s.cpu_temp / 1000)
                if (s.gpu_temp) s.gpu_temp = Math.round(s.gpu_temp / 1000)
                if (s.gpu_temp_c !== undefined) s.gpu_temp = s.gpu_temp_c
                s.fanList = Object.keys(s).filter(k => k.startsWith("fan_")).map(k => s[k])
                const b = UPower.displayDevice
                s.watts = root.unplugged && b ? Math.abs(b.changeRate) : -1
                root.stat = s
            }
        }
    }
    property string profile: ""

    // ---------- battery "charge to 100% once" ----------
    // asusd's oneshot lifts the cap to 100 but never puts it back (tested 2026-09-26), so we do: the old limit is
    // kept in a file (survives a shell restart) and restored when the battery is full or the charger comes out.
    // NOTE: this laptop's embedded controller only honours 60 / 80 / 100 (90 and 95 are ignored = charges to full).
    property int oneshotRestore: 0
    FileView {
        id: oneshotFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/battery-oneshot"
        onLoaded: { root.oneshotRestore = parseInt(text()) || 0; root.checkOneshot() }
    }
    function chargeOnce(prevLimit) {
        if (prevLimit <= 0 || prevLimit >= 100) return
        oneshotRestore = prevLimit
        oneshotFile.setText(String(prevLimit))
        Quickshell.execDetached(["asusctl", "battery", "oneshot"])
    }
    function cancelOnce(setBack) {           // setBack = put the old limit back now (the chip's cancel)
        if (!oneshotRestore) return
        if (setBack) Quickshell.execDetached(["asusctl", "battery", "limit", String(oneshotRestore)])
        oneshotRestore = 0
        oneshotFile.setText("")
    }
    function checkOneshot() {
        if (!oneshotRestore) return
        const d = UPower.displayDevice
        if (root.unplugged || (d && d.state === UPowerDeviceState.FullyCharged)) {
            Quickshell.execDetached(["asusctl", "battery", "limit", String(oneshotRestore)])
            oneshotRestore = 0
            oneshotFile.setText("")
        }
    }
    Connections { target: UPower; function onOnBatteryChanged() { root.checkOneshot() } }
    Connections { target: UPower.displayDevice; function onStateChanged() { root.checkOneshot() } }
    Timer { interval: 60000; running: root.oneshotRestore > 0; repeat: true; onTriggered: root.checkOneshot() }

    // `qs ipc call power screen` re-applies the laptop panel's refresh rate (used by ~/.local/bin/display-mode)
    IpcHandler {
        target: "power"
        function screen(): void { root.applyScreen() }
        // hypridle after waking (rice-settings write_idle): the charger may have come or gone while asleep, and the
        // screen is not back yet when that is noticed (rice-panel-hz finds no panel), so put the rate + lid light
        // right a moment later (seen 2026-10-02: unplugged during hibernation -> woke at 240 Hz on battery)
        function resumed(): void { resumeLater.restart() }
    }
    Timer { id: resumeLater; interval: 3000; onTriggered: if (root.loaded) { root.applyScreen(); root.applySlash() } }
}

// SystemPanel.qml -- the G-Helper-style System panel in the grown notch (hover the 󰢮 icon). WIDE: the
// notch grows sideways and down (wantWidth / wantHeight). Logic + saved settings: Power.qml.
//   left    Mode (Silent / Balanced / Turbo), Auto on charger, GPU (Eco / Standard / Ultimate),
//           Screen (60 / top / Auto Hz, overdrive), Keyboard light
//   middle  power limits of the current mode: CPU sustained / boost W, GPU temperature target   (ASUS only)
//   right   live monitor (temps, fans, load, clock, RAM, GPU, power) + fan curve editor (CPU / GPU, ASUS only)
// Every section shows only when it works on this machine (flags in Power.qml): any laptop gets the screen switch,
// keyboard-light brightness and power-profiles-daemon modes; ASUS adds watts, fan curves, overdrive and colours.
import QtQuick

Item {
    id: root
    readonly property int wantWidth: Power.asus ? 1180 : 820
    readonly property int wantHeight: Power.asus ? 440 : (Power.gfx || Power.panelSwitch || Power.kbd ? 340 : 230)
    signal openPanel(string id)            // Monitor > "usage ›" switches the notch to the usage panel
    Component.onCompleted: { Power.watchers += 1; Power.refreshGpu(); Power.readCurves(); Power.readKbd() }
    Component.onDestruction: Power.watchers -= 1

    readonly property var m: Power.modeCfg
    readonly property string prof: Power.profileOf[Power.mode]
    property string fan: "cpu"
    property bool ultimateArmed: false
    Timer { id: disarm; interval: 4000; onTriggered: root.ultimateArmed = false }

    component Label: Text {
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 1
    }
    component Stat: Row {
        property string k: ""
        property string v: ""
        property color vc: Theme.text
        width: parent ? parent.width : 0
        Text { width: parent.width * 0.5; text: parent.k; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
        Text { width: parent.width * 0.5; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: parent.v; color: parent.vc; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
    }

    // a labelled watt / temperature slider; shows the saved value of the current mode, applies 0.5 s
    // after you stop dragging
    component Watt: Column {
        id: w
        property string label: ""
        property int value: 0              // the saved value (follows the mode)
        property int local: -1             // while dragging
        readonly property int shown: local >= 0 ? local : value
        property int lo: 0
        property int hi: 100
        property string unit: " W"
        property var key: []
        width: parent ? parent.width : 0
        spacing: 2
        Item {
            width: parent.width; height: 16
            Text { text: w.label; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Text { anchors.right: parent.right; text: w.shown + w.unit; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
        }
        LevelSlider {
            width: parent.width
            label: ""
            value: (w.shown - w.lo) / (w.hi - w.lo)
            valueText: w.lo + "–" + w.hi
            onMoved: (v) => { w.local = Math.round(w.lo + v * (w.hi - w.lo)); apply.restart() }
        }
        Timer {
            id: apply; interval: 500
            onTriggered: { Power.setCfg(["modes", Power.mode].concat(w.key), w.local); w.local = -1; Power.applyMode() }
        }
    }
    readonly property var st: Power.stat

    Row {
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14

        // ================= left: modes =================
        Card {
            width: Power.asus ? (parent.width - 2 * parent.spacing) * 0.36 : (parent.width - parent.spacing) * 0.5; height: parent.height
            spacing: 8
          Column {
            visible: Power.hasModes
            width: parent.width; spacing: 8
            PanelTitle { title: "Mode"; action: !Power.battery ? "" : Power.onBattery ? "on battery" : "on charger" }
            Seg {
                options: Power.modeNames.map(n => Power.modeLabels[n])
                current: Power.modeNames.indexOf(Power.mode)
                onPicked: (i) => Power.pickMode(Power.modeNames[i])
            }
            Toggle {
                visible: Power.battery
                width: parent.width; label: "Auto: " + Power.modeLabels[Power.cfg.batteryMode] + " on battery"
                checked: Power.cfg.auto
                onToggled: Power.setCfg(["auto"], !Power.cfg.auto)
            }
            Text {
                visible: Power.battery
                width: parent.width; wrapMode: Text.Wrap
                text: Power.cfg.auto ? "battery → " + Power.modeLabels[Power.cfg.batteryMode] + " · charger → " + Power.modeLabels[Power.cfg.acMode]
                                     : "manual: stays on " + Power.modeLabels[Power.cfg.manualMode]
                color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
            }
            Item { width: 1; height: 2 }
          }
          Column {
            visible: Power.gfx
            width: parent.width; spacing: 8
            PanelTitle {
                title: "GPU"
                action: Power.gpuError ? "driver missing" : (Power.gpuMode === "Integrated" ? "off" : (Power.gpuPower === "active" ? "awake" : "asleep"))
            }
            Seg {
                // only the modes supergfxctl offers here (Ultimate = a MUX switch, most ASUS gaming laptops)
                readonly property var modes: ["Integrated", "Hybrid", "AsusMuxDgpu"].filter(x => Power.gfxModes.indexOf(x) >= 0)
                options: modes.map(x => x === "AsusMuxDgpu" ? (root.ultimateArmed ? "Confirm?" : "Ultimate") : Power.gpuLabels[x])
                current: modes.indexOf(Power.gpuMode)                          // in use now (coral)
                queued: Power.gpuChangeQueued ? modes.indexOf(Power.gpuQueued) : -1   // after reboot (amber)
                onPicked: (i) => {
                    const target = modes[i]
                    if (target === (Power.gpuChangeQueued ? Power.gpuQueued : Power.gpuMode)) return
                    if (target === "AsusMuxDgpu" && !root.ultimateArmed) { root.ultimateArmed = true; disarm.restart(); return }
                    root.ultimateArmed = false
                    Power.setGpuMode(target)
                }
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                visible: text !== ""
                text: root.ultimateArmed ? "Ultimate needs a reboot and stays switched in Windows until you change it back."
                    : Power.gpuError ? "The NVIDIA driver is not loaded. A reboot usually fixes it."
                    : Power.gpuChangeQueued ? "Now " + Power.gpuLabels[Power.gpuMode] + " · " + Power.gpuLabels[Power.gpuQueued] + " after the next reboot"
                    : ""
                color: root.ultimateArmed || Power.gpuError ? Theme.warn : Theme.amber
                font.family: Theme.font; font.pixelSize: 11
            }
            Item { width: 1; height: 2 }
          }
          Column {
            visible: Power.panelSwitch
            width: parent.width; spacing: 8
            PanelTitle { title: "Screen"; action: Power.hz + " Hz now" }
            Row {
                spacing: 8
                Seg {
                    // 60 Hz / the panel's top rate / Auto (60 on battery, top on the charger; laptops only)
                    readonly property var vals: Power.battery ? ["low", "high", "auto"] : ["low", "high"]
                    options: [Power.hzLow + " Hz", Power.hzHigh + " Hz", "Auto"].slice(0, vals.length)
                    current: vals.indexOf(Power.screenSel)
                    onPicked: (i) => Power.setCfg(["screen"], vals[i])
                }
                Seg {
                    visible: Power.overdrive
                    options: ["Overdrive"]
                    current: Power.cfg.overdrive === 1 ? 0 : -1
                    onPicked: { Power.setCfg(["overdrive"], Power.cfg.overdrive === 1 ? 0 : 1); Power.applyOverdrive() }
                }
            }
            Item { width: 1; height: 2 }
          }
          Column {
            visible: Power.kbd
            width: parent.width; spacing: 8
            PanelTitle { title: "Keyboard light" }
            Seg { options: Power.kbdLabels; current: Power.kbdLevel; onPicked: (i) => Power.setKbd(i) }
          }
        }

        // ================= middle: power limits of the current mode =================
        Card {
            visible: Power.asus
            width: (parent.width - 2 * parent.spacing) * 0.27; height: parent.height
            spacing: 10
            PanelTitle { title: Power.modeLabels[Power.mode] + " · power"; action: root.prof }
            Watt { label: "CPU sustained (PL1)"; lo: 30; hi: 85; value: root.m.pl1; key: ["pl1"] }
            Watt { label: "CPU boost (PL2)"; lo: 38; hi: 110; value: root.m.pl2; key: ["pl2"] }
            Watt { label: "GPU temperature target"; lo: 75; hi: 87; unit: " °C"; value: root.m.gpuTemp; key: ["gpuTemp"] }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: "GPU power: 80 W base (fixed by the firmware on this model). Silent's 30 W / 38 W is the lowest the firmware accepts."
                color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
            }
        }

        // ================= right: monitor + fans =================
        Card {
            width: Power.asus ? (parent.width - 2 * parent.spacing) * 0.37 : (parent.width - parent.spacing) * 0.5; height: parent.height
            spacing: 5
            PanelTitle { title: "Monitor"; action: "usage ›"; onActionClicked: root.openPanel("usage") }
            Stat { k: "CPU"; v: (root.st.cpu_temp ?? "–") + " °C · " + (root.st.cpu_load ?? "–") + " % · " + ((root.st.cpu_mhz ?? 0) / 1000).toFixed(1) + " GHz" }
            Stat { visible: Power.gfx; k: "GPU"; v: Power.gpuMode === "Integrated" ? "off (Eco)" : Power.gpuError ? "driver missing" : (Power.gpuPower === "active" ? "awake (in use)" : "asleep · 0 W"); vc: Power.gpuError ? Theme.warn : (Power.gpuPower === "active" ? Theme.amber : Theme.text) }
            // a GPU that is always on (desktop / AMD): load + temperature (hybrid NVIDIA uses the row above)
            Stat { visible: !Power.gfx && root.st.gpu_load !== undefined; k: "GPU"; v: (root.st.gpu_load ?? "–") + " %" + (root.st.gpu_temp !== undefined ? " · " + root.st.gpu_temp + " °C" : "") }
            Stat { visible: Power.asus; k: "Fans"; v: "CPU " + (root.st.cpu_fan ?? "–") + " · GPU " + (root.st.gpu_fan ?? "–") + " rpm" }
            // any other machine: the fan speeds it reports (no control: every brand needs its own tool, docs/HARDWARE.md)
            Stat { visible: !Power.asus && Power.fans && (root.st.fanList || []).length > 0; k: "Fans"; v: (root.st.fanList || []).join(" · ") + " rpm" }
            Stat { k: "Memory"; v: root.st.mem_total ? ((root.st.mem_used / 1048576).toFixed(1) + " / " + (root.st.mem_total / 1048576).toFixed(0) + " GB") : "–" }
            Stat { visible: Power.battery; k: "Power draw"; v: root.st.watts >= 0 ? root.st.watts.toFixed(1) + " W (battery)" : "on charger" }
          Column {
            visible: Power.asus
            width: parent.width; spacing: 5
            Item { width: 1; height: 2 }
            PanelTitle {
                title: "Fans · " + Power.modeLabels[Power.mode]
                readonly property bool isCustom: root.m.fans[root.fan] != null
                action: isCustom ? "custom · reset" : "firmware curve"
                busy: isCustom
                onActionClicked: if (isCustom) Power.setFanCurve(root.fan, null, null)
            }
            Seg { options: ["CPU fan", "GPU fan"]; current: root.fan === "cpu" ? 0 : 1; onPicked: (i) => root.fan = i === 0 ? "cpu" : "gpu" }
            Item { width: 1; height: 14 }      // breathing room between the toggle and the graph
            FanCurve {
                id: curve
                width: parent.width
                height: 140
                readonly property var fw: Power.curves[root.prof] ? Power.curves[root.prof][root.fan] : null
                readonly property var cc: Power.customCurve(Power.mode, root.fan)
                temps: cc ? cc.temps : (fw ? fw.temps : [])
                pcts: cc ? cc.pcts : (fw ? fw.pcts : [])
                custom: cc !== null
                onEdited: (t, p) => Power.setFanCurve(root.fan, t, p)
            }
            Text {
                width: parent.width
                text: "Drag a dot: sideways = temperature, up/down = speed. Shaded = safety minimum."
                color: Theme.dim; font.family: Theme.font; font.pixelSize: 10
            }
          }
        }
    }
}

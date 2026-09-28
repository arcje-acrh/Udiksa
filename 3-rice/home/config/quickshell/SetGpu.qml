// SetGpu.qml -- Settings > GPU (user 2026-09-28: "full gpu controls like notch and more"): GPU mode (same as the
// notch System panel), what the cards are doing right now, and per performance mode: temperature target, Dynamic
// Boost and the GPU fan curve. Logic + saved values: Power.qml (shared with the notch).
// The NVIDIA card is never asked anything (nvidia-smi / NVML keep it awake): everything below comes from /sys and
// /proc -- its sleep state, time awake, the driver version, and which programs hold it open.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    Component.onCompleted: { Power.watchers += 1; Power.refreshGpu(); Power.readCurves() }
    Component.onDestruction: Power.watchers -= 1

    readonly property bool eco: Power.gpuMode === "Integrated"
    readonly property bool awake: Power.gpuPower === "active"

    // ---- live facts (every 3 s while the page is shown) ----
    property var info: ({})
    property var apps: []
    Timer { interval: 3000; running: page.visible; repeat: true; triggeredOnStart: true; onTriggered: infoProc.running = true }
    Process {
        id: infoProc
        command: ["sh", "-c", `
d=$(for x in /sys/bus/pci/devices/*; do [ "$(cat $x/vendor)" = 0x10de ] && case $(cat $x/class) in 0x03*) echo $x; break;; esac; done)
echo "drv=$(cat /sys/module/nvidia/version 2>/dev/null)"
echo "act=$(cat $d/power/runtime_active_time 2>/dev/null)"
echo "sus=$(cat $d/power/runtime_suspended_time 2>/dev/null)"
for c in /sys/class/drm/card*; do [ -e $c/gt_cur_freq_mhz ] && { echo "icur=$(cat $c/gt_cur_freq_mhz)"; echo "imax=$(cat $c/gt_RP0_freq_mhz)"; break; }; done
for h in /sys/class/hwmon/hwmon*; do [ "$(cat $h/name)" = asus ] && echo "fan=$(cat $h/fan2_input 2>/dev/null)"; done
for p in /proc/[0-9]*; do ls -l $p/fd 2>/dev/null | grep -q '/dev/nvidia[0-9]' && echo "app=$(cat $p/comm 2>/dev/null)"; done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = {}, a = []
                for (const l of text.split("\n")) {
                    const i = l.indexOf("="); if (i < 0) continue
                    const k = l.slice(0, i), v = l.slice(i + 1).trim()
                    if (k === "app") { if (v && a.indexOf(v) < 0) a.push(v) } else s[k] = v
                }
                page.info = s; page.apps = a
            }
        }
    }
    readonly property string awakeShare: {
        const a = parseInt(info.act), s = parseInt(info.sus)
        return a + s > 0 ? Math.round(100 * a / (a + s)) + " % of the time since boot" : "–"
    }

    // ---- which performance mode the limits below edit (starts at the one in use) ----
    property string editMode: Power.mode
    readonly property var em: Power.cfg.modes[editMode]
    readonly property string emProf: Power.profileOf[editMode]

    property bool ultimateArmed: false
    Timer { id: disarm; interval: 4000; onTriggered: page.ultimateArmed = false }

    component Fact: SetRow {
        id: fact
        property string value: ""
        property color tint: Theme.text
        Text { text: fact.value; color: fact.tint; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignRight }
    }

    SetGroup { title: "GPU mode" }
    SetRow {
        title: "Mode"
        desc: page.ultimateArmed ? "Ultimate needs a reboot and stays switched in Windows until you change it back. Click again to confirm."
            : Power.gpuChangeQueued ? "Now " + Power.gpuLabels[Power.gpuMode] + " · " + Power.gpuLabels[Power.gpuQueued] + " after the next reboot."
            : "Eco: NVIDIA card off, longest battery. Standard: it sleeps and wakes only for games / apps that ask. Ultimate: the screen runs straight from NVIDIA (fastest, most power)."
        Seg {
            readonly property var modes: ["Integrated", "Hybrid", "AsusMuxDgpu"]
            options: ["Eco", "Standard", page.ultimateArmed ? "Confirm?" : "Ultimate"]
            current: modes.indexOf(Power.gpuMode)
            queued: Power.gpuChangeQueued ? modes.indexOf(Power.gpuQueued) : -1
            onPicked: (i) => {
                const target = modes[i]
                if (target === (Power.gpuChangeQueued ? Power.gpuQueued : Power.gpuMode)) return
                if (i === 2 && !page.ultimateArmed) { page.ultimateArmed = true; disarm.restart(); return }
                page.ultimateArmed = false
                Power.setGpuMode(target)
            }
        }
    }

    SetGroup { title: "Right now" }
    Fact {
        title: "NVIDIA card"
        value: page.eco ? "off (Eco)" : Power.gpuError ? "driver missing, reboot" : page.awake ? "awake, in use" : "asleep · 0 W"
        tint: Power.gpuError ? Theme.warn : page.awake ? Theme.amber : Theme.text
    }
    Fact { visible: !page.eco; title: "Awake"; value: page.awakeShare }
    Fact {
        visible: !page.eco
        title: "Programs using it"
        desc: "These keep the NVIDIA card awake (and use more battery)."
        value: page.apps.length ? page.apps.join(", ") : "none"
        tint: page.apps.length ? Theme.amber : Theme.text
    }
    Fact { title: "NVIDIA driver"; value: page.info.drv ? page.info.drv : "not loaded" }
    Fact { title: "Intel graphics (built in)"; value: page.info.icur ? page.info.icur + " / " + page.info.imax + " MHz" : "–" }
    Fact { title: "GPU fan"; value: page.info.fan !== undefined && page.info.fan !== "" ? page.info.fan + " rpm" : "–" }

    SetGroup { title: "Limits per performance mode" }
    SetRow {
        title: "Edit the limits of"
        desc: Power.modeLabels[Power.mode] + " is in use now; the others take effect when you switch to them (Settings > Performance or the notch)."
        Seg { options: Power.modeNames.map(m => Power.modeLabels[m]); current: Power.modeNames.indexOf(page.editMode); onPicked: (i) => page.editMode = Power.modeNames[i] }
    }
    SetRow {
        title: "Temperature target"
        desc: "The NVIDIA card slows down to stay under this. Lower = cooler and quieter."
        SetNum { value: page.em.gpuTemp; from: 75; to: 87; unit: " °C"; onChanged: (v) => Power.setModeValue(page.editMode, "gpuTemp", v) }
    }
    SetRow {
        title: "Dynamic Boost"
        desc: "CPU and NVIDIA card share one power budget. The card's base is 80 W (fixed on this model); in games the firmware may move up to this many extra watts from the CPU to it. Lower = cooler and quieter, slightly fewer FPS. No effect in Eco."
        SetNum { value: page.em.gpuBoost ?? 20; from: 5; to: 20; unit: " W"; onChanged: (v) => Power.setModeValue(page.editMode, "gpuBoost", v) }
    }
    SetRow {
        id: fanRow
        readonly property var fw: Power.curves[page.emProf] ? Power.curves[page.emProf].gpu : null
        readonly property var cc: Power.customCurve(page.editMode, "gpu")
        title: "GPU fan curve"
        desc: (cc ? "Your curve. " : "The firmware's curve. ") + "Drag a dot: sideways = temperature, up/down = fan speed. Shaded = safety minimum."
        Column {
            spacing: 6
            FanCurve {
                width: 560; height: 200
                temps: fanRow.cc ? fanRow.cc.temps : (fanRow.fw ? fanRow.fw.temps : [])
                pcts: fanRow.cc ? fanRow.cc.pcts : (fanRow.fw ? fanRow.fw.pcts : [])
                custom: fanRow.cc !== null
                onEdited: (t, p) => Power.setFanCurve("gpu", t, p, page.editMode)
            }
            SetButton {
                anchors.right: parent.right
                visible: fanRow.cc !== null
                text: "Back to the firmware curve"
                onClicked: Power.setFanCurve("gpu", null, null, page.editMode)
            }
        }
    }

    SetGroup { title: "Run a program on the NVIDIA card"; visible: Power.gpuMode === "Hybrid" }
    SetRow {
        visible: Power.gpuMode === "Hybrid"
        title: "Command"
        desc: "In Standard mode programs use the Intel graphics unless they ask for NVIDIA; this starts one on the NVIDIA card (e.g. a game or Blender)."
        Row {
            spacing: 6
            SetInput { id: nvCmd; width: 280; placeholder: "command, e.g. blender"; onAccepted: nvRun.clicked() }
            SetButton {
                id: nvRun
                text: "Run on NVIDIA"; accent: true
                enabled: nvCmd.text.trim() !== ""
                onClicked: {
                    Quickshell.execDetached(["env", "__NV_PRIME_RENDER_OFFLOAD=1", "__GLX_VENDOR_LIBRARY_NAME=nvidia",
                                             "__VK_LAYER_NV_optimus=NVIDIA_only", "sh", "-c", nvCmd.text.trim()])
                    nvCmd.text = ""
                }
            }
        }
    }
}

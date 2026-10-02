// SetPerformance.qml -- Settings > Performance (new 2026-09-28, the full version of the notch System panel's CPU side):
// the mode in use (Silent / Balanced / Turbo) + switching with the charger, live sensors (+ btop on click), and per
// mode: CPU sustained / boost watts and the CPU fan curve. GPU mode, GPU limits and the GPU fan: Settings > GPU.
// Logic + saved values: Power.qml (shared with the notch). ASUS: asusctl (watts, fan curves). Any other machine:
// power-profiles-daemon modes, live sensors and fan speeds only (no limits / curves: they need vendor tools).
import QtQuick
import Quickshell

SetPage {
    id: page
    Component.onCompleted: { Power.watchers += 1; Power.readCurves() }
    Component.onDestruction: Power.watchers -= 1
    readonly property var st: Power.stat

    property string editMode: Power.mode
    readonly property var em: Power.cfg.modes[editMode]
    readonly property string emProf: Power.profileOf[editMode]

    component Fact: SetRow {
        id: fact
        property string value: ""
        property color tint: Theme.text
        Text { text: fact.value; color: fact.tint; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
    }

    SetGroup { title: "Mode" }
    SetRow {
        title: "Performance mode"
        desc: (Power.asus ? "Silent: quiet, cool, 30 W. Balanced: 45 W. Turbo: 85 W, loud fans. "
                          : "Silent saves power, Turbo is fastest (power-profiles-daemon). ")
              + (!Power.battery ? "" : Power.unplugged ? "On battery now." : "On the charger now.")
        Seg { options: Power.modeNames.map(m => Power.modeLabels[m]); current: Power.modeNames.indexOf(Power.mode); onPicked: (i) => Power.pickMode(Power.modeNames[i]) }
    }
    SetRow {
        visible: Power.battery
        title: "Switch with the charger"
        desc: Power.cfg.auto ? "Battery → " + Power.modeLabels[Power.cfg.batteryMode] + ", charger → " + Power.modeLabels[Power.cfg.acMode] + " (picking a mode above sets it for the current power source)."
                             : "Manual: stays on " + Power.modeLabels[Power.cfg.manualMode] + "."
        Seg { options: ["Auto", "Manual"]; current: Power.cfg.auto ? 0 : 1; onPicked: (i) => Power.setCfg(["auto"], i === 0) }
    }

    SetGroup { title: "Right now" }
    Fact { title: "Processor"; value: (page.st.cpu_temp ?? "–") + " °C  ·  " + (page.st.cpu_load ?? "–") + " % load  ·  " + ((page.st.cpu_mhz ?? 0) / 1000).toFixed(1) + " GHz" }
    Fact { visible: Power.asus; title: "Fans"; value: "CPU " + (page.st.cpu_fan ?? "–") + " rpm  ·  GPU " + (page.st.gpu_fan ?? "–") + " rpm" }
    Fact { visible: !Power.asus && (page.st.fanList || []).length > 0; title: "Fans"; value: (page.st.fanList || []).join("  ·  ") + " rpm" }
    Fact { visible: !Power.gfx && page.st.gpu_load !== undefined; title: "Graphics"; value: (page.st.gpu_load ?? "–") + " % load" + (page.st.gpu_temp !== undefined ? "  ·  " + page.st.gpu_temp + " °C" : "") }
    Fact { title: "Memory"; value: page.st.mem_total ? (page.st.mem_used / 1048576).toFixed(1) + " of " + (page.st.mem_total / 1048576).toFixed(0) + " GB in use" : "–" }
    Fact { visible: Power.battery; title: "Power draw"; value: page.st.watts >= 0 ? page.st.watts.toFixed(1) + " W from the battery" : "on the charger" }
    SetRow {
        title: "System monitor"
        desc: "btop: every core, memory, disks, network and all processes. Keys inside: q quit, f filter, k kill."
        SetButton {
            text: "Open btop"; icon: "󰍛"
            onClicked: Quickshell.execDetached(["sh", "-c", "pgrep -x btop >/dev/null || exec kitty --class rice-btop --title btop -e btop"])
        }
    }

    SetGroup { title: "Limits per mode"; visible: Power.asus }
    SetRow {
        visible: Power.asus
        title: "Edit the limits of"
        desc: Power.modeLabels[Power.mode] + " is in use now; the others take effect when you switch to them."
        Seg { options: Power.modeNames.map(m => Power.modeLabels[m]); current: Power.modeNames.indexOf(page.editMode); onPicked: (i) => page.editMode = Power.modeNames[i] }
    }
    SetRow {
        visible: Power.asus
        title: "CPU sustained power (PL1)"
        desc: "What the processor may use for long. 30 W is the lowest the firmware accepts."
        SetNum { value: page.em.pl1; from: 30; to: 85; unit: " W"; onChanged: (v) => Power.setModeValue(page.editMode, "pl1", v) }
    }
    SetRow {
        visible: Power.asus
        title: "CPU boost power (PL2)"
        desc: "Short bursts (opening apps, compiling). Never below the sustained power."
        SetNum { value: page.em.pl2; from: 38; to: 110; unit: " W"; onChanged: (v) => Power.setModeValue(page.editMode, "pl2", v) }
    }
    SetRow {
        id: fanRow
        visible: Power.asus
        readonly property var fw: Power.curves[page.emProf] ? Power.curves[page.emProf].cpu : null
        readonly property var cc: Power.customCurve(page.editMode, "cpu")
        title: "CPU fan curve"
        desc: (cc ? "Your curve. " : "The firmware's curve. ") + "Drag a dot: sideways = temperature, up/down = fan speed. Shaded = safety minimum."
        Column {
            spacing: 6
            FanCurve {
                width: 560; height: 200
                temps: fanRow.cc ? fanRow.cc.temps : (fanRow.fw ? fanRow.fw.temps : [])
                pcts: fanRow.cc ? fanRow.cc.pcts : (fanRow.fw ? fanRow.fw.pcts : [])
                custom: fanRow.cc !== null
                onEdited: (t, p) => Power.setFanCurve("cpu", t, p, page.editMode)
            }
            SetButton {
                anchors.right: parent.right
                visible: fanRow.cc !== null
                text: "Back to the firmware curve"
                onClicked: Power.setFanCurve("cpu", null, null, page.editMode)
            }
        }
    }
}

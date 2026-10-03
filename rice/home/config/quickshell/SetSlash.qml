// SetSlash.qml -- Settings > Slash lighting: the LED bar on the lid of some ASUS laptops (e.g. Zephyrus G16), via
// ~/.local/bin/rice-slash (hardware/asus). The section only shows where the bar exists (Power.slash). Animation,
// brightness etc. are kept by asusd; the on/off switch in ~/.config/udiksa/slash.json, because the bar goes dark on
// battery unless "Also on battery" is on (rice-slash apply, called by Power.qml on every plug / unplug).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    property var sl: ({})
    Process {
        id: slGet
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/rice-slash"]
        stdout: StdioCollector { onStreamFinished: { try { page.sl = JSON.parse(text) } catch (e) {} } }
    }
    property var slPending: []
    function sset(k, v) {
        const c = JSON.parse(JSON.stringify(sl)); c[k] = v; sl = c
        slPending = slPending.concat([k, String(v)]); slTimer.restart()
    }
    Timer {
        id: slTimer; interval: 350
        onTriggered: { slSet.command = [Quickshell.env("HOME") + "/.local/bin/rice-slash", "set"].concat(page.slPending); page.slPending = []; slSet.running = true }
    }
    Process { id: slSet; onExited: slGet.running = true }
    readonly property bool slOn: sl.capable === true && sl.enabled === true

    SetGroup { title: "Lid light"; visible: page.sl.capable === true }
    SetRow {
        visible: page.sl.capable === true
        title: "Slash lighting"
        desc: page.slOn && Power.unplugged && !page.sl.battery ? "The LED bar on the lid. Dark right now: the laptop is on battery (see below)." : "The LED bar on the lid."
        Seg { options: ["On", "Off"]; current: page.sl.enabled ? 0 : 1; onPicked: (i) => page.sset("enabled", i === 0) }
    }
    SetRow {
        visible: page.slOn
        title: "Also on battery"
        desc: "Off: the bar stays dark while the laptop runs on battery (saves power)."
        Seg { options: ["On", "Off"]; current: page.sl.battery ? 0 : 1; onPicked: (i) => page.sset("battery", i === 0) }
    }
    SetRow {
        visible: page.slOn
        title: "Animation"
        Flow {
            width: 640
            spacing: 6
            layoutDirection: Qt.RightToLeft
            Repeater {
                model: page.sl.modes || []
                delegate: SetButton {
                    required property var modelData
                    text: modelData.replace(/([a-z])([A-Z])/g, "$1 $2")
                    accent: page.sl.mode === modelData
                    onClicked: page.sset("mode", modelData)
                }
            }
        }
    }
    SetRow {
        visible: page.slOn
        title: "Brightness"
        SetNum { value: Math.round((page.sl.brightness ?? 255) / 2.55); from: 5; to: 100; step: 5; unit: " %"; onChanged: (x) => page.sset("brightness", Math.round(x * 2.55)) }
    }
    SetRow {
        visible: page.slOn
        title: "Pause between runs"
        desc: "0 = the animation repeats without a break."
        SetNum { value: page.sl.interval ?? 0; from: 0; to: 5; onChanged: (x) => page.sset("interval", x) }
    }
    SetRow {
        visible: page.sl.capable === true
        title: "Also light up"
        desc: "Short animations at these moments, even with the bar off."
        Row {
            spacing: 8
            Repeater {
                model: [{ k: "boot", n: "Starting" }, { k: "shutdown", n: "Shutting down" }, { k: "sleep", n: "Going to sleep" },
                        { k: "warning", n: "Low battery" }]
                delegate: Seg {
                    required property var modelData
                    options: [modelData.n]
                    current: page.sl[modelData.k] ? 0 : -1
                    onPicked: page.sset(modelData.k, !page.sl[modelData.k])
                }
            }
        }
    }

}

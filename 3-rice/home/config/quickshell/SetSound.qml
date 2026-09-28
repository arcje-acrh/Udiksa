// SetSound.qml -- Settings > Sound (split from Devices, 2026-09-28): output + microphone level and mute, which device
// plays / records, EVERY app playing sound with its own level (the notch shows 3), and the automatic switch to new
// headphones (AudioAuto.qml; on/off saved in ~/.local/state/quickshell/audio.json). Values are Pipewire's own, live.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

SetPage {
    id: page
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var all: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: all.filter(n => n.isSink && !n.isStream)
    readonly property var sources: all.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: all.filter(n => n.isStream && n.isSink)
    function nameOf(n) { return n.description || n.nickname || n.name }
    PwObjectTracker { objects: page.sinks.concat(page.sources, page.streams) }

    // headphone auto-switch setting (AudioAuto.qml watches the same file)
    property bool autoSwitch: true
    FileView {
        id: audioCfg
        path: Quickshell.env("HOME") + "/.local/state/quickshell/audio.json"
        printErrors: false
        onLoaded: { try { page.autoSwitch = JSON.parse(text()).auto !== false } catch (e) {} }
    }
    function setAuto(on) { autoSwitch = on; audioCfg.setText(JSON.stringify({ auto: on }) + "\n") }

    component Level: Row {
        id: lv
        property var node: null
        property int max: 100
        spacing: 10
        SetNum {
            value: lv.node && lv.node.audio ? Math.round(lv.node.audio.volume * 100) : 0
            from: 0; to: lv.max; step: 5; unit: " %"
            onChanged: (x) => { if (lv.node && lv.node.audio) { lv.node.audio.muted = false; lv.node.audio.volume = x / 100 } }
        }
        SetButton {
            width: 84
            text: lv.node && lv.node.audio && lv.node.audio.muted ? "Unmute" : "Mute"
            warn: lv.node && lv.node.audio ? lv.node.audio.muted : false
            onClicked: if (lv.node && lv.node.audio) lv.node.audio.muted = !lv.node.audio.muted
        }
    }

    SetGroup { title: "Output" }
    SetRow {
        title: "Volume"
        desc: (page.sink ? page.nameOf(page.sink) : "No output") + ". Above 100 % is a digital boost (can distort)."
        Level { node: page.sink; max: 125 }
    }
    SetRow {
        title: "Play sound on"
        Column {
            spacing: 6
            Repeater {
                model: page.sinks
                delegate: SetButton { required property var modelData; width: 420; text: page.nameOf(modelData); accent: page.sink === modelData; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
            }
        }
    }
    SetRow {
        title: "Switch to new headphones"
        desc: "Headphones, a headset, Bluetooth or USB audio take over the sound as soon as they connect; unplugged = back to the previous output."
        Seg { options: ["On", "Off"]; current: page.autoSwitch ? 0 : 1; onPicked: (i) => page.setAuto(i === 0) }
    }

    SetGroup { title: "Apps playing sound" }
    SetRow {
        visible: page.streams.length === 0
        title: "Nothing is playing"
        desc: "Apps appear here while they play, each with its own volume."
    }
    Repeater {
        model: page.streams
        delegate: SetRow {
            required property var modelData
            title: modelData.properties["application.name"] || page.nameOf(modelData)
            desc: modelData.properties["media.name"] || ""
            Level { node: modelData; max: 100 }
        }
    }

    SetGroup { title: "Microphone" }
    SetRow {
        title: "Level"
        desc: page.source ? page.nameOf(page.source) : "No microphone"
        Level { node: page.source; max: 100 }
    }
    SetRow {
        title: "Record from"
        Column {
            spacing: 6
            Repeater {
                model: page.sources
                delegate: SetButton { required property var modelData; width: 420; text: page.nameOf(modelData); accent: page.source === modelData; onClicked: Pipewire.preferredDefaultAudioSource = modelData }
            }
        }
    }
}

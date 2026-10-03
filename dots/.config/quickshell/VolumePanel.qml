// VolumePanel.qml -- sound settings in the grown notch.
//   left card: output + microphone level (click the label = mute) and up to 3 playing apps
//   right card: pick the output / input device (becomes the default)
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root
    // node kinds come from the node's own flags (properties are only filled in once a node is tracked)
    //   device sink = speakers/headphones, device source = microphones, stream + sink = an app playing
    //   (Quickshell flags playback streams as Audio|Sink|Stream, type 21)
    readonly property var all: Pipewire.nodes.values.filter(n => n.audio)
    function nameOf(n) { return n.description || n.nickname || n.name }
    readonly property var sinks: all.filter(n => n.isSink && !n.isStream)
    readonly property var sources: all.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: all.filter(n => n.isStream && n.isSink).slice(0, 3)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams) }

    Row {
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14

        Card {
            width: (parent.width - parent.spacing) / 2; height: parent.height
            spacing: 8
            PanelTitle { title: "Sound"; action: root.sink ? root.nameOf(root.sink) : "" }
            LevelSlider {
                width: parent.width
                label: "Output"
                max: 1.25                          // up to 125 %; above 100 % is tinted red
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                off: root.sink && root.sink.audio ? root.sink.audio.muted : false
                valueText: off ? "Muted" : Math.round(value * 100) + "%"
                onMoved: (v) => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } }
                onLabelClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
            LevelSlider {
                width: parent.width
                label: "Microphone"
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                off: root.source && root.source.audio ? root.source.audio.muted : false
                valueText: off ? "Muted" : Math.round(value * 100) + "%"
                onMoved: (v) => { if (root.source && root.source.audio) { root.source.audio.muted = false; root.source.audio.volume = v } }
                onLabelClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
            }
            Item { width: 1; height: 4 }
            Text {
                text: root.streams.length ? "APPS" : "No app is playing sound"
                color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 1
            }
            Repeater {
                model: root.streams
                delegate: LevelSlider {
                    required property var modelData
                    width: parent.width
                    label: modelData.properties["application.name"] || root.nameOf(modelData)
                    value: modelData.audio ? modelData.audio.volume : 0
                    off: modelData.audio ? modelData.audio.muted : false
                    onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v }
                    onLabelClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                }
            }
        }

        Card {
            width: (parent.width - parent.spacing) / 2; height: parent.height
            spacing: 2
            PanelTitle { title: "Output device" }
            Repeater {
                model: root.sinks
                delegate: ListRow {
                    required property var modelData
                    icon: (modelData.name || "").indexOf("bluez") >= 0 ? "󰋋" : "󰓃"   // headphones for Bluetooth
                    title: root.nameOf(modelData)
                    active: root.sink === modelData
                    note: active ? "in use" : ""
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
            Item { width: 1; height: 6 }
            PanelTitle { title: "Input device" }
            Repeater {
                model: root.sources
                delegate: ListRow {
                    required property var modelData
                    icon: (modelData.name || "").indexOf("bluez") >= 0 ? "󰋎" : "󰍬"   // headset mic for Bluetooth
                    title: root.nameOf(modelData)
                    active: root.source === modelData
                    note: active ? "in use" : ""
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }
}

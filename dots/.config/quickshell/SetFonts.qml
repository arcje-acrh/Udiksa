// SetFonts.qml -- Settings > Fonts: the interface font (shell, GTK / Qt apps, browsers' default sans, viewers, login screen)
// and the monospace font (terminal, Zed). Every choice is drawn in its own typeface; a click applies it everywhere at once,
// like a theme (back end: `udiksa font`, which writes every app's config; the shell itself follows fonts.json live).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property string exe: Quickshell.env("HOME") + "/.local/lib/udiksa/font"
    property var uiList: []
    property var monoList: []
    property string curUi: ""
    property string curMono: ""

    function refresh() { info.running = true }
    Process {
        id: info
        command: [page.exe]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    page.uiList = j.ui_installed; page.monoList = j.mono_installed
                    page.curUi = j.ui; page.curMono = j.mono
                } catch (e) {}
            }
        }
    }
    Process { id: setter; onExited: page.refresh() }
    function pick(kind, name) {
        if (kind === "ui") curUi = name; else curMono = name          // shown at once; the files are written a moment later
        setter.command = [exe, kind, name]; setter.running = true
    }
    function nice(f) { return f.replace(/ Nerd Font$/, "").replace(/^(\w+)Mono$/, "$1 Mono") }

    // one choice: its name in its own typeface + a sample
    component FontKey: Rectangle {
        id: key
        property string family: ""
        property bool on: false
        property string sample: ""
        signal picked()
        width: parent ? parent.width : 600; height: 54; radius: 2
        color: on ? Theme.bg : (km.containsMouse ? Theme.hover : Theme.raised)
        Rectangle {   // LED
            x: 14; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5
            color: key.on ? Theme.coral : Theme.dim
        }
        Text {
            x: 32; anchors.verticalCenter: parent.verticalCenter; width: 230; elide: Text.ElideRight
            text: page.nice(key.family); color: key.on ? Theme.text : Theme.muted
            font.family: key.family; font.pixelSize: 17; font.bold: key.on
        }
        Text {
            x: 280; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 300; elide: Text.ElideRight
            text: key.sample; color: key.on ? Theme.text : Theme.muted
            font.family: key.family; font.pixelSize: 15
        }
        MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: key.picked() }
    }

    SetGroup { title: "Interface font"; action: "reset both to the defaults"; onActionClicked: { setter.command = [page.exe, "reset"]; setter.running = true } }
    SetRow {
        title: "Notch, Settings, apps"
        desc: "Used by the shell, GTK and Qt apps, the browser's default sans-serif, PDF / picture viewers and the login screen. Applies at once; Qt apps pick it up when they next start."
    }
    Column {
        width: parent.width; spacing: 4
        Repeater {
            model: page.uiList
            delegate: FontKey {
                required property string modelData
                family: modelData; on: page.curUi === modelData; sample: "The quick brown fox 0123456789 󰌾 󰂯 󰕾"
                onPicked: page.pick("ui", modelData)
            }
        }
    }

    SetGroup { title: "Monospace font" }
    SetRow {
        title: "Terminal and code"
        desc: "Used by kitty, Zed and everything that asks for \"monospace\". Nerd Fonts keep the icons; the interface font is never used here, because letters must line up in columns."
    }
    Column {
        width: parent.width; spacing: 4
        Repeater {
            model: page.monoList
            delegate: FontKey {
                required property string modelData
                family: modelData; on: page.curMono === modelData; sample: "~/Udiksa $ udiksa theme set 0O 1lI {} => 󰊢 󰈙"
                onPicked: page.pick("mono", modelData)
            }
        }
    }

    SetGroup { title: "Preview" }
    Rectangle {
        width: parent.width; height: 150; radius: 2; color: Theme.surface
        Column {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 22 }
            spacing: 8
            Text { text: "Sunset over the quiet harbour"; color: Theme.text; font.family: Theme.font; font.pixelSize: 26; font.bold: true }
            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Pack my box with five dozen liquor jugs. 0123456789  ·  1:42 PM  ·  80 %"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 15 }
            Text { text: "$ udiksa font ui \"" + page.curUi + "\""; color: Theme.coral; font.family: Theme.mono; font.pixelSize: 15 }
        }
    }
}

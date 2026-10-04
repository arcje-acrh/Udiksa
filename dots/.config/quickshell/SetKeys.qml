// SetKeys.qml -- Settings > Keys: every keyboard shortcut from ~/.config/hypr/conf/binds.lua (parsed in Binds.qml,
// grouped by the comment above each block), with a search box. To change one: "edit binds.lua" (nano); Hyprland
// reloads by itself when the file is saved.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property string file: host ? host.home + "/.config/hypr/conf/binds.lua" : ""
    readonly property var binds: Binds.rice       // [{ group, keys, action }] (Binds.qml reads binds.lua)
    property string query: ""

    readonly property var shown: query === "" ? binds : binds.filter(b => (b.keys + " " + b.action + " " + b.group).toLowerCase().indexOf(query.toLowerCase()) >= 0)

    Process { id: bindProc; onExited: page.host.load() }
    function bind(op, keys, cmd) { bindProc.command = [page.host.helper, "bind", op, keys].concat(cmd ? [cmd] : []); bindProc.running = true }

    SetGroup { title: "Your shortcuts" }
    Repeater {
        model: page.host ? (page.host.hv.binds || []) : []
        delegate: SetRow {
            required property var modelData
            title: modelData.keys
            desc: "runs  " + modelData.cmd
            SetButton { text: "Remove"; warn: true; onClicked: page.bind("rm", modelData.keys) }
        }
    }
    SetRow {
        title: "Add a shortcut"
        desc: "Keys like  SUPER + B  or  SUPER + SHIFT + M, and the command to run. Works at once."
        Row {
            spacing: 6
            SetInput { id: nk; width: 200; placeholder: "SUPER + B" }
            SetInput { id: nc; width: 260; placeholder: "command, e.g. zen-browser"; onAccepted: addB.clicked() }
            SetButton { id: addB; text: "Add"; accent: true; enabled: nk.text.trim() !== "" && nc.text.trim() !== ""
                onClicked: { page.bind("add", nk.text.trim().toUpperCase().replace(/\s*\+\s*/g, " + "), nc.text.trim()); nk.text = ""; nc.text = "" } }
        }
    }
    SetGroup { title: "All shortcuts" }
    SetRow {
        title: "Search"
        desc: page.binds.length + " shortcuts from binds.lua (yours above are extra). Edit the file to change these; saving applies them."
        Row {
            spacing: 8
            SetInput { width: 260; placeholder: "key or action…"; onTextChanged: page.query = text }
            SetButton { text: "Edit binds.lua"; icon: "󰏫"; onClicked: page.host.edit(page.file) }
        }
    }
    Repeater {
        model: page.shown
        delegate: Column {
            required property var modelData
            required property int index
            width: parent.width
            SetGroup { visible: index === 0 || page.shown[index - 1].group !== modelData.group; height: visible ? 46 : 0; title: modelData.group }
            Item {
                width: parent.width; height: 36
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {   // each key of the combo as a small key cap
                        model: modelData.keys.split(" + ")
                        delegate: Rectangle {
                            required property var modelData
                            width: cap.implicitWidth + 14; height: 24; radius: 2
                            color: Theme.raised; border.width: 1; border.color: Theme.hover
                            KeyEdge {}
                            Text { id: cap; anchors.centerIn: parent; text: modelData; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                        }
                    }
                }
                Text {
                    x: 380; width: parent.width - 380
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.action; color: Theme.muted; elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: 12
                }
            }
        }
    }
}

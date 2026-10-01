// SetKeys.qml -- Settings > Keys: every keyboard shortcut, read from ~/.config/hypr/conf/binds.lua (grouped by
// the comment above each block), with a search box. To change one: "edit binds.lua" (nano); Hyprland
// reloads by itself when the file is saved.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property string file: host ? host.home + "/.config/hypr/conf/binds.lua" : ""
    property var binds: []            // [{ group, keys, action }]
    property string query: ""

    function human(a) {
        if (a.startsWith("-- ")) return a.slice(3)
        a = a.trim().replace(/,\s*\{[^}]*\}\s*$/, "")                  // drop the options table
        let m = a.match(/^hl\.dsp\.exec_cmd\((.*)\)$/)
        if (m) return "run  " + m[1].replace(/programs\.(\w+)/g, "$1").replace(/"\s*\.\.\s*|\s*\.\.\s*"/g, "").replace(/"/g, "")
        return a.replace(/^hl\.dsp\./, "").replace(/\(\)$/, "").replace(/[{}"]/g, "").replace(/\s+/g, " ")
    }
    FileView {
        path: page.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const out = []; let group = "General"
            for (const raw of text().split("\n")) {
                const line = raw.trim()
                if (/^--\s*\S/.test(line) && !/^--\s*(https?:|NOTE)/i.test(line)) { group = line.replace(/^--\s*/, "").replace(/\s*\(.*$/, "").replace(/:.*$/, ""); continue }
                let m = line.match(/^hl\.bind\((.+?),\s*(hl\..*)\)\s*$/)
                // a key that runs a Lua function: its action is the comment after `function()`
                const fm = m ? null : line.match(/^hl\.bind\((.+?),\s*function\(\)\s*--\s*(.*)$/)
                if (fm) m = [line, fm[1], "-- " + fm[2]]
                if (!m) continue
                let keys = m[1].replace(/mainMod\s*\.\.\s*"/, "SUPER").replace(/"\s*\.\.\s*key/, " + 0-9").replace(/"/g, "").replace(/\s*\.\.\s*/g, "")
                keys = keys.replace(/\s*\+\s*/g, " + ").replace("SUPER + ", "SUPER + ").trim()
                out.push({ group: group.length > 60 ? group.slice(0, 60) + "…" : group, keys: keys, action: page.human(m[2]) })
            }
            page.binds = out
        }
    }
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

// SetFiles.qml -- Settings > Config files: the hand-edited configuration files with what each one does; Edit opens
// it in nano (kitty). "Add a file" puts any file of yours on the list (kept in ~/.local/state/rice/settings-files.json),
// × takes an added one off the list again (the file itself is not touched).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property string home: host ? host.home : ""
    readonly property var builtin: [
        { name: "Window rules", path: "~/.config/hypr/conf/rules.lua", desc: "which windows float, their size and place" },
        { name: "Keyboard shortcuts", path: "~/.config/hypr/conf/binds.lua", desc: "the key bindings (also listed under Shortcuts)" },
        { name: "Startup apps", path: "~/.config/hypr/conf/autostart.lua", desc: "programs started at login" },
        { name: "Screens", path: "~/.config/hypr/conf/monitors.lua", desc: "resolution, scale, refresh rate" },
        { name: "Animations", path: "~/.config/hypr/conf/animations.lua", desc: "curves and speeds" },
        { name: "Environment", path: "~/.config/hypr/conf/env.lua", desc: "variables for apps (toolkits, cursor)" },
        { name: "Terminal (kitty)", path: "~/.config/kitty/kitty.conf", desc: "font, cursor trail, padding" },
        { name: "Prompt (starship)", path: "~/.config/starship.toml", desc: "what the shell prompt shows" },
        { name: "System info (fastfetch)", path: "~/.config/fastfetch/config.jsonc", desc: "fastfetch lines and logo" },
        { name: "Music (ncspot)", path: "~/.config/ncspot/config.toml", desc: "ncspot keys (the [theme] part is written by the themer)" },
        { name: "Bash", path: "~/.bashrc", desc: "aliases and shell startup" }
    ]
    property var added: []
    FileView {
        id: store
        path: page.home ? page.home + "/.local/state/rice/settings-files.json" : ""
        printErrors: false
        onLoaded: { try { page.added = JSON.parse(text()) } catch (e) { page.added = [] } }
        onLoadFailed: page.added = []
    }
    function persist() { store.setText(JSON.stringify(added, null, 2)) }
    function abs(p) { return p.replace(/^~/, home) }
    function add() {
        const p = newPath.text.trim(); if (!p) return
        added = added.concat([{ name: newName.text.trim() || p.replace(/^.*\//, ""), path: p, desc: "added by you" }])
        persist(); newPath.text = ""; newName.text = ""
    }
    function removeAt(i) { const a = added.slice(); a.splice(i, 1); added = a; persist() }

    SetGroup { title: "Files" }
    Repeater {
        model: page.builtin.concat(page.added)
        delegate: SetRow {
            id: fileRow
            required property var modelData
            required property int index
            readonly property bool mine: index >= page.builtin.length
            title: modelData.name
            desc: modelData.desc + "  ·  " + modelData.path
            Row {
                spacing: 8
                SetButton { visible: fileRow.mine; text: "×"; onClicked: page.removeAt(fileRow.index - page.builtin.length) }
                SetButton { text: "Edit"; icon: "󰏫"; onClicked: page.host.edit(page.abs(fileRow.modelData.path)) }
            }
        }
    }
    SetGroup { title: "Add a file" }
    SetRow {
        title: "Any file you edit often"
        desc: "Path (~ works) and an optional name; it appears in the list above."
        Row {
            spacing: 8
            SetInput { id: newPath; width: 320; placeholder: "~/.config/…"; onAccepted: page.add() }
            SetInput { id: newName; width: 180; placeholder: "name (optional)"; onAccepted: page.add() }
            SetButton { text: "Add"; accent: true; onClicked: page.add() }
        }
    }
}

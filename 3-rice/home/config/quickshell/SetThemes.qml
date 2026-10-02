// SetThemes.qml -- Settings > Themes: the theme in use, the switcher, next wallpaper, and the colour editor for
// any theme's colors.toml (swatch + hex per key, the key's explanation; Save keeps comments and re-applies the
// theme if it is the one in use). A new theme = a new folder of pictures in ~/Pictures/Wallpapers.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property string walls: host ? host.home + "/Pictures/Wallpapers" : ""
    readonly property string exe: host ? host.home + "/.local/bin/rice-theme" : ""
    property var themes: []           // [{ name, wallpapers, current }]
    property string current: ""
    property string wall: ""
    property string theme: ""         // theme whose colours are edited
    property var lines: []
    property var rows: []             // [{ line, key, value, note }]
    property bool dirty: false

    onHostChanged: if (host) refresh()
    function refresh() { lister.command = [host.home + "/.local/bin/rice-theme", "list"]; lister.running = true }   // not `exe`: its binding updates after onHostChanged
    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    page.themes = j.themes
                    page.current = j.current ? j.current.theme : ""
                    page.wall = j.current ? j.current.wallpaper : ""
                    if (!page.theme) page.theme = page.current || (j.themes[0] ? j.themes[0].name : "")
                } catch (e) {}
            }
        }
    }
    readonly property var names: themes.map(t => t.name)
    FileView {
        id: toml
        path: page.theme ? page.walls + "/" + page.theme + "/colors.toml" : ""
        onLoaded: {
            page.lines = text().split("\n")
            const r = []
            page.lines.forEach((l, i) => {
                const m = l.match(/^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"\s*(#\s*(.*))?$/)
                if (m) r.push({ line: i, key: m[1], value: m[2], note: m[4] || "" })
            })
            page.rows = r
            page.dirty = false
        }
    }
    function setValue(i, hex) { const r = page.rows.slice(); r[i] = Object.assign({}, r[i], { value: hex }); page.rows = r; page.dirty = true }
    function save() {
        const out = page.lines.slice()
        for (const r of page.rows) out[r.line] = out[r.line].replace(/"#[0-9a-fA-F]{6}"/, '"' + r.value + '"')
        toml.setText(out.join("\n"))
        page.dirty = false
        if (page.theme === page.current) Quickshell.execDetached([page.exe, "reapply"])
    }
    function step(d) { if (!names.length) return; const i = Math.max(0, names.indexOf(theme)); theme = names[(i + d + names.length) % names.length] }

    SetGroup { title: "In use" }
    SetRow {
        title: page.current || "—"
        desc: page.wall ? page.wall.replace(/^.*\//, "") + "   ·   " + page.themes.length + " themes" : ""
        Row {
            spacing: 8
            SetButton { text: "Next wallpaper"; icon: "󰸉"; onClicked: { Quickshell.execDetached([page.exe, "next"]); later.restart() } }
            SetButton { text: "Theme switcher"; icon: "󰏘"; accent: true; onClicked: { page.host.close(); Quickshell.execDetached(["qs", "ipc", "call", "themes", "open"]) } }
        }
    }
    Timer { id: later; interval: 1500; onTriggered: page.refresh() }
    SetRow {
        title: "Add a theme"
        desc: "Make a folder in ~/Pictures/Wallpapers and put pictures in it; its colours are made from the first picture (edit them below)."
        SetButton { text: "Open wallpapers folder"; onClicked: Quickshell.execDetached(["xdg-open", page.walls]) }
    }

    SetGroup { title: "Theme colours" }
    SetRow {
        title: "Edit colours of"
        desc: "Saving the theme in use re-applies it at once."
        Row {
            spacing: 8
            SetButton { text: "‹"; onClicked: page.step(-1) }
            Text { width: 240; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: page.theme + (page.theme === page.current ? "  (in use)" : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
            SetButton { text: "›"; onClicked: page.step(1) }
            SetButton { text: page.dirty ? "Save" : "Saved"; accent: page.dirty; enabled: page.dirty; onClicked: page.save() }
        }
    }
    Repeater {
        model: page.rows
        delegate: Item {
            id: rowItem
            required property var modelData
            required property int index
            width: parent.width; height: 40
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 2
                color: /^#[0-9a-fA-F]{6}$/.test(hex.text) ? hex.text : rowItem.modelData.value
                border.width: 1; border.color: Theme.hover
            }
            Text { x: 40; width: 190; anchors.verticalCenter: parent.verticalCenter; text: rowItem.modelData.key; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
            SetInput {
                id: hex
                x: 236; width: 110
                anchors.verticalCenter: parent.verticalCenter
                text: rowItem.modelData.value
                onTextChanged: if (/^#[0-9a-fA-F]{6}$/.test(text) && text.toLowerCase() !== rowItem.modelData.value.toLowerCase()) page.setValue(rowItem.index, text.toLowerCase())
            }
            Text { x: 364; width: parent.width - 364; anchors.verticalCenter: parent.verticalCenter; text: rowItem.modelData.note; color: Theme.muted; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 11 }
        }
    }
}

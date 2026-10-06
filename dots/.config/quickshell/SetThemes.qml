// SetThemes.qml -- Settings > Themes: the theme in use, the switcher, next wallpaper, and the colour editor for
// any theme's colors.toml (swatch + hex per key, the key's explanation; Save keeps comments and re-applies the
// theme if it is the one in use). A new theme = a new folder of pictures in ~/Pictures/Wallpapers.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property string walls: host ? host.home + "/Pictures/Wallpapers" : ""
    readonly property string exe: host ? host.home + "/.local/lib/udiksa/theme" : ""
    property var themes: []           // [{ name, wallpapers, current }]
    property string current: ""
    property string wall: ""
    property string theme: ""         // theme whose colours are edited
    property var lines: []
    property var rows: []             // [{ line, key, value, note }]
    property bool dirty: false

    onHostChanged: if (host) refresh()
    function refresh() { lister.command = [host.home + "/.local/bin/udiksa", "theme", "list"]; lister.running = true }   // not `exe`: its binding updates after onHostChanged
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

    // ---- the system font: ONE font for everything (`udiksa font`); installed fonts are found by themselves ----
    property var fontList: []
    property string fontCur: ""
    property string fontMono: ""
    readonly property string fontExe: Quickshell.env("HOME") + "/.local/lib/udiksa/font"
    function fontRefresh() { fontInfo.running = true }
    Process {
        id: fontInfo
        command: [page.fontExe]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const all = j.installed.map(f => ({ name: f[0], tag: f[1] ? "mono" : "" }))
                    const top = [j.font, "Iosevka Nerd Font"].filter((n, i, a) => a.indexOf(n) === i)      // the font in use and the default first
                    page.fontList = top.map(n => all.find(f => f.name === n)).filter(f => f).map(f => ({ name: f.name, tag: (f.name === j.font ? "in use" : "default") + (f.tag ? " · mono" : "") })).concat(all.filter(f => top.indexOf(f.name) < 0))
                    page.fontCur = j.font; page.fontMono = j.mono
                } catch (e) {}
            }
        }
    }
    Process { id: fontSet; onExited: page.fontRefresh() }
    function fontPick(name) { fontCur = name; fontSet.command = [fontExe, name]; fontSet.running = true }

    SetGroup { title: "Font"; action: "reset to Iosevka Nerd Font"; onActionClicked: { fontSet.command = [page.fontExe, "reset"]; fontSet.running = true } }
    SetRow {
        title: "System font"
        desc: "One font for everything: the notch, Settings, apps, browsers, viewers, the login screen. Applies at once (Qt apps when they next start). In terminals and code it is used too when it is monospace; otherwise they use its companion" + (page.fontMono && page.fontMono !== page.fontCur ? " (" + page.fontMono.replace(/ Nerd Font$/, "") + ")." : ".")
        SetDrop { options: page.fontList; current: page.fontCur; fontFace: true; onPicked: (n) => page.fontPick(n); onOpened: page.fontRefresh() }
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

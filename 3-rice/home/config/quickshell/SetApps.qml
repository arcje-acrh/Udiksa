// SetApps.qml -- Settings > Apps > Default and startup (was SetSystem.qml): startup apps (yours can
// be added / removed here, via rice-settings -> settings.lua; the hand-written ones live in autostart.lua), and
// default apps per kind of file (every installed app that opens it is offered), and the apps of the music / chat
// scratchpads (Super+M / Super+D, ~/.local/bin/rice-scratch; saved in ~/.config/hypr/local/scratch.json).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property var v: host ? host.hv : ({})

    // ---- startup: hand-written (autostart.lua) + yours (settings.lua) ----
    readonly property string autostart: host ? host.home + "/.config/hypr/conf/autostart.lua" : ""
    property var fixedStart: []
    FileView {
        path: page.autostart
        onLoaded: page.fixedStart = (text().match(/^\s*hl\.exec_cmd\("([^"]+)"\)/mg) || []).map(l => l.replace(/^\s*hl\.exec_cmd\("/, "").replace(/"\)$/, ""))
    }
    Process { id: lst; onExited: page.host.load() }
    function startup(op, cmd) { lst.command = [host.helper, "startup", op, cmd]; lst.running = true }
    property string appQuery: ""
    readonly property var appHits: appQuery.length < 2 ? [] : DesktopEntries.applications.values
        .filter(a => !a.noDisplay && a.name.toLowerCase().indexOf(appQuery.toLowerCase()) >= 0).slice(0, 8)

    // ---- default apps per kind of file ----
    readonly property var kinds: [
        { k: "browser", n: "Web browser", m: "x-scheme-handler/https", all: [] },
        { k: "files", n: "Folders", m: "inode/directory", all: ["inode/directory"] },
        { k: "text", n: "Text files", m: "text/plain", all: ["text/plain"] },
        { k: "image", n: "Pictures", m: "image/png", all: ["image/png", "image/jpeg", "image/gif", "image/webp"] },
        { k: "video", n: "Videos", m: "video/mp4", all: ["video/mp4", "video/x-matroska", "video/webm"] },
        { k: "pdf", n: "PDF", m: "application/pdf", all: ["application/pdf"] },
        { k: "audio", n: "Music files", m: "audio/mpeg", all: ["audio/mpeg", "audio/flac", "audio/ogg"] }
    ]
    property var cur: ({})            // kind -> desktop id in use
    property var cand: ({})           // kind -> [{ id, name }]
    function readDefaults() {
        defs.command = ["sh", "-c", page.kinds.map(k =>
            "echo \"CUR|" + k.k + "|$(xdg-mime query default " + k.m + ")\"; " +
            "grep -l 'MimeType=.*" + k.m.replace("/", "\\/") + "' /usr/share/applications/*.desktop \"$HOME\"/.local/share/applications/*.desktop 2>/dev/null | " +
            "while read -r f; do echo \"APP|" + k.k + "|$(basename \"$f\")|$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)\"; done").join("; ")]
        defs.running = true
    }
    Process {
        id: defs
        stdout: StdioCollector {
            onStreamFinished: {
                const c = {}, a = {}
                text.trim().split("\n").forEach(l => {
                    const p = l.split("|")
                    if (p[0] === "CUR") c[p[1]] = p[2]
                    else if (p[0] === "APP") { a[p[1]] = a[p[1]] || []; if (!a[p[1]].some(x => x.id === p[2])) a[p[1]].push({ id: p[2], name: p[3] }) }
                })
                page.cur = c; page.cand = a
            }
        }
    }
    Component.onCompleted: readDefaults()

    // ---- scratchpad apps (personal layer: ~/.config/hypr/local/scratch.json) ----
    property var scratch: ({})
    FileView {
        id: scratchFile
        path: page.host ? page.host.home + "/.config/hypr/local/scratch.json" : ""
        printErrors: false
        onLoaded: { try { page.scratch = JSON.parse(text()) } catch (e) { page.scratch = {} } }
    }
    function setScratch(name, cmd) {
        const c = JSON.parse(JSON.stringify(scratch))
        if (cmd) c[name] = cmd; else delete c[name]
        scratch = c
        scratchFile.setText(JSON.stringify(c, null, 2) + "\n")
    }
    property bool hasMusic: false
    Process {
        running: true
        command: ["sh", "-c", "command -v music >/dev/null && echo yes"]
        stdout: StdioCollector { onStreamFinished: page.hasMusic = text.trim() === "yes" }
    }
    component ScratchRow: SetRow {
        id: sr
        property string name: ""
        property string keys: ""
        property string fallback: ""         // used when nothing is picked
        property string query: ""
        readonly property var hits: query.length < 2 ? [] : DesktopEntries.applications.values
            .filter(a => !a.noDisplay && a.name.toLowerCase().indexOf(query.toLowerCase()) >= 0).slice(0, 6)
        desc: keys + "   ·   " + (page.scratch[name] ? "runs  " + page.scratch[name] : fallback ? fallback : "nothing picked yet")
        Column {
            spacing: 6
            Row {
                spacing: 6
                SetInput { id: si; width: 260; placeholder: "app name or command"; onTextChanged: sr.query = text; onAccepted: useB.clicked() }
                SetButton { id: useB; text: "Use command"; enabled: si.text.trim() !== ""; onClicked: { page.setScratch(sr.name, si.text.trim()); si.text = "" } }
                SetButton { text: "Reset"; visible: page.scratch[sr.name] !== undefined; onClicked: page.setScratch(sr.name, "") }
            }
            Repeater {
                model: sr.hits
                delegate: SetButton {
                    required property var modelData
                    width: 380; text: "Use " + modelData.name
                    onClicked: { page.setScratch(sr.name, modelData.command.join(" ")); si.text = "" }
                }
            }
        }
    }
    Process { id: setter; onExited: page.readDefaults() }
    function setDefault(kind, id) {
        setter.command = kind.k === "browser" ? ["xdg-settings", "set", "default-web-browser", id] : ["xdg-mime", "default", id].concat(kind.all)
        setter.running = true
    }

    SetGroup { title: "Startup apps"; action: "edit autostart.lua"; onActionClicked: page.host.edit(page.autostart) }
    Repeater {
        model: page.fixedStart
        delegate: SetRow { required property var modelData; title: modelData.split(" ")[0].replace(/^.*\//, ""); desc: modelData + "   ·   part of the rice (autostart.lua)" }
    }
    Repeater {
        model: page.v.startup || []
        delegate: SetRow {
            required property var modelData
            title: modelData.split(" ")[0].replace(/^.*\//, "")
            desc: modelData + "   ·   added by you"
            SetButton { text: "Remove"; warn: true; onClicked: page.startup("rm", modelData) }
        }
    }
    SetRow {
        title: "Add a startup app"
        desc: "Search your apps, or type any command; it starts at your next login."
        Column {
            spacing: 6
            Row {
                spacing: 6
                SetInput { id: sq; width: 260; placeholder: "app name or command"; onTextChanged: page.appQuery = text; onAccepted: addCmd.clicked() }
                SetButton { id: addCmd; text: "Add as command"; enabled: sq.text.trim() !== ""; onClicked: { page.startup("add", sq.text.trim()); sq.text = "" } }
            }
            Repeater {
                model: page.appHits
                delegate: SetButton {
                    required property var modelData
                    width: 380; text: "Add " + modelData.name
                    onClicked: { page.startup("add", modelData.command.join(" ")); sq.text = "" }
                }
            }
        }
    }

    SetGroup { title: "Scratchpads" }
    SetRow {
        title: "System monitor"
        desc: "Ctrl+Shift+Esc   ·   btop, floating over everything; the same keys hide it."
    }
    ScratchRow { title: "Music"; name: "music"; keys: "Super+M"; fallback: page.hasMusic ? "ncspot + cava (the music extra)" : "" }
    ScratchRow { title: "Chat"; name: "chat"; keys: "Super+D" }

    SetGroup { title: "Default apps" }
    Repeater {
        model: page.kinds
        delegate: SetRow {
            id: kindRow
            required property var modelData
            title: modelData.n
            desc: (page.cand[modelData.k] || []).length ? "" : "No installed app opens these."
            Flow {
                width: 620
                spacing: 6
                layoutDirection: Qt.RightToLeft
                Repeater {
                    model: page.cand[kindRow.modelData.k] || []
                    delegate: SetButton {
                        required property var modelData
                        text: modelData.name
                        accent: page.cur[kindRow.modelData.k] === modelData.id
                        onClicked: page.setDefault(kindRow.modelData, modelData.id)
                    }
                }
            }
        }
    }
}

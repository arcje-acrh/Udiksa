// LauncherPanel.qml -- the launcher inside the grown notch (Super + R: `qs ipc call notch toggle launcher`),
// no prefix characters: just type.
//   Main view: just type. Apps only (most used first); a line that looks like math shows its result on top;
//   the last row runs what you typed as a command.
//   ">" shows the menu instead (">rec" searches it and the tools). Entries open as their own list (Enter),
//   with a breadcrumb "Menu › …":
//     Clipboard (history; Enter copies it back, Shift+Del removes)   Emoji (grid; Enter copies)
//     Windows (Enter focuses)   Calculator (qalc; Enter copies)   Scripts (~/.local/share/rice/scripts)
//     Tools (record the screen, pick a colour, draw on a screenshot, keep awake, game mode, system monitor)
//     Keybinds (every shortcut, searchable, from Binds.qml; Enter opens Settings > Shortcuts to change one)
//   (power actions live in the notch's power panel, not here)
//   ↑↓ select, Enter opens, Backspace on an empty search or Esc goes back, Esc on the main view closes.
// App usage counts: ~/.local/state/quickshell/launcher.json. Icons are plain white: a standard icon per
// app type (terminal, files, browser, ...), otherwise the app's own logo turned white.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland

Item {
    id: root
    signal done()
    readonly property int wantHeight: 460
    readonly property bool busy: true              // no hover-close while it is open

    // ---------- menu (nested lists) ----------
    readonly property var menu: [
        { id: "clip", title: "Clipboard", sub: "Everything you copied (text and images)", glyph: "󰅍" },
        { id: "emoji", title: "Emoji", sub: "Search and copy emoji", glyph: "󰞅" },
        { id: "win", title: "Windows", sub: "Jump to an open window", glyph: "󰖯" },
        { id: "calc", title: "Calculator", sub: "Math, units, percentages", glyph: "󰃬" },
        { id: "scripts", title: "Scripts", sub: "Maintenance: mirrors, updates, cleanup, snapshots, checks", glyph: "󰯁" },
        { id: "tools", title: "Tools", sub: "Record the screen, pick a colour, draw on a screenshot, keep awake, game mode", glyph: "󰦬" },
        { id: "keys", title: "Keybinds", sub: "Every shortcut at a glance (change them in Settings > Shortcuts)", glyph: "󰌌" },
        { id: "settings", title: "Settings", sub: "Look, devices, system, monitor, keys, software, about (Super+I)", glyph: "󰒓" }
    ]
    function viewInfo(id) { return menu.find(m => m.id === id) }
    property var stack: []                         // open menu entries, e.g. ["clip"]
    readonly property string view: stack.length ? stack[stack.length - 1] : "main"
    readonly property string crumb: stack.length ? "Menu › " + viewInfo(view).title : ""
    function openView(id) { stack = stack.concat([id]); input.text = ""; sel = 0 }
    function back() { if (stack.length) { stack = stack.slice(0, -1); input.text = ""; sel = 0 } else root.done() }
    onViewChanged: { if (view === "scripts") scriptProc.running = true; if (view === "clip") clipProc.running = true; if (view === "emoji" && emojis.length === 0) emojiFile.reload() }

    property int sel: 0
    readonly property string q: input.text.trim()
    property string startView: ""                  // set by the notch (`udiksa clipboard`, `udiksa emoji`)
    Component.onCompleted: { input.forceActiveFocus(); if (startView && viewInfo(startView)) openView(startView) }

    // ---------- fuzzy score: prefix > word start > substring > letters in order ----------
    function score(hay, needle) {
        if (!needle) return 1
        hay = (hay || "").toLowerCase(); needle = needle.toLowerCase()
        if (hay.startsWith(needle)) return 100
        if (hay.indexOf(" " + needle) >= 0 || hay.indexOf("-" + needle) >= 0) return 80
        if (hay.indexOf(needle) >= 0) return 60
        let j = 0
        for (let i = 0; i < hay.length && j < needle.length; i++) if (hay[i] === needle[j]) j++
        return j === needle.length ? 20 : 0
    }

    // ---------- standard white icons by app type (desktop-entry Categories) ----------
    readonly property var typeGlyphs: [
        ["TerminalEmulator", "󰆍"], ["FileManager", "󰉋"], ["WebBrowser", "󰖟"],
        ["Settings", "󰒓"], ["HardwareSettings", "󰒓"], ["Monitor", "󰍛"],
        ["TextEditor", "󰷈"], ["Archiving", "󰀼"], ["Compression", "󰀼"],
        ["Email", "󰇮"], ["InstantMessaging", "󰭹"], ["Chat", "󰭹"],
        ["Player", "󰐊"], ["Video", "󰕧"], ["Audio", "󰝚"], ["AudioVideo", "󰕧"],
        ["Graphics", "󰋩"], ["Photography", "󰋩"], ["Office", "󰈙"], ["Game", "󰊗"],
        ["Development", "󰅩"], ["Network", "󰛳"]
    ]
    function typeGlyph(entry) {
        const c = entry && entry.categories ? entry.categories : []
        for (const [cat, g] of typeGlyphs) if (c.indexOf(cat) >= 0) return g
        return ""
    }

    // ---------- app usage counts ----------
    property var usage: ({})
    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/launcher.json"
        printErrors: false
        onLoaded: { try { root.usage = JSON.parse(text()) } catch (e) {} }
    }
    function bump(id) { const u = JSON.parse(JSON.stringify(usage)); u[id] = (u[id] || 0) + 1; usage = u; usageFile.setText(JSON.stringify(u)) }

    // ---------- calculator (qalc) ----------
    readonly property bool looksMath: /\d/.test(q) && (/[+\-*\/^%()]/.test(q) || / (to|in) /.test(q) || /\b(sqrt|sin|cos|tan|log|ln|pi)\b/.test(q))
    property string calcResult: ""
    property string calcFor: ""
    Timer { id: calcDebounce; interval: 140; onTriggered: { calcProc.command = ["qalc", "-t", root.q]; calcProc.running = true; root.calcFor = root.q } }
    Process {
        id: calcProc
        stdout: StdioCollector { onStreamFinished: root.calcResult = text.trim().split("\n").pop() }
    }
    onQChanged: { calcResult = ""; if ((view === "calc" && q) || (view === "main" && looksMath)) calcDebounce.restart() }

    // ---------- clipboard (cliphist) ----------
    property var clips: []
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.clips = text.split("\n").filter(l => l).map(l => ({ line: l, text: l.replace(/^\d+\t/, "") })) }
    }
    Process { id: clipDo; onExited: if (root.view === "clip") clipProc.running = true }

    // ---------- emoji (unicode-emoji) ----------
    property var emojis: []
    FileView {
        id: emojiFile
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        printErrors: false
        onLoaded: {
            const out = []
            for (const l of text().split("\n")) {
                const m = l.match(/; fully-qualified\s+# (\S+) E[\d.]+ (.+)$/)
                if (m) out.push({ ch: m[1], name: m[2] })
            }
            root.emojis = out
        }
    }

    // ---------- scripts: ~/.local/share/rice/scripts/*.sh (drop a file in to add one) ----------
    // header lines: "# title: …", "# desc: …", "# terminal: yes|no" (yes = run in kitty, stays open)
    property var scripts: []
    Process {
        id: scriptProc
        command: ["sh", "-c", "for f in \"$HOME\"/.local/share/rice/scripts/*.sh; do [ -f \"$f\" ] || continue; " +
                  "printf '%s\\t%s\\t%s\\t%s\\n' \"$f\" \"$(sed -n 's/^# title: //p' \"$f\")\" \"$(sed -n 's/^# desc: //p' \"$f\")\" \"$(sed -n 's/^# terminal: //p' \"$f\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.scripts = text.split("\n").filter(l => l).map(l => {
                const p = l.split("\t")
                return { path: p[0], title: p[1] || p[0].split("/").pop(), desc: p[2] || "", terminal: p[3] !== "no" }
            })
        }
    }
    function runScript(sc) {
        if (sc.terminal) Quickshell.execDetached(["kitty", "--class", "rice-script", "--title", sc.title, "-e", "bash", "-c",
            "bash \"$1\"; echo; read -rp 'Done. Press Enter to close.'", "_", sc.path])
        else Quickshell.execDetached(["bash", sc.path])
    }


    // ---------- tools: the same as their keys (binds.lua); the notch closes first, so it is not in the picture ----------
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    readonly property var tools: [
        { title: Recorder.on ? "Stop recording" : "Record the screen", sub: "Super+Alt+R · saved in Videos/Recordings", glyph: "󰑋", cmd: [bin + "udiksa", "record", "screen"] },
        { title: "Record an area", sub: "Super+Alt+Shift+R · pick the area first", glyph: "󰩭", cmd: [bin + "udiksa", "record", "region"], wait: true },
        { title: "Record with sound", sub: "Super+Alt+Ctrl+R · what you hear + the microphone", glyph: "󰕾", cmd: [bin + "udiksa", "record", "sound"] },
        { title: "Pick a colour", sub: "Super+Shift+C · copies the hex code", glyph: "󰏘", cmd: [bin + "udiksa", "pick"], wait: true },
        { title: "Screenshot to draw on", sub: "Alt+Print · arrows, boxes, text, blur; Enter saves + copies", glyph: "󰏫", cmd: [bin + "udiksa", "shot", "edit"], wait: true },
        { title: Modes.awake ? "Keep awake: on" : "Keep awake: off", sub: "No lock, screen off or sleep until you turn it off", glyph: "󰅶", mode: "awake" },
        { title: Modes.game ? "Game mode: on" : "Game mode: off", sub: "Animations, blur, shadows, gaps off", glyph: "󰊴", mode: "game" },
        { title: "System monitor", sub: "Ctrl+Shift+Esc · btop on its scratchpad", glyph: "󰓅", cmd: [bin + "udiksa", "scratch", "sysmon"] }
    ]
    function runTool(t) {
        if (t.mode === "awake") Modes.setAwake(!Modes.awake)
        else if (t.mode === "game") Modes.setGame(!Modes.game)
        else if (t.wait) Quickshell.execDetached(["sh", "-c", "sleep 0.5; exec \"$0\" \"$@\""].concat(t.cmd))
        else Quickshell.execDetached(t.cmd)
    }

    // ---------- results of the current view ----------
    readonly property var results: {
        const s = q
        if (view === "main" && s.startsWith(">")) {            // ">": the menu (and its tools), nothing else
            const m = s.slice(1).trim()
            const menuRows = menu.filter(x => !m || Math.max(score(x.title, m), score(x.sub, m) * 0.6) > 0)
                .map(x => ({ kind: "menu", title: x.title, sub: x.sub, glyph: x.glyph, target: x.id, more: true }))
            const toolRows = m ? tools.filter(t => score(t.title, m) > 0).map(t => ({ kind: "tool", title: t.title, sub: t.sub, glyph: t.glyph, tool: t })) : []
            return menuRows.concat(toolRows)
        }
        if (view === "main") {
            const use = a => usage[a.id] || 0
            const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
                .map(a => ({ a: a, sc: Math.max(score(a.name, s), score(a.genericName, s) * 0.8, score((a.keywords || []).join(" "), s) * 0.7) }))
                .filter(x => x.sc > 0)
            apps.sort((x, y) => s ? ((y.sc - x.sc) || (use(y.a) - use(x.a)) || x.a.name.localeCompare(y.a.name))
                                  : ((use(y.a) - use(x.a)) || x.a.name.localeCompare(y.a.name)))
            const appRows = apps.slice(0, 40).map(x => ({ kind: "app", title: x.a.name, sub: x.a.genericName || x.a.comment || "", icon: x.a.icon, glyph: typeGlyph(x.a), entry: x.a }))
            let r = []
            if (looksMath && calcResult && calcFor === s) r.push({ kind: "calc", title: "= " + calcResult, sub: s + "   ·   Enter copies the result", glyph: "󰃬" })
            r = r.concat(appRows)
            if (s) r.push({ kind: "run", title: "Run “" + s + "”", sub: "as a command · Ctrl+Enter: in a terminal", glyph: "󰆍", cmd: s })
            return r
        }
        if (view === "calc") return s ? [
            { kind: "calc", title: calcResult ? "= " + calcResult : "…", sub: s + "   ·   Enter copies the result", glyph: "󰃬" }
        ] : [{ kind: "none", title: "Type math or a conversion", sub: "12*7 · 5 km to mi · 100 °F to °C · sqrt(2)", glyph: "󰃬" }]
        if (view === "clip") return clips.filter(c => score(c.text, s) > 0).slice(0, 60)
            .map(c => ({ kind: "clip", title: c.text.startsWith("[[ binary") ? "Image" : c.text, sub: c.text.startsWith("[[ binary") ? c.text.replace(/[\[\]]/g, "").trim() : "", glyph: c.text.startsWith("[[ binary") ? "󰋩" : "󰅍", line: c.line }))
        if (view === "win") return Hyprland.toplevels.values
            .map(t => ({ t: t, sc: Math.max(score(t.title, s), score(t.lastIpcObject ? t.lastIpcObject.class : "", s)) }))
            .filter(x => x.sc > 0).sort((x, y) => y.sc - x.sc)
            .map(x => ({ kind: "win", title: x.t.title, sub: (x.t.lastIpcObject && x.t.lastIpcObject.class ? x.t.lastIpcObject.class : "") + (x.t.workspace ? "  ·  workspace " + x.t.workspace.id : ""), glyph: "󰖯", top: x.t }))
        if (view === "emoji") return emojis.filter(e => score(e.name, s) > 0).slice(0, 120).map(e => ({ kind: "emoji", title: e.ch, sub: e.name }))
        if (view === "tools") return tools.filter(t => Math.max(score(t.title, s), score(t.sub, s) * 0.6) > 0)
            .map(t => ({ kind: "tool", title: t.title, sub: t.sub, glyph: t.glyph, tool: t }))
        if (view === "keys") return Binds.list.filter(b => Math.max(score(b.keys, s), score(b.action, s), score(b.group, s) * 0.6) > 0)
            .map(b => ({ kind: "key", title: b.keys, sub: b.action + "  ·  " + b.group, glyph: "󰌌" }))
        if (view === "scripts") return scripts.filter(sc => Math.max(score(sc.title, s), score(sc.desc, s) * 0.6) > 0)
            .map(sc => ({ kind: "script", title: sc.title, sub: sc.desc + (sc.terminal ? "" : "  ·  runs in the background"), glyph: sc.terminal ? "󰆍" : "󰑓", sc: sc }))
        return []
    }
    onResultsChanged: sel = Math.min(sel, Math.max(0, results.length - 1))

    // ---------- actions ----------
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]) }
    function activate(r, alt) {
        if (!r || r.kind === "none" || r.off) return
        if (r.kind === "menu") {
            if (r.target === "settings") { Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "themes"]); root.done(); return }
            openView(r.target); return
        }
        if (r.kind === "app") {
            bump(r.entry.id)
            // Terminal=true apps (ncspot, htop, ...): Quickshell's execute() ignores that flag -> open them in kitty
            if (r.entry.runInTerminal) Quickshell.execDetached(["kitty", "--class", r.entry.startupClass || r.entry.id, "-e"].concat(r.entry.command))
            else r.entry.execute()
        }
        else if (r.kind === "run") Quickshell.execDetached(alt ? ["kitty", "-e", "sh", "-c", r.cmd + "; exec bash"] : ["sh", "-c", r.cmd])
        else if (r.kind === "calc") { if (!calcResult) return; copy(calcResult) }
        else if (r.kind === "clip") Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", r.line])
        else if (r.kind === "win") { const a = r.top.address; Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + (a.startsWith("0x") ? a : "0x" + a) + "\" })") }
        else if (r.kind === "emoji") copy(r.title)
        else if (r.kind === "script") runScript(r.sc)
        else if (r.kind === "tool") runTool(r.tool)
        else if (r.kind === "key") Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "keys"])
        root.done()
    }

    // ================= UI =================
    Column {
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 10

        // search field (with the breadcrumb inside a menu)
        Rectangle {
            width: parent.width; height: 44; radius: 2
            color: Theme.surface
            border.width: 1; border.color: Qt.alpha(Theme.coral, input.activeFocus ? 0.7 : 0.25)
            Text {
                id: searchIcon
                anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: root.view === "main" ? "󰍉" : root.viewInfo(root.view).glyph
                color: Theme.coral; font.family: Theme.font; font.pixelSize: 18
            }
            Text {
                id: crumbText
                visible: root.crumb !== ""
                anchors.left: searchIcon.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: root.crumb
                color: Theme.coral; font.family: Theme.font; font.pixelSize: 14; font.bold: true
            }
            TextInput {
                id: input
                anchors.left: crumbText.visible ? crumbText.right : searchIcon.right; anchors.leftMargin: 12
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4)
                font.family: Theme.font; font.pixelSize: 16
                clip: true
                Text {
                    visible: !input.text
                    text: root.view === "main" ? "Search apps, math or a command  ·  > for the menu" : "Search…"
                    color: Theme.dim; font: input.font
                }
                Keys.onPressed: (e) => {
                    const n = root.results.length, cols = root.view === "emoji" ? grid.cols : 1
                    if (e.key === Qt.Key_Escape) { root.back(); e.accepted = true }
                    else if (e.key === Qt.Key_Backspace && input.text === "" && root.stack.length) { root.back(); e.accepted = true }
                    else if (e.key === Qt.Key_Down) { root.sel = Math.min(n - 1, root.sel + cols); e.accepted = true }
                    else if (e.key === Qt.Key_Up) { root.sel = Math.max(0, root.sel - cols); e.accepted = true }
                    else if (e.key === Qt.Key_Right && root.view === "emoji") { root.sel = Math.min(n - 1, root.sel + 1); e.accepted = true }
                    else if (e.key === Qt.Key_Left && root.view === "emoji") { root.sel = Math.max(0, root.sel - 1); e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.activate(root.results[root.sel], e.modifiers & Qt.ControlModifier); e.accepted = true }
                    else if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier) && root.view === "clip") {
                        const r = root.results[root.sel]
                        if (r) { clipDo.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", r.line]; clipDo.running = true }
                        e.accepted = true
                    }
                }
            }
        }

        // results: a list, or a grid for emoji
        Item {
            width: parent.width
            height: parent.height - 44 - 18 - 2 * parent.spacing

            ScrollList {
                id: list
                visible: root.view !== "emoji"
                anchors.fill: parent
                model: root.results
                currentIndex: root.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    width: ListView.view.width - ListView.view.rightMargin
                    height: 44; radius: 2
                    opacity: row.modelData.off ? 0.45 : 1
                    color: (on ? Qt.alpha(Theme.coral, 0.14) : (rm.containsMouse ? Theme.raised : "transparent"))
                    Item {
                        id: ic
                        anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26
                        // an app without a standard type icon: its own logo, turned plain white
                        readonly property bool useLogo: row.modelData.kind === "app" && !row.modelData.glyph && img.source != ""
                        IconImage {
                            id: img
                            anchors.fill: parent
                            visible: false                 // drawn through the white effect below
                            source: row.modelData.kind === "app" && !row.modelData.glyph ? Notifs.resolve(row.modelData.icon) : ""
                            asynchronous: true
                        }
                        MultiEffect {
                            visible: ic.useLogo
                            anchors.fill: img
                            source: img
                            brightness: 1.0                 // every pixel white, the logo's shape kept by its alpha
                            colorization: 1.0
                            colorizationColor: Theme.text
                        }
                        Text {
                            visible: !ic.useLogo
                            anchors.centerIn: parent
                            text: row.modelData.glyph || "󰀻"
                            color: Theme.text
                            font.family: Theme.font; font.pixelSize: 19
                        }
                    }
                    Column {
                        anchors.left: ic.right; anchors.leftMargin: 12
                        anchors.right: more.left; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: row.modelData.title; textFormat: Text.PlainText
                            color: row.on ? Theme.coral : Theme.text
                            font.family: Theme.font; font.pixelSize: 13; font.bold: row.on
                        }
                        Text {
                            visible: text !== ""
                            width: parent.width; elide: Text.ElideRight
                            text: row.modelData.sub || ""; textFormat: Text.PlainText
                            color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
                    Text {   // "opens a list" marker for menu entries
                        id: more
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.more ? "󰅂" : ""
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 18
                    }
                    MouseArea {
                        id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = row.index
                        onClicked: root.activate(row.modelData, false)
                    }
                }
                Text {
                    parent: list
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: root.view === "clip" ? "Clipboard history is empty" : "Nothing found"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
            }

            GridView {
                id: grid
                visible: root.view === "emoji"
                anchors.fill: parent
                clip: true
                readonly property int cols: 14
                cellWidth: width / cols; cellHeight: cellWidth
                model: root.results
                currentIndex: root.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    width: grid.cellWidth - 4; height: grid.cellHeight - 4; radius: 2
                    color: on ? Qt.alpha(Theme.coral, 0.18) : (em.containsMouse ? Theme.raised : "transparent")
                    Text { anchors.centerIn: parent; text: cell.modelData.title; font.pixelSize: 26 }
                    MouseArea {
                        id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = cell.index
                        onClicked: root.activate(cell.modelData, false)
                    }
                }
            }
        }

        // footer: selected emoji name / key hints
        Text {
            width: parent.width; height: 18; elide: Text.ElideRight
            text: root.view === "emoji" && root.results[root.sel] ? root.results[root.sel].sub
                : "↑↓ select · Enter open · " + (root.stack.length ? "Backspace/Esc back" : "Esc close")
                  + (root.view === "clip" ? " · Shift+Del remove" : "") + (root.view === "main" ? " · > menu · Ctrl+Enter runs a command in a terminal" : "")
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
        }
    }
}

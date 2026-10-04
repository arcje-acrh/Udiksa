// Binds.qml -- singleton: every keyboard shortcut, for Settings > Shortcuts and the launcher's "> Keybinds" list.
// Read from ~/.config/hypr/conf/binds.lua (grouped by the comment above each block) plus the ones added in Settings
// (~/.config/hypr/local/settings.lua, group "Your shortcuts"). Both files are watched: edits show up at once.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/conf/binds.lua"
    property var rice: []             // [{ group, keys, action }]
    property var mine: []
    readonly property var list: mine.concat(rice)

    // an action as words: "run kitty", "window.close", or the comment after a Lua function
    function human(a) {
        if (a.startsWith("-- ")) return a.slice(3)
        a = a.trim().replace(/,\s*\{[^}]*\}\s*$/, "")                  // drop the options table
        let m = a.match(/^hl\.dsp\.exec_cmd\((.*)\)$/)
        if (m) return "run  " + m[1].replace(/programs\.(\w+)/g, "$1").replace(/"\s*\.\.\s*|\s*\.\.\s*"/g, "").replace(/"/g, "")
        return a.replace(/^hl\.dsp\./, "").replace(/\(\)$/, "").replace(/[{}"]/g, "").replace(/\s+/g, " ")
    }
    function parse(text, fixed) {
        const out = []; let group = fixed || "General"
        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (!fixed && /^--\s*\S/.test(line) && !/^--\s*(https?:|NOTE)/i.test(line)) { group = line.replace(/^--\s*/, "").replace(/\s*\(.*$/, "").replace(/:.*$/, ""); continue }
            let m = line.match(/^hl\.bind\((.+?),\s*(hl\..*)\)\s*$/)
            // a key that runs a Lua function: its action is the comment after `function()`
            const fm = m ? null : line.match(/^hl\.bind\((.+?),\s*function\(\)\s*--\s*(.*)$/)
            if (fm) m = [line, fm[1], "-- " + fm[2]]
            if (!m) continue
            let keys = m[1].replace(/mainMod\s*\.\.\s*"/, "SUPER").replace(/"\s*\.\.\s*key/, " + 0-9").replace(/"/g, "").replace(/\s*\.\.\s*/g, "")
            keys = keys.replace(/\s*\+\s*/g, " + ").trim()
            out.push({ group: group.length > 60 ? group.slice(0, 60) + "…" : group, keys: keys, action: human(m[2]) })
        }
        return out
    }
    FileView { path: root.file; watchChanges: true; onFileChanged: reload(); onLoaded: root.rice = root.parse(text(), "") }
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/local/settings.lua"
        watchChanges: true; onFileChanged: reload(); onLoaded: root.mine = root.parse(text(), "Your shortcuts")
    }
}

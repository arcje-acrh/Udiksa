// Settings.qml -- the Settings app: a floating, centred window (user 2026-09-26; was full screen), sections down the left as retro
// LED keys, the chosen section on the right. Changes apply at once. Open: Super+I, the launcher's "Settings"
// entry, or `qs ipc call settings toggle | open <section>`. Keys: Esc close, Ctrl+↑/↓ (or Ctrl+Tab) section.
// Hyprland options go through ~/.local/bin/rice-settings (saves + writes ~/.config/hypr/conf/settings.lua).
// Sections are grouped (user 2026-09-28: Personalise / Devices / Network / Power / System); each page is its own file
// Set<Name>.qml, a section with `tabs` has several (Apps: SetApps + SetSoftware, Advanced: SetFiles + SetScripts).
// Pages get `host` (this object) to read/write.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property bool open: false
    property bool shown: false
    property string section: "themes"
    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: home + "/.local/bin/rice-settings"
    // group = sidebar heading; tabs = a section made of several pages (a switch under the title)
    readonly property var sections: [
        { id: "themes",    group: "Personalise", file: "Themes",      name: "Themes",             icon: "󰸉", desc: "theme, wallpaper, theme colours" },
        { id: "look",      group: "Personalise", file: "Look",        name: "Windows",            icon: "󰏘", desc: "tiling layout, new windows, gaps, borders, corners, shadows, blur, animations" },
        { id: "slash",     group: "Personalise", needs: "slash", file: "Slash", name: "Slash lighting", icon: "󰛨", desc: "the LED bar on the lid: animation, brightness, when it lights" },
        { id: "display",   group: "Devices",     file: "Display",     name: "Display",            icon: "󰍹", desc: "brightness, refresh rate, external monitor" },
        { id: "sound",     group: "Devices",     file: "Sound",       name: "Sound",              icon: "󰕾", desc: "output, microphone, app volumes, headphones" },
        { id: "keyboard",  group: "Devices",     file: "Keyboard",    name: "Keyboard & touchpad", icon: "󰌌", desc: "layout, key repeat, light, touchpad" },
        { id: "keys",      group: "Devices",     file: "Keys",        name: "Shortcuts",          icon: "󰘳", desc: "every key binding, add your own" },
        { id: "wifi",      group: "Network",     needs: "wifi", file: "Wifi",        name: "Wi-Fi",              icon: "󰖩", desc: "networks, passwords, hidden networks, airplane mode" },
        { id: "bluetooth", group: "Network",     needs: "bt",   file: "Bluetooth",   name: "Bluetooth",          icon: "󰂯", desc: "pair, connect, forget" },
        { id: "tailscale", group: "Network",     needs: "tailscale", file: "Tailscale",   name: "Tailscale",          icon: "󰖂", desc: "your devices, exit node, DNS, routes" },
        { id: "power",     group: "Power",       file: "Power",       name: "Battery & sleep",    icon: "󰂄", desc: "battery, charge limit, idle, lid, hibernate" },
        { id: "perf",      group: "Power",       needs: "modes", file: "Performance", name: "Performance",        icon: "󰓅", desc: "Silent / Balanced / Turbo, CPU power, fans, sensors" },
        { id: "gpu",       group: "Power",       needs: "gfx",  file: "Gpu",         name: "GPU",                icon: "󰢮", desc: "GPU mode, NVIDIA card, temperature, boost, GPU fan" },
        { id: "notify",    group: "System",      file: "Notify",      name: "Notifications",      icon: "󰂚", desc: "do not disturb, history, calendar" },
        { id: "apps",      group: "System",      name: "Apps",                icon: "󰀻", desc: "default apps, startup apps, install and remove",
          tabs: [{ name: "Default and startup", file: "Apps" }, { name: "Install and remove", file: "Software" }] },
        { id: "region",    group: "System",      file: "Region",      name: "Date & language",    icon: "󰥔", desc: "time, timezone, language, weather" },
        { id: "advanced",  group: "System",      name: "Advanced",            icon: "󰒓", desc: "configuration files, maintenance scripts",
          tabs: [{ name: "Config files", file: "Files" }, { name: "Scripts", file: "Scripts" }] },
        { id: "about",     group: "System",      file: "About",       name: "About",              icon: "󰋼", desc: "you and this machine" }
    ]
    property int tab: 0
    onSectionChanged: tab = 0
    // sections for hardware this machine lacks are left out (rule: show only what works here). needs: "modes" =
    // asusctl or power-profiles-daemon, "gfx" = supergfxctl, "slash" = a Slash lid bar, "wifi" / "bt" = the adapter,
    // "tailscale" = installed. Flags: Power.qml. Pages also rename to fit (no touchpad / no battery).
    function has(n) {
        return n === "modes" ? Power.hasModes : n === "gfx" ? Power.gfx : n === "slash" ? Power.slash
             : n === "wifi" ? Power.wifi : n === "bt" ? Power.bt : n === "tailscale" ? Tailscale.installed : true
    }
    readonly property var shownSections: sections.filter(s => !s.needs || has(s.needs)).map(s =>
          s.id === "keyboard" && !Power.touchpad ? Object.assign({}, s, { name: "Keyboard", desc: "layout, key repeat" + (Power.kbd ? ", light" : "") })
        : s.id === "power" && !Power.battery ? Object.assign({}, s, { name: "Power & sleep", desc: "idle, sleep, power button, hibernate" })
        : s)
    readonly property var cur: shownSections.find(s => s.id === section) || shownSections[0]

    function toggle() { if (open) close(); else show(section) }
    function show(s) { if (s) section = s; load(); open = true; shown = true }
    function close() { open = false; hideTimer.restart() }
    function step(d) {
        const L = shownSections, i = L.findIndex(s => s.id === section)
        section = L[(i + d + L.length) % L.length].id
    }
    Timer { id: hideTimer; interval: 320; onTriggered: if (!root.open) root.shown = false }

    // ---------- Hyprland options (rice-settings) ----------
    property var hv: ({})                     // current values from `rice-settings get`
    function load() { getter.running = true }
    Process {
        id: getter
        command: [root.helper, "get"]
        stdout: StdioCollector { onStreamFinished: { try { root.hv = JSON.parse(text) } catch (e) {} } }
    }
    // set(key, value): shown at once, written by one rice-settings call at a time (latest value per key wins)
    property var pending: ({})
    function set(key, value) {
        const h = JSON.parse(JSON.stringify(hv)); h[key] = value; hv = h
        const p = JSON.parse(JSON.stringify(pending)); p[key] = value; pending = p
        flush.restart()
    }
    Timer { id: flush; interval: 180; onTriggered: root.nextSet() }
    function nextSet() {
        if (setter.running) return
        const keys = Object.keys(pending)
        if (!keys.length) return
        const k = keys[0], v = pending[k]
        const p = JSON.parse(JSON.stringify(pending)); delete p[k]; pending = p
        setter.command = [root.helper, "set", k, String(v)]
        setter.running = true
    }
    Process { id: setter; onExited: root.nextSet() }
    function run(cmd) { Quickshell.execDetached(cmd) }
    // open a file in nano inside kitty (config files that have no controls here)
    function edit(path) { run(["kitty", "--class", "rice-edit", "-e", "nano", path]) }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function open(section: string): void { root.show(section) }
        function close(): void { root.close() }
    }

    FloatingWindow {
        id: win
        visible: root.shown
        title: "Settings"                  // Hyprland rule "settings-window" (rules.lua): float, centre, 1600x1000
        implicitWidth: 1600
        implicitHeight: 1000
        color: Theme.bg
        onVisibleChanged: if (!visible && root.shown) { root.open = false; root.shown = false }   // closed by the WM (Super+Q)

        Item {
            id: stage
            anchors.fill: parent
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.open ? 220 : 260; easing.type: Easing.OutCubic } }
            focus: root.open
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (e) => {
                const ctrl = e.modifiers & Qt.ControlModifier
                if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true }
                else if (ctrl && (e.key === Qt.Key_Down || e.key === Qt.Key_Tab)) { root.step(1); e.accepted = true }
                else if (ctrl && (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab)) { root.step(-1); e.accepted = true }
            }

            Rectangle { anchors.fill: parent; color: Theme.bg }

            // ---------- sidebar ----------
            Rectangle {
                id: side
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 260
                color: Theme.surface
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.raised }

                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24; topMargin: 32 }
                    spacing: 4
                    Text { text: "SETTINGS"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; font.bold: true; font.letterSpacing: 3 }
                    Item { width: 1; height: 10 }
                    Repeater {
                        model: root.shownSections
                        delegate: Column {
                            id: entry
                            required property var modelData
                            required property int index
                            width: parent.width
                            spacing: 4
                            Text {   // group heading, above the first section of each group
                                visible: entry.index === 0 || root.shownSections[entry.index - 1].group !== entry.modelData.group
                                topPadding: entry.index === 0 ? 0 : 10
                                text: entry.modelData.group.toUpperCase(); color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2
                            }
                        Rectangle {
                            id: key
                            readonly property var modelData: entry.modelData
                            readonly property bool on: root.section === modelData.id
                            width: parent.width; height: 34; radius: 2
                            color: on ? Theme.bg : (km.containsMouse ? Theme.hover : Theme.raised)
                            border.width: 1; border.color: on ? Theme.dim : Theme.hover
                            KeyEdge { pressed: key.on }
                            Rectangle {   // LED
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                width: 5; height: 5; radius: 2.5
                                color: key.on ? Theme.coral : Theme.dim
                                Rectangle { visible: key.on; anchors.centerIn: parent; width: 11; height: 11; radius: 5.5; z: -1; color: Qt.alpha(Theme.coral, 0.3) }
                            }
                            Text {
                                x: 28; anchors.verticalCenter: parent.verticalCenter
                                text: key.modelData.icon; color: key.on ? Theme.coral : Theme.muted
                                font.family: Theme.font; font.pixelSize: 16
                            }
                            Text {
                                x: 56; anchors.verticalCenter: parent.verticalCenter
                                text: key.modelData.name.toUpperCase(); color: key.on ? Theme.text : Theme.muted
                                font.family: Theme.font; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.5
                            }
                            MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.section = key.modelData.id }
                        }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
                    text: "esc close · ctrl+↑↓ section"
                    color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                }
            }

            // ---------- page ----------
            Item {
                id: page
                anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 40; rightMargin: 36; topMargin: 32; bottomMargin: 24 }

                Row {
                    id: head
                    spacing: 14
                    Text { text: root.cur.icon; color: Theme.coral; font.family: Theme.font; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: root.cur.name.toUpperCase(); color: Theme.text; font.family: Theme.font; font.pixelSize: 22; font.bold: true; font.letterSpacing: 3 }
                        Text { text: root.cur.desc; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                    }
                }
                Seg {
                    anchors { right: parent.right; verticalCenter: head.verticalCenter }
                    visible: !!root.cur.tabs
                    options: root.cur.tabs ? root.cur.tabs.map(t => t.name) : []
                    current: root.tab
                    onPicked: (i) => root.tab = i
                }
                Rectangle { id: rule; anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 18 } height: 1; color: Theme.raised }

                Loader {
                    id: pageLoader
                    anchors { left: parent.left; right: parent.right; top: rule.bottom; bottom: parent.bottom; topMargin: 18 }
                    active: root.shown
                    source: "Set" + (root.cur.tabs ? root.cur.tabs[Math.min(root.tab, root.cur.tabs.length - 1)].file : root.cur.file) + ".qml"
                    onLoaded: item.host = root
                }
            }
        }
    }
}

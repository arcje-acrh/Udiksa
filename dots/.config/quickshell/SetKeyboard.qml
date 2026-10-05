// SetKeyboard.qml -- Settings > Mouse & keyboard (was Keyboard & touchpad; split from Devices, 2026-09-28): mouse pointer
// (moved here from Themes 2026-10-03: style, size, shake to find), layout (from a list or typed),
// key repeat, keyboard light (ASUS: brightness, effect, colour / follow theme, speed, direction, when lit -- via
// ~/.local/bin/udiksa kbd, saved in ~/.config/udiksa/keyboard.json), touchpad. Hyprland options go through udiksa settings (settings.lua); the light via Power.qml.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    readonly property var v: host ? host.hv : ({})
    function set(k, val) { host.set(k, val) }
    function onoff(b) { return b ? 0 : 1 }

    // ---- keyboard layouts offered (layout + variant); anything else: type it ----
    readonly property var layouts: [
        { n: "English (US)", l: "us", v: "" },
        { n: "English (US, international)", l: "us", v: "intl" },
        { n: "English (UK)", l: "gb", v: "" },
        { n: "Hindi (Bolnagri)", l: "in", v: "bolnagri" },
        { n: "German", l: "de", v: "" },
        { n: "French", l: "fr", v: "" },
        { n: "Spanish", l: "es", v: "" }
    ]
    function setLayout(l, va) { page.set("kb_layout", l); page.set("kb_variant", va) }
    Component.onCompleted: Power.readKbd()

    // ---- mouse pointer (udiksa settings cursor): Udiksa = Bibata Original in the theme colours, or a Bibata ----
    SetGroup { title: "Pointer" }
    property var cursor: ({ theme: "Udiksa", size: 25 })
    readonly property var hostCursor: host && host.hv ? host.hv.cursor : undefined
    onHostCursorChanged: if (hostCursor) cursor = JSON.parse(JSON.stringify(hostCursor))
    function setCursor(theme, size) {
        cursor = { theme: theme, size: size }
        cursorProc.command = [page.host.helper, "cursor", theme, String(size)]
        cursorProc.running = true
    }
    Process { id: cursorProc }
    SetRow {
        title: "Mouse pointer"
        desc: "Udiksa = in the theme's colour, changing with every theme. The others are Bibata's own colours. Original = pointy, Modern = rounded."
    }
    Flow {
        width: parent.width
        spacing: 6
        Repeater {
            model: [
                { id: "Udiksa", name: "Udiksa Original" }, { id: "Udiksa-Modern", name: "Udiksa Modern" },
                { id: "Bibata-Original-Classic", name: "Original Classic" }, { id: "Bibata-Original-Ice", name: "Original Ice" },
                { id: "Bibata-Original-Amber", name: "Original Amber" }, { id: "Bibata-Modern-Classic", name: "Modern Classic" },
                { id: "Bibata-Modern-Ice", name: "Modern Ice" }, { id: "Bibata-Modern-Amber", name: "Modern Amber" }
            ]
            delegate: SetButton {
                required property var modelData
                text: modelData.name
                accent: page.cursor.theme === modelData.id
                onClicked: page.setCursor(modelData.id, page.cursor.size)
            }
        }
    }
    SetRow {
        title: "Pointer size"
        Seg {
            readonly property var vals: [20, 24, 25, 28, 32]
            options: vals.map(v => v + " px")
            current: vals.indexOf(page.cursor.size)
            onPicked: (i) => page.setCursor(page.cursor.theme, vals[i])
        }
    }

    SetRow {
        title: "Shake to find"
        desc: (page.host && page.host.hv && page.host.hv.shake && !page.host.hv.shake.plugin)
              ? "Needs the dynamic-cursors plugin (built with hyprpm). Install opens a terminal; takes a few minutes."
              : "Shake the mouse and the pointer grows for a moment, so you see where it is (like macOS)."
        Row {
            spacing: 8
            SetButton {
                visible: !!(page.host && page.host.hv && page.host.hv.shake && !page.host.hv.shake.plugin)
                text: "Install"
                onClicked: Quickshell.execDetached(["kitty", "--class", "rice-script", "--title", "Shake to find", "-e", "bash", "-c",
                    "hyprpm update && yes | hyprpm add https://github.com/virtcode/hypr-dynamic-cursors; hyprpm enable dynamic-cursors && hyprpm reload; echo; read -rp 'Done. Press Enter to close.'"])
            }
            Seg {
                options: ["Off", "On"]
                current: page.shakeOn ? 1 : 0
                onPicked: (i) => { page.shakeOn = i === 1; shakeProc.command = [page.host.helper, "shake", i === 1 ? "on" : "off"]; shakeProc.running = true }
            }
        }
    }
    property bool shakeOn: true
    readonly property var hostShake: host && host.hv ? host.hv.shake : undefined
    onHostShakeChanged: if (hostShake) shakeOn = hostShake.on !== false
    Process { id: shakeProc }

    SetGroup { title: "Keyboard"; action: "reset keyboard + touchpad to my config files"; onActionClicked: { Quickshell.execDetached([host.helper, "reset", "input"]); resetLater.restart() } }
    Timer { id: resetLater; interval: 900; onTriggered: host.load() }
    SetRow {
        title: "Layout"
        desc: "In use: " + (page.v.kb_layout || "us") + (page.v.kb_variant ? " (" + page.v.kb_variant + ")" : "")
        Column {
            spacing: 6
            Flow {
                width: 640
                spacing: 6
                layoutDirection: Qt.RightToLeft
                Repeater {
                model: page.layouts
                delegate: SetButton {
                    required property var modelData
                    text: modelData.n
                    accent: (page.v.kb_layout || "us") === modelData.l && (page.v.kb_variant || "") === modelData.v
                    onClicked: page.setLayout(modelData.l, modelData.v)
                }
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 6
                SetInput { id: other; width: 236; placeholder: "other: it, us:dvorak"; onAccepted: go.clicked() }
                SetButton { id: go; width: 58; text: "Use"; onClicked: { const p = other.text.trim().split(":"); if (p[0]) page.setLayout(p[0], p[1] || "") } }
            }
        }
    }
    SetRow {
        title: "Key repeat speed"
        desc: "Characters per second while a key is held."
        SetNum { value: page.v.repeat_rate ?? 35; from: 10; to: 80; unit: "/s"; onChanged: (x) => page.set("repeat_rate", x) }
    }
    SetRow {
        title: "Key repeat delay"
        SetNum { value: page.v.repeat_delay ?? 300; from: 150; to: 800; step: 25; unit: " ms"; onChanged: (x) => page.set("repeat_delay", x) }
    }

    // ---- keyboard light (ASUS only: ~/.local/bin/udiksa kbd; the whole group hides on other machines) ----
    property var kb: ({})
    Process {
        id: kbGet
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/udiksa", "kbd"]
        stdout: StdioCollector { onStreamFinished: { try { page.kb = JSON.parse(text) } catch (e) {} } }
    }
    property var kbPending: []
    function kset(k, v) {
        const c = JSON.parse(JSON.stringify(kb)); c[k] = v; kb = c
        kbPending = kbPending.concat([k, String(v)]); kbTimer.restart()
    }
    Timer {
        id: kbTimer; interval: 350
        onTriggered: { kbSet.command = [Quickshell.env("HOME") + "/.local/bin/udiksa", "kbd", "set"].concat(page.kbPending); page.kbPending = []; kbSet.running = true }
    }
    Process { id: kbSet; onExited: { kbGet.running = true; Power.readKbd() } }
    readonly property bool kbRgb: kb.rgb === true
    readonly property string eff: kb.effect || "static"
    readonly property var swatches: ["ffffff", String(Theme.coral).slice(1, 7), String(Theme.amber).slice(1, 7), "ff2a2a", "ff8c00", "ffd400", "2aff6a", "00c8ff", "2a5bff", "b02aff", "ff2ad4"]

    component Swatches: Row {
        id: sw
        property string key: "colour"
        spacing: 6
        Repeater {
            model: page.swatches
            delegate: Rectangle {
                required property var modelData
                width: 26; height: 26; radius: 2
                color: "#" + modelData
                border.width: (page.kb[sw.key] || "") === modelData ? 2 : 1
                border.color: border.width === 2 ? Theme.text : Theme.hover
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.kset("follow_theme", false); page.kset(sw.key, modelData) } }
            }
        }
        SetInput {
            width: 96; text: "#" + (page.kb[sw.key] || "")
            onAccepted: if (/^#?[0-9a-fA-F]{6}$/.test(text)) { page.kset("follow_theme", false); page.kset(sw.key, text.replace("#", "").toLowerCase()) }
        }
    }

    // ASUS: udiksa kbd (colours, effects, saved); any other backlit keyboard: brightness only (Power.qml, brightnessctl)
    readonly property bool plainKbd: page.kb.capable !== true && Power.kbd
    SetGroup { title: "Keyboard light"; visible: page.kb.capable === true || page.plainKbd }
    SetRow {
        visible: page.plainKbd
        title: "Brightness"
        desc: "Same as the notch's System panel."
        Seg { options: Power.kbdLabels; current: Power.kbdLevel; onPicked: (i) => Power.setKbd(i) }
    }
    SetRow {
        visible: page.kb.capable === true
        title: "Brightness"
        desc: page.kbRgb ? "The whole keyboard is one colour on this model (no per-key lights)." : "This keyboard has a white light only."
        Seg { options: ["Off", "Low", "Med", "High"]; current: ["off", "low", "med", "high"].indexOf(page.kb.brightness); onPicked: (i) => page.kset("brightness", ["off", "low", "med", "high"][i]) }
    }
    SetRow {
        visible: page.kbRgb
        title: "Effect"
        desc: page.eff === "breathe" ? "Fades between two colours." : page.eff === "rainbow-cycle" ? "The whole keyboard cycles through all colours."
            : page.eff === "rainbow-wave" ? "A rainbow moving across the keys." : page.eff === "pulse" ? "One colour pulsing." : "One steady colour."
        Seg {
            readonly property var vals: ["static", "breathe", "rainbow-cycle", "rainbow-wave", "pulse"]
            options: ["Steady", "Breathe", "Colour cycle", "Rainbow wave", "Pulse"]
            current: vals.indexOf(page.eff)
            onPicked: (i) => page.kset("effect", vals[i])
        }
    }
    SetRow {
        visible: page.kbRgb && ["static", "breathe", "pulse"].indexOf(page.eff) >= 0
        title: "Follow the theme"
        desc: "On: the keyboard always has the theme's accent colour (second accent for Breathe) and changes with every theme switch. Off: a colour you pick below."
        Seg { options: ["On", "Off"]; current: page.kb.follow_theme ? 0 : 1; onPicked: (i) => page.kset("follow_theme", i === 0) }
    }
    SetRow {
        visible: page.kbRgb && ["static", "breathe", "pulse"].indexOf(page.eff) >= 0 && !page.kb.follow_theme
        title: page.eff === "breathe" ? "First colour" : "Colour"
        desc: "A fixed colour. The 2nd and 3rd squares are the current theme's accents as they are now; to change with every theme, turn on Follow the theme."
        Swatches { key: "colour" }
    }
    SetRow {
        visible: page.kbRgb && page.eff === "breathe" && !page.kb.follow_theme
        title: "Second colour"
        Swatches { key: "colour2" }
    }
    SetRow {
        visible: page.kbRgb && ["breathe", "rainbow-cycle", "rainbow-wave"].indexOf(page.eff) >= 0
        title: "Speed"
        Seg { readonly property var vals: ["low", "med", "high"]; options: ["Slow", "Medium", "Fast"]; current: vals.indexOf(page.kb.speed); onPicked: (i) => page.kset("speed", vals[i]) }
    }
    SetRow {
        visible: page.kbRgb && page.eff === "rainbow-wave"
        title: "Direction"
        Seg { readonly property var vals: ["left", "right", "up", "down"]; options: ["← Left", "Right →", "↑ Up", "↓ Down"]; current: vals.indexOf(page.kb.direction); onPicked: (i) => page.kset("direction", vals[i]) }
    }
    SetRow {
        visible: page.kbRgb
        title: "Lit while"
        desc: "Turn one off to keep the keyboard dark at that time (e.g. while asleep)."
        Row {
            spacing: 8
            Repeater {
                model: [{ k: "boot", n: "Starting" }, { k: "awake", n: "Awake" }, { k: "sleep", n: "Asleep" }, { k: "shutdown", n: "Shutting down" }]
                delegate: Seg {
                    required property var modelData
                    options: [modelData.n]
                    current: page.kb[modelData.k] ? 0 : -1
                    onPicked: page.kset(modelData.k, !page.kb[modelData.k])
                }
            }
        }
    }

    // touchpad rows only with a touchpad; pointer speed is for every mouse too (a desktop sees it under "Mouse")
    SetGroup { title: Power.touchpad ? "Touchpad" : "Mouse" }
    SetRow {
        visible: Power.touchpad
        title: "Natural scrolling"
        desc: "Content follows your fingers."
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.natural_scroll); onPicked: (i) => page.set("natural_scroll", i === 0) }
    }
    SetRow {
        visible: Power.touchpad
        title: "Tap to click"
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.tap_to_click); onPicked: (i) => page.set("tap_to_click", i === 0) }
    }
    SetRow {
        visible: Power.touchpad
        title: "Ignore touchpad while typing"
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.disable_while_typing); onPicked: (i) => page.set("disable_while_typing", i === 0) }
    }
    SetRow {
        title: "Pointer speed"
        desc: "0 = normal."
        SetNum { value: page.v.sensitivity ?? 0; from: -1; to: 1; step: 0.1; decimals: 1; onChanged: (x) => page.set("sensitivity", x) }
    }
}

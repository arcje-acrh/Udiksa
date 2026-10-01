// SetLook.qml -- Settings > Windows: tiling layout + where new windows open, window gaps / borders / corners / opacity, shadows (size, sharpness, colour,
// strength), blur, dim, animations. Values = Hyprland's live ones (re-read every time Settings opens);
// changes are saved in ~/.config/hypr/conf/settings.lua. Theme + colours: Settings > Themes.
import QtQuick
import Quickshell

SetPage {
    id: page
    // corner radii of the screen / notch (Prefs); the lock + login screen and GRUB follow a moment later (rice-theme)
    function setCorner(key, px) { Prefs.set(["corners", key], px); if (key === "screen") cornerLater.restart() }
    Timer { id: cornerLater; interval: 800; onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rice-theme", "corners"]) }
    readonly property var v: host ? host.hv : ({})
    function set(k, val) { host.set(k, val) }
    function onoff(b) { return b ? 0 : 1 }
    // shadow colour "rrggbbaa": colour part + strength (alpha) are edited separately
    readonly property string shadowHex: (v.shadow_color || "000000e6")
    readonly property string shadowRgb: shadowHex.slice(0, 6)
    readonly property int shadowAlpha: Math.round(parseInt(shadowHex.slice(6, 8) || "ff", 16) / 2.55)
    function setShadow(rgb, alphaPct) {
        const a = Math.round(Math.max(0, Math.min(100, alphaPct)) * 2.55).toString(16).padStart(2, "0")
        set("shadow_color", rgb.replace("#", "").toLowerCase() + a)
    }

    // ---- tiling: how windows share the screen, where new ones go (only the chosen layout's options show) ----
    readonly property string lay: v.layout || "dwindle"
    SetGroup { title: "Tiling"; action: "reset tiling to my config files"; onActionClicked: { Quickshell.execDetached([host.helper, "reset", "layout"]); resetLater.restart() } }
    SetRow {
        title: "Layout"
        desc: ["Split: each new window splits the space of the one it opens from.",
               "Main + stack: one big main window, the rest stacked beside it.",
               "Scrolling: windows sit in columns on a strip that scrolls sideways.",
               "One at a time: every window fills the screen, the others wait behind it."][["dwindle", "master", "scrolling", "monocle"].indexOf(page.lay)] || ""
        Seg {
            readonly property var vals: ["dwindle", "master", "scrolling", "monocle"]
            options: ["Split", "Main + stack", "Scrolling", "One at a time"]
            current: vals.indexOf(page.lay)
            onPicked: (i) => page.set("layout", vals[i])
        }
    }
    // Split (dwindle)
    SetRow {
        visible: page.lay === "dwindle"
        title: "New windows open"
        desc: "Right / below: the new window always takes the right (or lower) half."
        Seg { options: ["Next to the mouse", "Left / above", "Right / below"]; current: page.v.force_split ?? 0; onPicked: (i) => page.set("force_split", i) }
    }
    SetRow {
        visible: page.lay === "dwindle"
        title: "First window's share"
        desc: "How much of a split the older window keeps."
        SetNum { value: Math.round((page.v.split_ratio ?? 1) * 50); from: 20; to: 80; step: 5; unit: " %"; onChanged: (x) => page.set("split_ratio", x / 50) }
    }
    SetRow {
        visible: page.lay === "dwindle"
        title: "Keep split direction"
        desc: "On: a split stays side by side (or stacked) when windows are resized or closed."
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.preserve_split); onPicked: (i) => page.set("preserve_split", i === 0) }
    }
    // Main + stack (master)
    SetRow {
        visible: page.lay === "master"
        title: "Main window side"
        Seg {
            readonly property var vals: ["left", "right", "top", "bottom", "center"]
            options: ["Left", "Right", "Top", "Bottom", "Centre"]
            current: vals.indexOf(page.v.master_side || "left")
            onPicked: (i) => page.set("master_side", vals[i])
        }
    }
    SetRow {
        visible: page.lay === "master"
        title: "New windows"
        Seg {
            readonly property var vals: ["master", "slave"]
            options: ["Become the main window", "Join the stack"]
            current: Math.max(0, vals.indexOf(page.v.master_new || "master"))
            onPicked: (i) => page.set("master_new", vals[i])
        }
    }
    SetRow {
        visible: page.lay === "master" && page.v.master_new === "slave"
        title: "Place in the stack"
        Seg { options: ["Top", "Bottom"]; current: page.v.master_new_top ? 0 : 1; onPicked: (i) => page.set("master_new_top", i === 0) }
    }
    SetRow {
        visible: page.lay === "master"
        title: "Main window size"
        SetNum { value: Math.round((page.v.master_size ?? 0.55) * 100); from: 20; to: 90; step: 5; unit: " %"; onChanged: (x) => page.set("master_size", x / 100) }
    }
    // Scrolling
    SetRow {
        visible: page.lay === "scrolling"
        title: "New columns go"
        Seg {
            readonly property var vals: ["right", "left", "down", "up"]
            options: ["Right", "Left", "Down", "Up"]
            current: Math.max(0, vals.indexOf(page.v.scroll_direction || "right"))
            onPicked: (i) => page.set("scroll_direction", vals[i])
        }
    }
    SetRow {
        visible: page.lay === "scrolling"
        title: "Column width"
        desc: "Of the screen, for new columns."
        SetNum { value: Math.round((page.v.scroll_width ?? 0.5) * 100); from: 20; to: 100; step: 5; unit: " %"; onChanged: (x) => page.set("scroll_width", x / 100) }
    }

    SetGroup { title: "Windows"; action: "reset all to my config files"; onActionClicked: { Quickshell.execDetached([host.helper, "reset", "look"]); resetLater.restart() } }
    Timer { id: resetLater; interval: 900; onTriggered: host.load() }
    SetRow {
        title: "Gap between windows"
        SetNum { value: page.v.gaps_in ?? 4; from: 0; to: 30; unit: " px"; onChanged: (x) => page.set("gaps_in", x) }
    }
    SetRow {
        title: "Gap to the screen edge"
        SetNum { value: page.v.gaps_out ?? 10; from: 0; to: 60; unit: " px"; onChanged: (x) => page.set("gaps_out", x) }
    }
    SetRow {
        title: "Border thickness"
        desc: "The line around windows; its colours come from the theme."
        SetNum { value: page.v.border_size ?? 2; from: 0; to: 8; unit: " px"; onChanged: (x) => page.set("border_size", x) }
    }
    SetRow {
        title: "Active window opacity"
        SetNum { value: Math.round((page.v.active_opacity ?? 1) * 100); from: 50; to: 100; unit: " %"; onChanged: (x) => page.set("active_opacity", x / 100) }
    }
    SetRow {
        title: "Other windows opacity"
        SetNum { value: Math.round((page.v.inactive_opacity ?? 1) * 100); from: 50; to: 100; unit: " %"; onChanged: (x) => page.set("inactive_opacity", x / 100) }
    }
    SetRow {
        title: "Dim other windows"
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.dim_inactive); onPicked: (i) => page.set("dim_inactive", i === 0) }
    }

    // ---- corners: windows (Hyprland), the screen and the notch (Prefs corners, -1 = same as the windows) ----
    SetGroup { title: "Corners" }
    SetRow {
        title: "Windows"
        desc: "How round windows are. Their visible curve is this plus the border (" + Math.round(Corners.winPx) + " px now)."
        SetNum { value: page.v.rounding ?? 8; from: 0; to: 24; unit: " px"; onChanged: (x) => page.set("rounding", x) }
    }
    component CornerRow: SetRow {
        id: cr
        property string key: ""
        property int max: 30
        readonly property int cur: (Prefs.v.corners || {})[key] ?? -1
        readonly property bool own: cur >= 0
        Row {
            spacing: 10
            Seg {
                options: ["Same as windows", "Own"]
                current: cr.own ? 1 : 0
                onPicked: (i) => page.setCorner(cr.key, i === 0 ? -1 : Math.round(Corners.winPx))
            }
            SetNum {
                visible: cr.own
                value: cr.cur; from: 0; to: cr.max; unit: " px"
                onChanged: (x) => page.setCorner(cr.key, x)
            }
        }
    }
    CornerRow {
        key: "screen"; title: "Screen corners"
        desc: "The black arcs in the corners of the screen, also on the lock and login screen and the boot menu."
    }
    CornerRow {
        key: "notch"; title: "Notch corners"; max: 15
        desc: "The notch's corners: the bottom ones and the curves where it meets the top edge (at most 15 px)."
    }

    SetGroup { title: "Shadows" }
    SetRow {
        title: "Shadows"
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.shadow); onPicked: (i) => page.set("shadow", i === 0) }
    }
    SetRow {
        title: "Size"
        desc: "How far the shadow spreads."
        SetNum { value: page.v.shadow_range ?? 12; from: 0; to: 60; unit: " px"; onChanged: (x) => page.set("shadow_range", x) }
    }
    SetRow {
        title: "Softness"
        desc: "1 = very soft, 4 = sharp edge."
        SetNum { value: page.v.shadow_power ?? 3; from: 1; to: 4; onChanged: (x) => page.set("shadow_power", x) }
    }
    SetRow {
        title: "Strength"
        SetNum { value: page.shadowAlpha; from: 0; to: 100; step: 5; unit: " %"; onChanged: (x) => page.setShadow(page.shadowRgb, x) }
    }
    SetRow {
        title: "Colour"
        desc: "Black, the theme's accent or background, or any #hex."
        Row {
            spacing: 6
            Repeater {
                model: [{ n: "Black", c: "#000000" }, { n: "Accent", c: String(Theme.coral) }, { n: "Theme", c: String(Theme.bg) }]
                delegate: Rectangle {
                    required property var modelData
                    width: 32; height: 32; radius: 2
                    color: modelData.c
                    border.width: page.shadowRgb === modelData.c.replace("#", "").slice(0, 6).toLowerCase() ? 2 : 1
                    border.color: border.width === 2 ? Theme.coral : Theme.hover
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.setShadow(modelData.c.slice(0, 7), page.shadowAlpha) }
                }
            }
            SetInput { width: 110; text: "#" + page.shadowRgb; onAccepted: if (/^#?[0-9a-fA-F]{6}$/.test(text)) page.setShadow(text, page.shadowAlpha) }
        }
    }

    SetGroup { title: "Blur and motion" }
    SetRow {
        title: "Blur"
        desc: "Frosted glass behind see-through windows and the bar."
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.blur); onPicked: (i) => page.set("blur", i === 0) }
    }
    SetRow {
        title: "Blur size"
        SetNum { value: page.v.blur_size ?? 7; from: 1; to: 20; onChanged: (x) => page.set("blur_size", x) }
    }
    SetRow {
        title: "Blur passes"
        desc: "More = smoother but uses more GPU."
        SetNum { value: page.v.blur_passes ?? 3; from: 1; to: 6; onChanged: (x) => page.set("blur_passes", x) }
    }
    SetRow {
        title: "Animations"
        desc: "Off = windows and workspaces change instantly."
        Seg { options: ["On", "Off"]; current: page.onoff(page.v.animations); onPicked: (i) => page.set("animations", i === 0) }
    }
}

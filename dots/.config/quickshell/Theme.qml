// Theme.qml -- THE ONLY place with colours, sizes and fonts for the shell.
// COLOURS come from colors.json (next to this file) -- the ONE file the auto-themer (matugen) writes.
// It is watched: saving it re-colours the whole shell live, no restart. The values below are only the
// fallback if the file is missing or broken (= the warm sunset theme, same as ~/.config/kitty/colors.conf
// and ~/.config/hypr/conf/colors.lua).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    // ---- COLOURS (from colors.json) ----
    property var c: ({})
    FileView {
        path: Qt.resolvedUrl("colors.json").toString().replace(/^file:\/\//, "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { theme.c = JSON.parse(text()) } catch (e) { console.warn("colors.json:", e) } }
    }
    function pick(key, fallback) { return c[key] ? c[key] : fallback }
    readonly property color bg:         pick("bg",         "#170d0a")
    readonly property color surface:    pick("surface",    "#2b1c17")
    readonly property color raised:     pick("raised",     "#3a2a25")
    readonly property color hover:      pick("hover",      "#47342e")
    readonly property color text:       pick("text",       "#f2dcd4")
    readonly property color muted:      pick("muted",      "#a38b85")
    readonly property color dim:        pick("dim",        "#6b5750")
    readonly property color coral:      pick("accent",     "#ff8a5c")   // main accent
    readonly property color amber:      pick("accent2",    "#f3bc7b")   // lighter accent
    readonly property color warn:       pick("warn",       "#f3bc7b")   // warnings / confirms (a theme accent, not red)
    readonly property color accentDeep: pick("accentDeep", "#7a2e4a")
    readonly property color shadow:     pick("shadow",     "#000000")
    readonly property bool  light:      c.mode === "light"       // light themes (Catppuccin Latte, White, ...)
    // ---- END COLOURS ----

    // ---- geometry (logical px; the screen is 2048x1280 at scale 1.25) ----
    readonly property int stripHeight: 30   // slim notch height = space reserved for tiling (exclusiveZone)

    // ---- notch panels (grow only: a panel is never narrower than the resting notch) ----
    // Timing preset = "Calm" (user choice 2026-09-25). Other presets for the future Settings app:
    //   Snappy 120 / 250 / 180, Balanced 200 / 350 / 260, Calm 320 / 500 / 380 (open / close / animation, ms)
    readonly property int hoverOpenDelay:  320   // hover this long on an item before its panel opens
    readonly property int hoverCloseDelay: 500   // panel closes this long after the mouse leaves the notch
    readonly property int notchAnim:       380   // grow / shrink animation
    readonly property int feedbackTime:   1500   // inline key feedback (volume, brightness, ...) stays this long
    // full notch height while each panel is open (logical px); width = the resting notch
    readonly property var panelHeight: ({
        battery: 96, power: 130, usage: 360, media: 150, notifications: 220, system: 440, tailscale: 310, launcher: 460, bluetooth: 260, wifi: 260, volume: 270, clock: 300, clockA: 232
    })
    // ---- notifications (Notifications.qml) ----
    readonly property int notifWidth:   380     // card width
    readonly property int notifTimeout: 8000    // ms a new notification shows inline in the notch (the mouse on it keeps it)
    readonly property real glass:       0.82    // opacity of the translucent cards (blurred behind)

    readonly property int panelMaxHeight: 520   // tallest a panel may grow (Wi-Fi sign-in forms); sizes the bar window
    readonly property real notchFraction: 0.405  // notch width as a fraction of the screen width (user 2026-09-25: 10% narrower than 0.45)
    readonly property real islandRadius: Corners.notch   // the notch's bottom corners: Settings > Windows > Corners (default = the windows')

    // ---- fonts ----
    readonly property string font:    "Iosevka Nerd Font"
    readonly property string fontCjk: "Noto Sans CJK JP"
    readonly property int fontSize: 13
}

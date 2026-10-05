// Corners.qml -- singleton: corner radii in this shell's units (Hyprland px / the shell's own QT_SCALE_FACTOR).
//   win     the windows' visible outer curve = decoration:rounding + general:border_size (the border is drawn around
//           the rounded corner); 0 = square windows
//   r       rounded SCREEN corners: Prefs corners.screen px, or -1 = the same as the windows (default)
//   notch   the notch's corners, bottom AND the top ones where it meets the screen edge (Theme.islandRadius): Prefs corners.notch px, or -1 = the same as the windows;
//           at most half the slim notch (15)
// Set in Settings > Windows > Corners.
// Re-read at start, after a Hyprland reload, and on `qs ipc call corners refresh` (udiksa settings: rounding / border).
// Used by ScreenCorners.qml (the desktop) and ThemeSwitcher.qml; the lock / login screen and GRUB get the same
// radius in screen pixels from udiksa theme (theme.json "corner", GRUB corner images).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property real winPx: 0                                  // Hyprland px
    readonly property real win: winPx / factor
    readonly property var pref: Prefs.v.corners || ({ screen: -1, notch: -1 })
    readonly property real r: (pref.screen >= 0 ? pref.screen : winPx) / factor
    readonly property real notch: Math.min(15, (pref.notch >= 0 ? pref.notch : winPx) / factor)
    readonly property real factor: Number(Quickshell.env("QT_SCALE_FACTOR")) || 1

    function refresh() { reader.running = true }
    Process {
        id: reader
        running: true
        command: ["sh", "-c", "hyprctl getoption decoration:rounding -j; hyprctl getoption general:border_size -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = text.trim().split(/\n(?=\{)/).map(t => JSON.parse(t).int || 0)
                    root.winPx = v[0] > 0 ? v[0] + (v[1] || 0) : 0      // square windows -> square screen
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") root.refresh() }
    }
    IpcHandler {
        target: "corners"
        function refresh(): void { root.refresh() }
    }
}

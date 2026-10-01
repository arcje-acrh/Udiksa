// Corners.qml -- singleton: the radius of the rounded screen corners, in this shell's units. = the windows' visible
// outer curve = Hyprland decoration:rounding + general:border_size (the border is drawn around the rounded corner),
// divided by the shell's own QT_SCALE_FACTOR (rice-shell) so it matches Hyprland's pixels. 0 = square windows.
// Re-read at start, after a Hyprland reload, and on `qs ipc call corners refresh` (rice-settings: rounding / border).
// Used by ScreenCorners.qml (the desktop) and ThemeSwitcher.qml; the lock / login screen and GRUB get the same
// radius in screen pixels from rice-theme (theme.json "corner", GRUB corner images).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property real r: 0
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
                    root.r = v[0] > 0 ? (v[0] + (v[1] || 0)) / root.factor : 0      // square windows -> square screen
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

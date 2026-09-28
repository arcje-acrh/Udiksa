// WindowTitle.qml -- title of the focused window, elided.
// Some apps (e.g. the terminal running Claude Code) put a status symbol at the START of the title
// ("◑ name"). Such a lone leading symbol is moved to the END ("name ◑") -- user request.
import QtQuick
import Quickshell.Hyprland

Text {
    readonly property var win: Hyprland.activeToplevel
    readonly property string raw: win && win.title ? win.title : ""
    // lone symbol = one UTF-16 unit in U+2190..U+2BFF (arrows, geometric shapes, dingbats, braille) + space
    function moveSymbol(t) {
        if (t.length > 2 && t.charAt(1) === " ") {
            const c = t.charCodeAt(0)
            if (c >= 0x2190 && c <= 0x2BFF)
                return t.substring(2) + " " + t.charAt(0)
        }
        return t
    }
    text: moveSymbol(raw)
    color: Theme.muted
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    elide: Text.ElideRight
    maximumLineCount: 1
}

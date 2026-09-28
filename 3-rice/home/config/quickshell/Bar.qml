// Bar.qml -- one transparent full-width PanelWindow per screen holding the notch.
//   * exclusiveZone = Theme.stripHeight -> Hyprland tiles windows BELOW the notch strip
//   * mask = only the notch takes mouse input (it follows the notch as it grows); everything else is click-through
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "shell-bar"   // matched by the layer rule in hypr/conf/rules.lua
    // keyboard only while a panel is open (Wi-Fi password, Esc to close); never steals it otherwise
    // keyboard while a panel is open; the focus grab below hands it to the notch at once for panels
    // opened by click / key (launcher: type immediately). Exclusive focus conflicted with the grab
    // (it was cleared at once and closed the launcher), so it is not used.
    WlrLayershell.keyboardFocus: notch.panel !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.panelMaxHeight + 48   // tallest panel + room for its shadow (transparent + click-through)
    exclusiveZone: Theme.stripHeight
    color: "transparent"

    mask: Region { item: notch }

    // a panel opened by a click / key: clicking anywhere outside the notch closes it
    HyprlandFocusGrab {
        windows: [win]
        active: notch.panel !== "" && notch.clickOpened
        onCleared: notch.close()
    }

    Notch {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        // the design's share of the screen, but at least what its row needs (rotated / narrow screens) and never
        // wider than the screen; panels are capped at the screen too (maxWidth)
        maxWidth: Math.max(200, win.width - 2 * (notch.ear + 8))
        restWidth: Math.min(maxWidth, Math.max(Math.round(win.width * Theme.notchFraction), notch.minRestWidth))
    }
}

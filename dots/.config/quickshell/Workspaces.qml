// Workspaces.qml -- plain kanji numerals in the sans CJK font (the "old" look, user asked to revert). Hyprland keeps workspaces 1..10;
// this only maps the id to a numeral. Active = coral text (no pill), occupied = white, empty = grey.
import QtQuick
import Quickshell.Hyprland

Row {
    id: root
    spacing: 2
    readonly property var kanji: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    // ids that hold at least one window
    function occupied(id) {
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id && list[i].toplevels.values.length > 0) return true
        return false
    }
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    Repeater {
        model: 10
        delegate: Item {
            id: cell
            required property int index
            readonly property int wsId: index + 1
            readonly property bool isActive: root.activeId === wsId
            readonly property bool isOccupied: root.occupied(wsId)
            // show 1..5 always, plus any higher workspace that is active or occupied
            visible: wsId <= 5 || isActive || isOccupied
            width: visible ? 24 : 0
            height: 20

            Text {
                anchors.centerIn: parent
                text: root.kanji[cell.index]
                font.family: Theme.fontCjk
                font.bold: cell.isActive
                font.pixelSize: 14
                color: cell.isActive ? Theme.coral
                     : (hover.containsMouse ? Theme.amber : (cell.isOccupied ? Theme.text : Theme.dim))
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Quickshell wraps this string as `hl.dispatch(<string>)`, so it must be a Lua expression
                // (same form as ~/.config/hypr/conf/binds.lua); the old "workspace N" text is invalid Lua.
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.wsId + " })")
            }
        }
    }
}

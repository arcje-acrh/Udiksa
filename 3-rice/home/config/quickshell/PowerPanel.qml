// PowerPanel.qml -- power options inside the grown notch: wide buttons across the full width. Sleep = rice-idle
// (sleep, then hibernate later when Settings > Power says so); Hibernate shows only when it is set up.
// Lock = the Quickshell lock screen (Lock.qml). Log out / Reboot / Power off need a second
// click within 3 s (the button turns red and says "Confirm?"). done() closes the notch after an action.
// Second row: Keep awake and Game mode switches (Modes.qml), LED keys: the LED is lit while on.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    signal done()

    property string armed: ""       // id of the button waiting for its confirm click
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }
    property bool canHib: false
    Process {
        running: true
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector { onStreamFinished: root.canHib = text.indexOf('"yes"') >= 0 }
    }

    Row {
        id: row
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 22; anchors.rightMargin: 22
        anchors.top: parent.top; anchors.topMargin: 16
        spacing: 10
        // Hibernate shows only when it is set up (show only what works); the buttons share the row
        readonly property var buttons: [
                { id: "lock",     icon: "󰌾", name: "Lock",        confirm: false, enabled: true,  cmd: ["qs", "ipc", "call", "lock", "lock"] },
                { id: "logout",   icon: "󰍃", name: "Log out",     confirm: true,  enabled: true,  cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                { id: "suspend",  icon: "󰤄", name: "Sleep",       confirm: false, enabled: true,  cmd: [Quickshell.env("HOME") + "/.local/bin/rice-idle", "sleep", "any"] },
                { id: "hibernate", icon: "󰋊", name: "Hibernate",  confirm: false, enabled: root.canHib, cmd: ["systemctl", "hibernate"] },
                { id: "reboot",   icon: "󰜉", name: "Reboot",      confirm: true,  enabled: true,  cmd: ["systemctl", "reboot"] },
                { id: "poweroff", icon: "󰐥", name: "Power off",   confirm: true,  enabled: true,  cmd: ["systemctl", "poweroff"] }
            ].filter(b => b.enabled)
        readonly property real btnW: (width - (buttons.length - 1) * spacing) / buttons.length
        Repeater {
            model: row.buttons
            delegate: Rectangle {
                id: btn
                required property var modelData
                readonly property bool isArmed: root.armed === modelData.id
                readonly property color fg: !modelData.enabled ? Theme.dim
                                          : (isArmed || (hover.containsMouse && modelData.confirm) ? Theme.warn : Theme.text)
                width: row.btnW; height: 44; radius: 2
                color: !modelData.enabled ? "transparent"
                     : (isArmed ? Qt.alpha(Theme.warn, 0.18) : (hover.containsMouse ? Theme.raised : Theme.surface))
                border.width: 1
                border.color: !modelData.enabled ? Theme.raised : (isArmed ? Qt.alpha(Theme.warn, 0.6) : Theme.hover)
                Behavior on color { ColorAnimation { duration: 120 } }
                KeyEdge { visible: btn.modelData.enabled; pressed: btn.isArmed }

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.modelData.icon; color: btn.fg
                        font.family: Theme.font; font.pixelSize: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.isArmed ? "Confirm?" : btn.modelData.name; color: btn.fg
                        font.family: Theme.font; font.pixelSize: 12; font.bold: true
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: btn.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (btn.modelData.confirm && !btn.isArmed) {
                            root.armed = btn.modelData.id
                            disarm.restart()
                            return
                        }
                        root.armed = ""
                        root.done()
                        Quickshell.execDetached(btn.modelData.cmd)
                    }
                }
            }
        }
    }

    // ---------- switches: keep awake, game mode ----------
    Row {
        id: modesRow
        anchors.left: parent.left; anchors.leftMargin: 22
        anchors.top: row.bottom; anchors.topMargin: 10
        spacing: 10
        Repeater {
            model: [
                { id: "awake", icon: "󰅶", name: "Keep awake", on: Modes.awake, toggle: () => Modes.setAwake(!Modes.awake) },
                { id: "game",  icon: "󰊴", name: "Game mode",  on: Modes.game,  toggle: () => Modes.setGame(!Modes.game) }
            ]
            delegate: Rectangle {
                id: sw
                required property var modelData
                width: row.btnW; height: 44; radius: 2
                color: swHover.containsMouse ? Theme.raised : Theme.surface
                border.width: 1; border.color: modelData.on ? Qt.alpha(Theme.coral, 0.6) : Theme.hover
                Behavior on color { ColorAnimation { duration: 120 } }
                KeyEdge { pressed: sw.modelData.on }
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Rectangle {   // the LED
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 1
                        color: sw.modelData.on ? Theme.coral : Theme.raised
                        Rectangle { visible: sw.modelData.on; anchors.fill: parent; anchors.margins: -2; radius: 2; z: -1; color: Qt.alpha(Theme.coral, 0.3) }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sw.modelData.icon; color: sw.modelData.on ? Theme.coral : Theme.text
                        font.family: Theme.font; font.pixelSize: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sw.modelData.name; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 12; font.bold: true
                    }
                }
                MouseArea {
                    id: swHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sw.modelData.toggle()
                }
            }
        }
    }
    Text {
        anchors.left: modesRow.right; anchors.leftMargin: 16
        anchors.right: parent.right; anchors.rightMargin: 22
        anchors.verticalCenter: modesRow.verticalCenter
        wrapMode: Text.Wrap
        text: "Keep awake: no lock, screen off or sleep until you turn it off.  Game mode: animations, blur, shadows and gaps off."
        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
    }
}

// PowerPanel.qml -- power options inside the grown notch: six equal icon-only keys across the full width. Sleep = rice-idle
// (sleep, then hibernate later when Settings > Power says so); Hibernate shows only when it is set up.
// Lock = the Quickshell lock screen (Lock.qml). Log out / Reboot / Power off need a second
// click within 3 s (the button turns red and says "Confirm?"). done() closes the notch after an action.
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
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        readonly property real btnW: (width - (buttons.length - 1) * spacing) / buttons.length
        // Hibernate shows only when it is set up (show only what works); the buttons share the row
        readonly property var buttons: [
                { id: "lock",     icon: "󰌾", name: "Lock",        confirm: false, enabled: true,  cmd: ["qs", "ipc", "call", "lock", "lock"] },
                { id: "logout",   icon: "󰍃", name: "Log out",     confirm: true,  enabled: true,  cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                { id: "suspend",  icon: "󰤄", name: "Sleep",       confirm: false, enabled: true,  cmd: [Quickshell.env("HOME") + "/.local/bin/rice-idle", "sleep", "any"] },
                { id: "hibernate", icon: "󰋊", name: "Hibernate",  confirm: false, enabled: root.canHib, cmd: ["systemctl", "hibernate"] },
                { id: "reboot",   icon: "󰜉", name: "Reboot",      confirm: true,  enabled: true,  cmd: ["systemctl", "reboot"] },
                { id: "poweroff", icon: "󰐥", name: "Power off",   confirm: true,  enabled: true,  cmd: ["systemctl", "poweroff"] }
            ].filter(b => b.enabled)
        Repeater {
            model: row.buttons
            delegate: Rectangle {
                id: btn
                required property var modelData
                readonly property bool isArmed: root.armed === modelData.id
                readonly property color fg: !modelData.enabled ? Theme.dim
                                          : (isArmed || (hover.containsMouse && modelData.confirm) ? Theme.warn : Theme.text)
                width: row.btnW; height: 44; radius: 4
                color: !modelData.enabled ? "transparent"
                     : (isArmed ? Qt.alpha(Theme.warn, 0.18) : (hover.containsMouse ? Theme.raised : Theme.surface))
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {   // icon only; the armed key says "Confirm?" instead
                    anchors.centerIn: parent
                    text: btn.isArmed ? "Confirm?" : btn.modelData.icon; color: btn.fg
                    font.family: Theme.font; font.pixelSize: btn.isArmed ? 12 : 22; font.bold: btn.isArmed
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
}

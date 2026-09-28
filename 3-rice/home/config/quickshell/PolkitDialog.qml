// PolkitDialog.qml -- the password prompt when an app needs administrator rights (polkit agent;
// replaces hyprpolkitagent). A translucent card appears in the centre of the screen and
// takes the keyboard while it is open: type the password, Enter = authenticate, Esc = cancel.
// A wrong password shows the error and lets you try again.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

Scope {
    id: root
    PolkitAgent {
        id: agent
        onIsRegisteredChanged: console.info("polkit agent registered:", isRegistered)
    }
    readonly property var flow: agent.flow

    PanelWindow {
        visible: agent.isActive && root.flow !== null
        WlrLayershell.namespace: "shell-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusiveZone: 0                   // no anchors = centred on the screen
        implicitWidth: 460 + 48
        implicitHeight: card.height + 48
        color: "transparent"
        onVisibleChanged: if (visible) { pw.text = ""; pw.focusIt() }

        RectangularShadow {
            anchors.fill: card; radius: card.radius
            blur: 30; offset: Qt.vector2d(0, 8)
            color: Qt.alpha(Theme.shadow, 0.5)
        }
        Rectangle {
            id: card
            x: 24; y: 12
            width: 460
            height: col.height + 36
            radius: 18
            color: Qt.alpha(Theme.bg, Theme.glass)
            border.width: 1; border.color: Qt.alpha(Theme.coral, 0.45)

            Column {
                id: col
                x: 20; y: 18
                width: parent.width - 40
                spacing: 12

                Row {
                    spacing: 12
                    Text { text: "󰌾"; color: Theme.coral; font.family: Theme.font; font.pixelSize: 26 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Authentication required"; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 15; font.bold: true
                    }
                }
                Text {
                    width: parent.width
                    text: root.flow ? root.flow.message : ""
                    wrapMode: Text.Wrap
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 12
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    wrapMode: Text.Wrap
                    color: root.flow && root.flow.supplementaryIsError ? Theme.warn : Theme.amber
                    font.family: Theme.font; font.pixelSize: 12
                }
                Field {
                    id: pw
                    width: parent.width
                    label: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                    password: !(root.flow && root.flow.responseVisible)
                    onAccepted: root.submit()
                    Keys.onEscapePressed: root.cancel()
                }
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    Rectangle {
                        width: 100; height: 34; radius: 10
                        color: cm.containsMouse ? Theme.hover : Theme.raised
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                    }
                    Rectangle {
                        width: 140; height: 34; radius: 10
                        color: om.containsMouse ? Theme.amber : Theme.coral
                        Text { anchors.centerIn: parent; text: "Authenticate"; color: Theme.bg; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                    }
                }
            }
        }
    }

    function submit() { if (root.flow && root.flow.isResponseRequired) { root.flow.submit(pw.text); pw.text = "" } }
    function cancel() { if (root.flow) root.flow.cancelAuthenticationRequest() }
}

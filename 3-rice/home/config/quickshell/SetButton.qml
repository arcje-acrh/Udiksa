// SetButton.qml -- a retro key button for Settings (square, bevelled). `accent` = the main action,
// `warn` = something to think twice about (it turns into "Confirm?" and needs a second click within 3 s).
import QtQuick

Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool accent: false
    property bool warn: false
    property bool enabled: true
    property bool armed: false
    signal clicked()
    width: row.implicitWidth + 28; height: 32; radius: 2
    opacity: enabled ? 1 : 0.45
    color: armed ? Qt.alpha(Theme.warn, 0.2) : accent ? (m.containsMouse ? Theme.amber : Theme.coral) : (m.pressed ? Theme.bg : m.containsMouse ? Theme.hover : Theme.raised)
    border.width: accent ? 0 : 1
    border.color: armed ? Theme.warn : Theme.hover
    KeyEdge { visible: !root.accent; pressed: m.pressed }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text { visible: root.icon !== ""; text: root.icon; color: root.accent ? Theme.bg : (root.armed || root.warn ? Theme.warn : Theme.text); font.family: Theme.font; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.armed ? "Confirm?" : root.text; color: root.accent ? Theme.bg : (root.armed || root.warn ? Theme.warn : Theme.text); font.family: Theme.font; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
    }
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }
    MouseArea {
        id: m; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.warn && !root.armed) { root.armed = true; disarm.restart(); return }
            root.armed = false
            root.clicked()
        }
    }
}

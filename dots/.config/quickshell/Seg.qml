// Seg.qml -- a row of retro hardware keys (user pick 2026-09-26, style D), one selected.
// Each key: small LED + label on a flat square key; the chosen one is dark with a
// lit accent LED. `options` = labels, `current` = index, picked(i) when one is clicked (the owner applies
// the change and updates `current`). `queued` = index of a choice that takes effect later (amber LED +
// amber label), e.g. a GPU mode after reboot.
import QtQuick

Row {
    id: root
    property var options: []
    property int current: -1
    property int queued: -1
    signal picked(int index)
    spacing: 4
    Repeater {
        model: root.options
        delegate: Rectangle {
            required property int index
            required property var modelData
            readonly property bool on: root.current === index
            readonly property bool later: root.queued === index && !on
            width: label.implicitWidth + 28; height: 30; radius: 2
            color: on ? Theme.bg : (ma.containsMouse ? Theme.hover : Theme.raised)
            Rectangle {   // LED
                id: led
                x: 8; anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5; radius: 2.5
                color: parent.on ? Theme.text : (parent.later ? Theme.amber : Theme.dim)
                Rectangle {   // glow
                    visible: parent.parent.on || parent.parent.later
                    anchors.centerIn: parent; width: 11; height: 11; radius: 5.5; z: -1
                    color: Qt.alpha(parent.color, 0.3)
                }
            }
            Text {
                id: label
                x: 18; anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: parent.on ? Theme.text : (parent.later ? Theme.amber : Theme.muted)
                font.family: Theme.font; font.pixelSize: 12; font.bold: true
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(index) }
        }
    }
}

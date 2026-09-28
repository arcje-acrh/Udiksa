// Check.qml -- a labelled checkbox in the retro hardware style (user pick 2026-09-26, style D): a small
// square key with an LED that lights in the accent when on. toggled() on click; the owner flips the setting.
import QtQuick

Rectangle {
    id: root
    property string label: ""
    property bool checked: false
    signal toggled()
    height: 30; radius: 4
    color: ma.containsMouse ? Theme.raised : "transparent"
    Row {
        x: 10; anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 2
            color: Theme.bg
            border.width: 1; border.color: Theme.dim
            Rectangle {
                anchors.centerIn: parent; width: 6; height: 6; radius: 1
                color: root.checked ? Theme.coral : Theme.raised
                Rectangle { visible: root.checked; anchors.centerIn: parent; width: 12; height: 12; radius: 3; z: -1; color: Qt.alpha(Theme.coral, 0.3) }
            }
        }
        Text { text: root.label; color: root.checked ? Theme.text : Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}

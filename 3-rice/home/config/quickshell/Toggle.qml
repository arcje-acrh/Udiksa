// Toggle.qml -- a labelled on/off switch row. toggled() on click; the owner flips the real setting.
import QtQuick

Rectangle {
    id: root
    property string label: ""
    property bool checked: false
    property bool busy: false
    signal toggled()
    height: 40; radius: 10
    color: ma.containsMouse ? Theme.raised : Theme.surface
    Text {
        anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
        text: root.label; color: Theme.text
        font.family: Theme.font; font.pixelSize: 13
    }
    Rectangle {   // switch: classy hairline style (user pick 2026-09-26, style C): square corners, square knob
        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 14; radius: 2
        color: root.checked ? Qt.alpha(Theme.coral, 0.18) : "transparent"
        border.width: 1; border.color: root.checked ? Theme.coral : Theme.dim
        opacity: root.busy ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 12; height: 10; radius: 1; y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? Theme.coral : Theme.dim
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}

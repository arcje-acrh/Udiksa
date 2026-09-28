// SetGroup.qml -- a small caps heading that starts a group of rows in a Settings section,
// with an optional action on the right (e.g. "reset").
import QtQuick

Item {
    id: root
    property string title: ""
    property string action: ""
    signal actionClicked()
    width: parent ? parent.width : 600
    height: 46
    Text {
        anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 8 }
        text: root.title.toUpperCase(); color: Theme.coral
        font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
    }
    Text {
        visible: root.action !== ""
        anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
        text: root.action; color: am.containsMouse ? Theme.text : Theme.muted
        font.family: Theme.font; font.pixelSize: 11; font.bold: true
        MouseArea { id: am; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.actionClicked() }
    }
}

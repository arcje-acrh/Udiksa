// PanelTitle.qml -- small header line in a panel card: bold title left, optional note/action right.
import QtQuick

Item {
    id: root
    property string title: ""
    property string action: ""      // e.g. "scan ↻" (clickable when set)
    property bool busy: false
    signal actionClicked()
    width: parent ? parent.width : 0
    height: 22
    Text {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        text: root.title.toUpperCase(); color: Theme.text
        font.family: Theme.font; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
    }
    Text {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: root.action; color: root.busy ? Theme.coral : (ma.containsMouse ? Theme.amber : Theme.muted)
        font.family: Theme.font; font.pixelSize: 11
        MouseArea { id: ma; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.actionClicked() }
    }
}

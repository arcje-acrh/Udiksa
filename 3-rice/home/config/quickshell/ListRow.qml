// ListRow.qml -- one clickable line in a panel list: optional icon (device / OS logo), title on the
// left, small note on the right, optional status glyphs (e.g. 󰌾 + signal), and an optional small action
// icon at the far right (e.g. 󰒓 = settings) with actionClicked().
import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string note: ""
    property string glyphs: ""
    property string actionIcon: ""
    property bool active: false
    property bool dim: false
    signal clicked()
    signal actionClicked()
    width: parent ? parent.width : 0
    height: 32; radius: 9
    color: ma.containsMouse || act.containsMouse ? Theme.raised : "transparent"
    Text {
        id: iconText
        visible: root.icon !== ""
        anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
        width: 18
        text: root.icon
        color: root.active ? Theme.coral : (root.dim ? Theme.dim : Theme.muted)
        font.family: Theme.font; font.pixelSize: 15
    }
    Text {
        anchors.left: iconText.visible ? iconText.right : parent.left
        anchors.leftMargin: iconText.visible ? 8 : 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: noteText.left; anchors.rightMargin: 10
        text: root.title; elide: Text.ElideRight
        color: root.active ? Theme.coral : (root.dim ? Theme.muted : Theme.text)
        font.family: Theme.font; font.pixelSize: 13
    }
    Text {
        id: noteText
        anchors.right: glyphText.visible ? glyphText.left : (actText.visible ? actText.left : parent.right)
        anchors.rightMargin: glyphText.visible ? 8 : 10; anchors.verticalCenter: parent.verticalCenter
        text: root.note; color: Theme.muted
        font.family: Theme.font; font.pixelSize: 11
    }
    Text {
        id: glyphText
        visible: root.glyphs !== ""
        anchors.right: actText.visible ? actText.left : parent.right
        anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
        text: root.glyphs; color: Theme.muted
        font.family: Theme.font; font.pixelSize: 13
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Text {
        id: actText
        visible: root.actionIcon !== ""
        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
        text: root.actionIcon
        color: act.containsMouse ? Theme.coral : Theme.muted
        font.family: Theme.font; font.pixelSize: 14
        MouseArea { id: act; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.actionClicked() }
    }
}

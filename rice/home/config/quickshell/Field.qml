// Field.qml -- a labelled one-line text box for panel forms.
//   password: true = hidden text with a show/hide eye;  browse: true = a "Browse…" button (browseClicked())
//   accepted() on Enter.
import QtQuick

Item {
    id: root
    property string label: ""
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool browse: false
    property bool reveal: false
    signal accepted()
    signal browseClicked()
    function focusIt() { input.forceActiveFocus() }
    width: parent ? parent.width : 200
    height: 32

    Text {
        id: lab
        width: 150; anchors.verticalCenter: parent.verticalCenter
        text: root.label; elide: Text.ElideRight
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    Rectangle {
        id: box
        anchors.left: lab.right; anchors.right: browseBtn.visible ? browseBtn.left : parent.right
        anchors.rightMargin: browseBtn.visible ? 8 : 0
        height: parent.height; radius: 9
        color: Theme.raised
        border.width: 1; border.color: input.activeFocus ? Theme.coral : "transparent"
        TextInput {
            id: input
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: root.password ? 34 : 10
            verticalAlignment: TextInput.AlignVCenter
            echoMode: root.password && !root.reveal ? TextInput.Password : TextInput.Normal
            clip: true; selectByMouse: true
            color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4)
            font.family: Theme.font; font.pixelSize: 13
            Keys.onReturnPressed: root.accepted()
            Keys.onEnterPressed: root.accepted()
            Text {
                visible: !input.text && !input.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; elide: Text.ElideRight
                text: root.placeholder; color: Theme.dim; font: input.font
            }
        }
        Text {   // show / hide password
            visible: root.password
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            text: root.reveal ? "󰈉" : "󰈈"
            color: eye.containsMouse ? Theme.coral : Theme.muted
            font.family: Theme.font; font.pixelSize: 15
            MouseArea { id: eye; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.reveal = !root.reveal }
        }
    }
    Rectangle {
        id: browseBtn
        visible: root.browse
        anchors.right: parent.right
        width: 80; height: parent.height; radius: 9
        color: bm.containsMouse ? Theme.hover : Theme.raised
        Text { anchors.centerIn: parent; text: "Browse…"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.browseClicked() }
    }
}

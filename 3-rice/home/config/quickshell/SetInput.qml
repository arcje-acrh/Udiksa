// SetInput.qml -- a plain one-line text box for Settings (no label column, unlike Field.qml). accepted() on Enter.
import QtQuick

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    signal accepted()
    function focusIt() { input.forceActiveFocus() }
    width: 240; height: 32; radius: 2
    clip: true
    color: Theme.bg
    border.width: 1; border.color: input.activeFocus ? Theme.coral : Theme.hover
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true; selectByMouse: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4)
        font.family: Theme.font; font.pixelSize: 13
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
    }
    Text {
        anchors { fill: parent; leftMargin: 10 }
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.activeFocus
        text: root.placeholder; color: Theme.dim
        elide: Text.ElideRight
        anchors.rightMargin: 10
        font.family: Theme.font; font.pixelSize: 13
    }
}

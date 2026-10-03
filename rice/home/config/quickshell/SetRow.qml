// SetRow.qml -- one line of the Settings app: title + short description on the left, the control on the right.
// Put the control inside:  SetRow { title: "Gaps"; desc: "space between windows"; Seg { ... } }
import QtQuick

Item {
    id: root
    property string title: ""
    property string desc: ""
    default property alias control: slot.data
    width: parent ? parent.width : 600
    height: Math.max(52, txt.implicitHeight + 18, slot.childrenRect.height + 14)

    Column {
        id: txt
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; right: slot.left; rightMargin: 24 }
        spacing: 3
        Text { text: root.title; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
        Text {
            visible: root.desc !== ""
            width: parent.width
            text: root.desc; color: Theme.muted; wrapMode: Text.WordWrap
            font.family: Theme.font; font.pixelSize: 12
        }
    }
    Item {
        id: slot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.raised; opacity: 0.6 }
}

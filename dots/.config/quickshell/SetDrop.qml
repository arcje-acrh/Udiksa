// SetDrop.qml -- a drop-down for Settings: a key showing the current choice; click it and the list opens right under it
// (the row grows with it), type to filter, click a choice. With `fontFace` every name is drawn in its own typeface.
//   SetDrop { options: [{ name: "Inter", tag: "sans" }, ...]; current: "Inter"; onPicked: (n) => ...; onOpened: refresh() }
import QtQuick

Item {
    id: root
    property var options: []            // [{ name, tag }]
    property string current: ""
    property bool fontFace: false
    property int boxWidth: 360
    property int listHeight: 300
    property bool open: false
    property string filter: ""
    signal picked(string name)
    signal opened()
    readonly property var shown: options.filter(o => o.name.toLowerCase().indexOf(filter.toLowerCase()) >= 0)
    width: boxWidth
    height: 32 + (open ? 6 + 34 + 4 + listHeight : 0)

    Rectangle {   // the key: the current choice + a chevron
        width: root.boxWidth; height: 32; radius: 2
        color: hm.pressed ? Theme.bg : (hm.containsMouse || root.open ? Theme.hover : Theme.raised)
        Text {
            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight
            text: root.current || "—"; color: Theme.text; font.family: root.fontFace && root.current ? root.current : Theme.font; font.pixelSize: 14; font.bold: true
        }
        Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: root.open ? "󰅃" : "󰅀"; color: Theme.muted; font.family: Theme.mono; font.pixelSize: 14 }
        MouseArea {
            id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.open = !root.open; root.filter = ""; if (root.open) { root.opened(); find.forceActiveFocus() } }
        }
    }
    Column {
        visible: root.open
        y: 38; spacing: 4; width: root.boxWidth
        Rectangle {   // type to filter
            width: parent.width; height: 34; radius: 2; color: Theme.surface
            TextInput {
                id: find
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter; clip: true
                color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4); font.family: Theme.font; font.pixelSize: 13
                text: root.filter; onTextChanged: root.filter = text
                Keys.onEscapePressed: root.open = false
                Text { visible: find.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "type to filter  ·  " + root.options.length + " installed"; color: Theme.dim; font: find.font }
            }
        }
        ScrollList {
            width: parent.width; height: root.listHeight
            spacing: 2
            model: root.shown
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.name === root.current
                width: ListView.view.width - ListView.view.rightMargin; height: 32; radius: 2
                color: on ? Theme.bg : (im.containsMouse ? Theme.hover : Theme.raised)
                Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: parent.on ? Theme.coral : Theme.dim }
                Text {
                    x: 26; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; elide: Text.ElideRight
                    text: modelData.name; color: parent.on ? Theme.text : Theme.muted
                    font.family: root.fontFace ? modelData.name : Theme.font; font.pixelSize: 14; font.bold: parent.on
                }
                Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: modelData.tag || ""; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
                MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.open = false; root.picked(modelData.name) } }
            }
        }
    }
}

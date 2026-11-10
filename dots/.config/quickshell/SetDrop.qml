// SetDrop.qml -- a drop-down for Settings: a key showing the current choice; click it and a scrollable list FLOATS over
// the page (Settings' "dropLayer"; the row never grows), under the key or above it when there is no room below. Click a
// choice, click outside or press Esc to close. Long lists get a type-to-filter box. `fontFace`: each name in its own font.
//   SetDrop { options: [{ name: "Inter", tag: "sans" }, ...]; current: "Inter"; onPicked: (n) => ...; onOpened: refresh() }
import QtQuick

Item {
    id: root
    property var options: []            // [{ name, tag }]
    property string current: ""
    property bool fontFace: false
    property int boxWidth: 360
    property int listHeight: 300        // the most the list shows before it scrolls
    property bool filterable: options.length > 12
    property bool open: false
    property string filter: ""
    signal picked(string name)
    signal opened()
    readonly property var shown: options.filter(o => o.name.toLowerCase().indexOf(filter.toLowerCase()) >= 0)
    width: boxWidth; height: 32

    // the window's top layer (Settings.qml), else the window itself
    function topLayer() {
        let p = root.parent, top = root
        while (p) { if (p.objectName === "dropLayer") return p; for (const c of p.children) if (c.objectName === "dropLayer") return c; top = p; p = p.parent }
        return top
    }
    function toggle() {
        if (open) { open = false; return }
        filter = ""; opened()
        const l = topLayer(), pt = root.mapToItem(l, 0, 0), h = pop.implicitHeight
        pop.parent = l
        pop.x = Math.min(pt.x, l.width - boxWidth)
        pop.y = pt.y + 38 + h <= l.height ? pt.y + 38 : Math.max(0, pt.y - 6 - h)   // below, or above when no room
        open = true
        if (filterable) find.forceActiveFocus()
    }

    Rectangle {   // the key: the current choice + a chevron
        width: root.boxWidth; height: 32; radius: 2
        color: hm.pressed ? Theme.bg : (hm.containsMouse || root.open ? Theme.hover : Theme.raised)
        Text {
            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight
            text: root.current || "—"; color: Theme.text; font.family: root.fontFace && root.current ? root.current : Theme.font; font.pixelSize: 14; font.bold: true
        }
        Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: root.open ? "󰅃" : "󰅀"; color: Theme.muted; font.family: Theme.mono; font.pixelSize: 14 }
        MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle() }
    }

    Item {   // the floating list (moved onto the layer while open)
        id: pop
        visible: root.open
        implicitHeight: (root.filterable ? 34 + 4 : 0) + list.height + 8
        width: root.boxWidth; height: implicitHeight
        // a click anywhere outside closes it; the page underneath does not scroll meanwhile
        MouseArea {
            parent: pop.parent; anchors.fill: parent; visible: root.open; z: -1
            onClicked: root.open = false; onWheel: (w) => w.accepted = true
        }
        Rectangle { anchors.fill: parent; radius: 2; color: Theme.surface; border.width: 1; border.color: Theme.raised }
        Column {
            x: 4; y: 4; width: parent.width - 8; spacing: 4
            Rectangle {   // type to filter
                visible: root.filterable
                width: parent.width; height: 34; radius: 2; color: Theme.bg
                TextInput {
                    id: find
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter; clip: true
                    color: Theme.text; selectionColor: Qt.alpha(Theme.coral, 0.4); font.family: Theme.font; font.pixelSize: 13
                    text: root.filter; onTextChanged: root.filter = text
                    Keys.onEscapePressed: root.open = false
                    Text { visible: find.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "type to filter  ·  " + root.options.length; color: Theme.dim; font: find.font }
                }
            }
            ScrollList {
                id: list
                width: parent.width; height: Math.min(root.listHeight, root.shown.length * 34)
                spacing: 2
                model: root.shown
                Keys.onEscapePressed: root.open = false
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData.name === root.current
                    width: ListView.view.width - ListView.view.rightMargin; height: 32; radius: 2
                    color: on ? Theme.bg : (im.containsMouse ? Theme.hover : Theme.raised)
                    Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: parent.on ? Theme.coral : Theme.dim }
                    Text {
                        x: 26; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; elide: Text.ElideRight
                        text: modelData.name; color: parent.on ? Theme.text : Theme.muted
                        font.family: root.fontFace ? modelData.name : Theme.font; font.pixelSize: 14; font.bold: parent.on
                    }
                    Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: modelData.tag || ""; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
                    MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.open = false; root.picked(modelData.name) } }
                }
            }
        }
    }
}

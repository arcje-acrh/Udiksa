// IconKey.qml -- an icon-only key (same retro bevel as Seg.qml): one glyph, its name appears on hover.
// on = pressed in (the page you are on, or a switch that is on), led = a small lit LED in the corner while on,
// hot = amber/coral LED while something runs (e.g. recording), dot = a tiny "opens a submenu" mark in the corner.
import QtQuick

Rectangle {
    id: root
    property string glyph: ""
    property string tip: ""
    property bool on: false
    property bool led: false
    property bool hot: false
    property bool menu: false
    property string label: ""          // a small name under the icon (big tiles)
    property int glyphSize: 16
    signal clicked()
    width: 34; height: 30; radius: 2
    color: on ? Theme.bg : (ma.containsMouse ? Theme.hover : Theme.raised)
    border.width: 1; border.color: on ? Theme.dim : Theme.hover
    KeyEdge { pressed: root.on }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: root.label !== "" ? -8 : 0
        text: root.glyph
        color: root.hot ? Theme.coral : (root.on ? Theme.text : Theme.muted)
        font.family: Theme.font; font.pixelSize: root.glyphSize
    }
    Text {
        visible: root.label !== ""
        anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 22
        text: root.label; color: root.on ? Theme.text : Theme.muted; font.family: Theme.font; font.pixelSize: 10
    }
    Rectangle {   // LED (switches)
        visible: root.led || root.hot
        x: parent.width - 8; y: 4; width: 4; height: 4; radius: 2
        color: (root.on || root.hot) ? Theme.coral : Theme.dim
    }
    Text {   // submenu mark
        visible: root.menu
        x: parent.width - 11; y: 4
        text: "▾"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 9
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Timer { id: wait; interval: 350; running: ma.containsMouse && root.tip !== "" }
    Rectangle {   // the name, under the key
        visible: ma.containsMouse && !wait.running && root.tip !== ""
        z: 20
        x: (root.width - width) / 2; y: root.height + 4
        width: tipText.implicitWidth + 14; height: 20; radius: 2
        color: Theme.surface; border.width: 1; border.color: Theme.hover
        Text { id: tipText; anchors.centerIn: parent; text: root.tip; color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
    }
}

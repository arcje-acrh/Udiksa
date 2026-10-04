// IconKey.qml -- a small flat key with one glyph or short word (the clock pages' presets, steppers and add buttons).
// on = a soft accent fill and an accent glyph (the chosen one).
import QtQuick

Rectangle {
    id: root
    property string glyph: ""
    property bool on: false
    property int glyphSize: 16
    signal clicked()
    width: 34; height: 30; radius: 8
    color: on ? Qt.alpha(Theme.coral, 0.22) : (ma.containsMouse ? Theme.hover : Theme.raised)
    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.on ? Theme.coral : (ma.containsMouse ? Theme.text : Theme.muted)
        font.family: Theme.font; font.pixelSize: root.glyphSize
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}

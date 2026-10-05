// IconKey.qml -- a key with one glyph or a short word (the clock pages' presets, steppers and add buttons).
// Same gapped-key look as Seg.qml: 30 px high, square corners, flat, no border. A lone glyph = a 30x30
// square; a word = as wide as its text. on = a soft accent fill and an accent label (the chosen one).
import QtQuick

Rectangle {
    id: root
    property string glyph: ""
    property bool on: false
    property int glyphSize: 16
    signal clicked()
    width: txt.implicitWidth < 24 ? height : txt.implicitWidth + 28
    height: 30; radius: 2
    color: on ? Qt.alpha(Theme.coral, 0.22) : (ma.containsMouse ? Theme.hover : Theme.raised)
    Text {
        id: txt
        anchors.centerIn: parent
        text: root.glyph
        color: root.on ? Theme.coral : (ma.containsMouse ? Theme.text : Theme.muted)
        font.family: Theme.font; font.pixelSize: root.glyphSize; font.bold: root.glyphSize < 16
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}

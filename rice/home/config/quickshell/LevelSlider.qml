// LevelSlider.qml -- "label [LED segments] 35%" (retro style D): drag or scroll to change. value is 0..1;
// moved(v) fires while dragging/scrolling (the owner applies it). Icon click = iconClicked() (e.g. mute).
import QtQuick

Item {
    id: root
    property string label: ""
    property real value: 0
    property real max: 1.0                 // e.g. 1.25 for volume up to 125 %
    property real safe: 1.0                // above this the track is tinted amber (easy to see, hard to do by mistake)
    readonly property real frac: Math.max(0, Math.min(1, value / max))
    readonly property real safeFrac: Math.min(1, safe / max)
    property bool off: false
    property string valueText: Math.round(value * 100) + "%"
    signal moved(real v)
    signal labelClicked()
    height: 28

    Text {
        id: lab
        width: root.label !== "" ? 100 : 0; anchors.verticalCenter: parent.verticalCenter
        text: root.label; elide: Text.ElideRight
        color: root.off ? Theme.dim : Theme.muted
        font.family: Theme.font; font.pixelSize: 12
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.labelClicked() }
    }
    Item {
        id: track
        anchors.left: lab.right; anchors.leftMargin: root.label !== "" ? 8 : 0
        anchors.right: val.left; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 20
        LedBar {   // retro LED segments (style D); amber above `safe`
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            frac: root.frac
            safeFrac: root.safeFrac
            off: root.off
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function set(x) { root.moved(root.max * Math.max(0, Math.min(1, x / width))) }
            onPressed: (m) => set(m.x)
            onPositionChanged: (m) => { if (pressed) set(m.x) }
            onWheel: (w) => root.moved(Math.max(0, Math.min(root.max, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Text {
        id: val
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 48; horizontalAlignment: Text.AlignRight
        text: root.valueText
        color: root.off ? Theme.dim : Theme.text
        font.family: Theme.font; font.pixelSize: 12; font.bold: true
    }
}

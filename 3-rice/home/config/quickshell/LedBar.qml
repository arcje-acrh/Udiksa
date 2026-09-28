// LedBar.qml -- the retro "hardware" level bar: a row of small LED segments (user pick 2026-09-26, style D).
// Lit segments glow in the accent; the part above `safe` (e.g. volume > 100 %) is amber, dimly lit even when
// off so the extra range is visible; `off` (muted) = lit segments grey. `mark` = one segment in muted colour
// (e.g. the battery charge limit). Width decides the segment count (4 px segment + 2 px gap).
import QtQuick

Row {
    id: root
    property real frac: 0            // 0..1 of the whole bar
    property real safeFrac: 1        // above this = amber range
    property bool off: false
    property real mark: -1           // 0..1 position of a marker segment (-1 = none)
    property int segH: 16
    spacing: 2
    height: segH
    readonly property int segs: Math.max(1, Math.floor((width + spacing) / 6))
    Repeater {
        model: root.segs
        delegate: Rectangle {
            required property int index
            readonly property real at: (index + 0.5) / root.segs
            readonly property bool lit: at <= root.frac
            readonly property bool extra: at > root.safeFrac
            readonly property bool marked: root.mark >= 0 && Math.abs(at - root.mark) < 0.5 / root.segs
            width: 4; height: root.segH; radius: 1
            color: lit ? (root.off ? Theme.dim : (extra ? Theme.amber : Theme.coral))
                 : (marked ? Theme.muted : (extra ? Qt.alpha(Theme.amber, 0.14) : Theme.raised))
            Rectangle {   // soft glow around lit segments
                visible: parent.lit && !root.off
                anchors.fill: parent; anchors.margins: -2
                radius: 2; z: -1
                color: Qt.alpha(parent.color, 0.25)
            }
        }
    }
}

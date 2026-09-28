// SetNum.qml -- a number setting as retro hardware: [−] LED bar [+] and the value. Click / drag on the bar
// or use the keys; `changed(v)` fires on every step (Settings applies it at once).
import QtQuick

Row {
    id: root
    property real value: 0
    property real from: 0
    property real to: 10
    property real step: 1
    property string unit: ""
    property int decimals: 0
    property int barWidth: 180
    property var labels: []                // optional: value = index, shown as labels[value] (e.g. timer stops)
    signal changed(real v)
    spacing: 8

    function set(v) {
        v = Math.max(from, Math.min(to, Math.round(v / step) * step))
        v = Number(v.toFixed(Math.max(decimals, 0) + 2))
        if (v !== value) changed(v)          // the owner updates `value` (so it stays bound to the live value)
    }

    Repeater {
        model: [{ t: "−", d: -1 }]
        delegate: key
    }
    Item {
        width: root.barWidth; height: 26
        anchors.verticalCenter: parent.verticalCenter
        LedBar {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; segH: 14
            frac: (root.value - root.from) / Math.max(0.0001, root.to - root.from)
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function at(x) { root.set(root.from + Math.max(0, Math.min(1, x / width)) * (root.to - root.from)) }
            onPressed: (m) => at(m.x)
            onPositionChanged: (m) => { if (pressed) at(m.x) }
            onWheel: (w) => root.set(root.value + (w.angleDelta.y > 0 ? root.step : -root.step))
        }
    }
    Repeater {
        model: [{ t: "+", d: 1 }]
        delegate: key
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        text: root.labels.length ? (root.labels[Math.round(root.value)] ?? "") : root.value.toFixed(root.decimals) + root.unit
        color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true
        horizontalAlignment: Text.AlignRight
    }

    Component {
        id: key
        Rectangle {
            required property var modelData
            width: 26; height: 26; radius: 2
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            color: km.pressed ? Theme.bg : (km.containsMouse ? Theme.hover : Theme.raised)
            border.width: 1; border.color: Theme.hover
            KeyEdge { pressed: km.pressed }
            Text { anchors.centerIn: parent; text: modelData.t; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
            MouseArea {
                id: km; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.set(root.value + modelData.d * root.step)
                onPressAndHold: rep.start()
                onReleased: rep.stop()
            }
            Timer { id: rep; interval: 90; repeat: true; onTriggered: root.set(root.value + modelData.d * root.step) }
        }
    }
}

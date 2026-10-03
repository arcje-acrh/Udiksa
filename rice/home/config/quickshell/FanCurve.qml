// FanCurve.qml -- fan curve editor for the System panel: 8 points, temperature (x) and fan speed % (y).
// Drag a point in any direction: sideways = the temperature where that step starts (kept in order,
// 20-100 °C, at least 1 ° apart), up/down = speed. The curve stays rising left to right and never goes
// below the safety floor (red area, Power.floorPct). edited(temps, pcts) fires when you let go.
import QtQuick

Item {
    id: root
    property var temps: []                 // 8 temperatures (°C)
    property var pcts: []                  // 8 speeds (%)
    property bool custom: false            // false = firmware default (drawn dimmer)
    signal edited(var temps, var pcts)

    property var work: pcts                // speeds while dragging
    property var workT: temps              // temperatures while dragging
    onPctsChanged: work = pcts
    onTempsChanged: workT = temps.map(t => Math.max(tMin, Math.min(tMax, t)))
    readonly property real tMin: 20
    readonly property real tMax: 100
    function xOf(t) { return plot.width * (Math.max(tMin, Math.min(tMax, t)) - tMin) / (tMax - tMin) }
    function yOf(p) { return plot.height * (1 - p / 100) }

    Item {
        id: plot
        anchors.fill: parent
        anchors.leftMargin: 30; anchors.bottomMargin: 18; anchors.topMargin: 6; anchors.rightMargin: 8

        Canvas {
            id: cv
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d"); g.reset()
                // grid + labels are Text items below; here: floor area, grid lines, curve
                g.strokeStyle = Qt.alpha(Theme.text, 0.08); g.lineWidth = 1
                for (let p = 0; p <= 100; p += 25) { g.beginPath(); g.moveTo(0, root.yOf(p)); g.lineTo(width, root.yOf(p)); g.stroke() }
                // safety floor
                g.fillStyle = Qt.alpha(Theme.warn, 0.16)
                g.beginPath(); g.moveTo(0, height)
                for (let t = root.tMin; t <= root.tMax; t += 1) g.lineTo(root.xOf(t), root.yOf(Power.floorPct(t)))
                g.lineTo(width, height); g.closePath(); g.fill()
                // curve
                if (!root.work || root.work.length === 0) return
                g.strokeStyle = root.custom ? Theme.coral : Qt.alpha(Theme.coral, 0.45); g.lineWidth = 2
                g.beginPath()
                for (let i = 0; i < root.workT.length; i++) {
                    const x = root.xOf(root.workT[i]), y = root.yOf(root.work[i])
                    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y)
                }
                g.stroke()
            }
            Connections {
                target: root
                function onWorkChanged() { cv.requestPaint() }
                function onWorkTChanged() { cv.requestPaint() }
                function onCustomChanged() { cv.requestPaint() }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Repeater {   // y labels
            model: [0, 50, 100]
            delegate: Text {
                required property var modelData
                x: -28; y: root.yOf(modelData) - 7
                text: modelData + "%"; color: Theme.dim
                font.family: Theme.font; font.pixelSize: 9
            }
        }
        Repeater {   // x labels
            model: [30, 50, 70, 90]
            delegate: Text {
                required property var modelData
                x: root.xOf(modelData) - 10; y: plot.height + 3
                text: modelData + "°"; color: Theme.dim
                font.family: Theme.font; font.pixelSize: 9
            }
        }

        Repeater {   // draggable points
            model: root.workT.length
            delegate: Rectangle {
                id: pt
                required property int index
                readonly property real t: root.workT[index]
                width: 12; height: 12; radius: 6
                x: root.xOf(t) - 6
                y: root.yOf(root.work[index] || 0) - 6
                color: drag.pressed || drag.containsMouse ? Theme.amber : (root.custom ? Theme.coral : Theme.muted)
                border.width: 2; border.color: Theme.bg
                MouseArea {
                    id: drag
                    anchors.fill: parent; anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.SizeAllCursor
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        const p = pt.mapToItem(plot, m.x + 6, m.y + 6)
                        const i = pt.index, T = root.workT.slice(), w = root.work.slice()
                        // temperature: between the neighbours (1 ° gap), within 20-100 °C
                        const lo = i > 0 ? T[i - 1] + 1 : root.tMin
                        const hi = i < T.length - 1 ? T[i + 1] - 1 : root.tMax
                        T[i] = Math.max(lo, Math.min(hi, Math.round(root.tMin + (root.tMax - root.tMin) * p.x / plot.width)))
                        // speed: rising curve, never below the floor
                        let v = Math.max(Power.floorPct(T[i]), Math.min(100, Math.round(100 * (1 - p.y / plot.height))))
                        w[i] = v
                        for (let j = i + 1; j < w.length; j++) w[j] = Math.max(w[j], v)
                        for (let j = i - 1; j >= 0; j--) w[j] = Math.min(w[j], v)
                        for (let j = 0; j < w.length; j++) w[j] = Math.max(w[j], Power.floorPct(T[j]))
                        root.workT = T; root.work = w
                    }
                    onReleased: root.edited(root.workT, root.work)
                }
                Text {
                    visible: drag.pressed || drag.containsMouse
                    anchors.bottom: parent.top; anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pt.t + "° · " + (root.work[pt.index] || 0) + "%"
                    color: Theme.amber; font.family: Theme.font; font.pixelSize: 10; font.bold: true
                }
            }
        }
    }
}

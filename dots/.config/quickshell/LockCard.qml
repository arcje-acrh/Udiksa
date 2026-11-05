// LockCard.qml -- a glass card on the lock overlay (LockScreen.qml): glyph + title in caps, then its content.
// It slides in from `from` (x offset) and fades in, `delay` ms after the lock appears (the cards come in one by one).
import QtQuick

Rectangle {
    id: card
    property real s: 1                       // the lock screen's scale (height / 768)
    property string glyph: ""
    property string title: ""
    property string note: ""                 // right side of the title row (a count, a time)
    property int delay: 0
    property real from: 0
    default property alias content: body.data
    property real shown: 0

    radius: 14 * s
    color: Qt.alpha(Theme.surface, 0.5)
    border { width: 1; color: Qt.alpha(Theme.text, 0.08) }
    height: col.implicitHeight + 30 * s
    opacity: shown
    transform: Translate { x: card.from * (1 - card.shown) }
    Component.onCompleted: enter.start()
    SequentialAnimation {
        id: enter
        PauseAnimation { duration: card.delay }
        NumberAnimation { target: card; property: "shown"; to: 1; duration: 600; easing.type: Easing.OutCubic }
    }

    Column {
        id: col
        x: 16 * card.s; y: 15 * card.s
        width: parent.width - 32 * card.s
        spacing: 11 * card.s
        Item {
            width: parent.width
            height: head.implicitHeight
            Row {
                id: head
                spacing: 8 * card.s
                Text { text: card.glyph; color: Theme.coral; font { family: Theme.font; pixelSize: 12 * card.s } }
                Text { text: card.title.toUpperCase(); color: Theme.text; font.family: "Departure Narrow"; font.pixelSize: Math.round(12 * card.s); font.letterSpacing: 2 * card.s }
            }
            Text {
                anchors.right: parent.right
                text: card.note
                color: Theme.dim
                font { family: "Departure Narrow"; pixelSize: 11 * card.s; letterSpacing: 1 * card.s }
            }
        }
        Column { id: body; width: parent.width; spacing: 8 * card.s }
    }
}

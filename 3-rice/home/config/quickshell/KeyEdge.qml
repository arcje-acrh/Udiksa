// KeyEdge.qml -- the retro key bevel (same as Seg.qml's keys) for any button Rectangle: drop it inside.
// Raised = a faint light line along the top edge; pressed = a dark inset line (e.g. a selected / armed button).
import QtQuick

Item {
    property bool pressed: false
    anchors.fill: parent
    Rectangle {   // top light edge (raised key)
        visible: !parent.pressed
        x: 1; y: 1; width: parent.width - 2; height: 1
        color: Qt.alpha(Theme.text, 0.12)
    }
    Rectangle {   // inset shadow (pressed key)
        visible: parent.pressed
        x: 1; y: 1; width: parent.width - 2; height: 2
        color: Qt.alpha(Theme.shadow, 0.35)
    }
}

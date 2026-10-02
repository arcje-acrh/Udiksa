// Card.qml -- a raised rounded block inside a notch panel. Children go into `content` (a Column).
import QtQuick

Rectangle {
    id: root
    default property alias content: col.data
    property int pad: 12
    property alias spacing: col.spacing
    readonly property alias contentHeight: col.implicitHeight      // lets a panel grow to fit its tallest card
    color: Theme.surface
    radius: 12
    Column {
        id: col
        x: root.pad; y: root.pad
        width: root.width - 2 * root.pad
        spacing: 6
    }
}

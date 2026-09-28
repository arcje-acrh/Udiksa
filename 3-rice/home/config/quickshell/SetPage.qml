// SetPage.qml -- base of every Settings section: a vertical scroll area; put rows / group titles inside.
//   SetPage { SetGroup { title: "Windows" } SetRow { ... } }
import QtQuick

Flickable {
    id: root
    property var host: null
    default property alias content: col.data
    property alias spacing: col.spacing
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    Column {
        id: col
        width: Math.min(root.width - 12, 1100)
        spacing: 0
    }
}

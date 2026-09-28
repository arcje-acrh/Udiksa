// ScrollList.qml -- a clipped, scrollable ListView (mouse wheel / touchpad) with a thin coral
// position bar on the right while there is more than fits. Give it `model` and `delegate`.
import QtQuick

ListView {
    id: root
    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    rightMargin: contentHeight > height ? 8 : 0
    Rectangle {   // scroll position
        visible: root.contentHeight > root.height
        anchors.right: parent.right
        width: 3; radius: 2
        color: Qt.alpha(Theme.coral, 0.7)
        height: Math.max(20, root.height * root.height / root.contentHeight)
        y: (root.height - height) * (root.contentY - root.originY) / Math.max(1, root.contentHeight - root.height)
    }
}

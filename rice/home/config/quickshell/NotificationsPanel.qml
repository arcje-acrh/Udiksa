// NotificationsPanel.qml -- the notifications panel in the grown notch (hover the bell or an inline
// notification). Header: count, Do not disturb, Clear all. Then every notification as a card (full text,
// 󰅀 expand, actions, ×). Opening it marks everything read. Grows to fit (wantHeight), scrolls when long.
import QtQuick

Item {
    id: root
    readonly property int wantHeight: Math.min(Theme.panelMaxHeight, Math.max(150, list.contentHeight + 32 + 34 + 12))
    Component.onCompleted: Notifs.markRead()

    Item {
        id: header
        x: 22; y: 16
        width: parent.width - 44; height: 26
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "NOTIFICATIONS · " + Notifs.list.length
            color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Text {
                text: (Notifs.dnd ? "󰂛 " : "󰂚 ") + "Do not disturb"
                color: Notifs.dnd ? Theme.coral : (dm.containsMouse ? Theme.amber : Theme.muted)
                font.family: Theme.font; font.pixelSize: 12; font.bold: Notifs.dnd
                MouseArea { id: dm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.dnd = !Notifs.dnd }
            }
            Text {
                visible: Notifs.list.length > 0
                text: "Clear all"
                color: ca.containsMouse ? Theme.coral : Theme.muted
                font.family: Theme.font; font.pixelSize: 12
                MouseArea { id: ca; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearAll() }
            }
        }
    }

    ScrollList {
        id: list
        x: 22; y: header.y + header.height + 10
        width: parent.width - 44
        height: parent.height - y - 16
        spacing: 8
        model: Notifs.list
        delegate: NotificationCard {
            required property var modelData
            notif: modelData
            width: ListView.view.width - ListView.view.rightMargin
        }
    }
    Text {
        visible: Notifs.list.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: header.y + header.height + 24
        text: "󰄬  All caught up"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 13
    }
}

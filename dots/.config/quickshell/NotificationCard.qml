// NotificationCard.qml -- one notification inside the expanded notification notch (Notifications.qml).
//   icon (the notification's image or the app's icon), app name, close ×, summary, body (basic markup),
//   action buttons. Click the card = its default action (if it has one) and close it.
//   󰅀 expands a long notification to its full text. Critical ones get a red outline.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Item {
    id: root
    required property var notif
    property bool expanded: false
    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property var actions: notif ? notif.actions.filter(a => a.identifier !== "default") : []
    readonly property var defaultAction: notif ? notif.actions.find(a => a.identifier === "default") : null
    readonly property string icon: Notifs.iconFor(notif)
    width: Theme.notifWidth
    height: card.height

    Rectangle {
        id: card
        width: parent.width
        height: body.height + 28
        radius: 12
        color: Theme.surface
        border.width: root.critical ? 1 : 0
        border.color: Theme.warn

        MouseArea {
            anchors.fill: parent
            cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            // default action if the app has one; otherwise a click expands / collapses long text
            onClicked: {
                if (root.defaultAction) { root.defaultAction.invoke(); root.notif.dismiss() }
                else if (expandBtn.visible) root.expanded = !root.expanded
            }
        }

        Row {
            id: body
            x: 14; y: 14
            width: parent.width - 28
            spacing: 12

            Item {   // icon
                width: 40; height: 40
                visible: root.icon !== ""
                IconImage { anchors.fill: parent; source: root.icon; asynchronous: true }
            }
            Column {
                width: parent.width - (root.icon !== "" ? 52 : 0)
                spacing: 4
                Item {
                    width: parent.width; height: 16
                    Text {
                        anchors.left: parent.left; anchors.right: expandBtn.visible ? expandBtn.left : closeX.left; anchors.rightMargin: 8
                        text: root.notif ? (root.notif.appName || "Notification") : ""
                        elide: Text.ElideRight
                        color: root.critical ? Theme.warn : Theme.muted
                        font.family: Theme.font; font.pixelSize: 11; font.letterSpacing: 0.5
                    }
                    Text {   // expand / collapse (only when there is more text than shows)
                        id: expandBtn
                        visible: bodyText.truncated || summaryText.truncated || root.expanded
                        anchors.right: closeX.left; anchors.rightMargin: 10
                        text: root.expanded ? "󰅃" : "󰅀"
                        color: em.containsMouse ? Theme.coral : Theme.muted
                        font.family: Theme.font; font.pixelSize: 14
                        MouseArea { id: em; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.expanded = !root.expanded }
                    }
                    Text {
                        id: closeX
                        anchors.right: parent.right
                        text: "󰅖"
                        color: xm.containsMouse ? Theme.coral : Theme.dim
                        font.family: Theme.font; font.pixelSize: 14
                        MouseArea { id: xm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.notif.dismiss() }
                    }
                }
                Text {
                    id: summaryText
                    width: parent.width
                    visible: text !== ""
                    text: root.notif ? root.notif.summary : ""
                    wrapMode: Text.Wrap; maximumLineCount: root.expanded ? 20 : 2; elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 13; font.bold: true
                }
                Text {
                    id: bodyText
                    width: parent.width
                    visible: text !== ""
                    text: root.notif ? root.notif.body : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap; maximumLineCount: root.expanded ? 60 : 4; elide: Text.ElideRight
                    color: Theme.text; linkColor: Theme.amber
                    font.family: Theme.font; font.pixelSize: 12
                    onLinkActivated: (url) => Qt.openUrlExternally(url)
                }
                Flow {
                    visible: root.actions.length > 0
                    width: parent.width
                    spacing: 6
                    topPadding: 4
                    Repeater {
                        model: root.actions
                        delegate: Rectangle {
                            required property var modelData
                            width: at.implicitWidth + 22; height: 28; radius: 9
                            color: am.containsMouse ? Theme.raised : Theme.surface
                            Text { id: at; anchors.centerIn: parent; text: modelData.text; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { modelData.invoke(); root.notif.dismiss() } }
                        }
                    }
                }
            }
        }
    }
}

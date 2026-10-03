// Notifs.qml -- singleton: the desktop's notification server (org.freedesktop.Notifications) for every
// app, browser pop-ups and system messages. The NOTCH shows them (Notch.qml): a new one "breathes" the
// notch wider and appears inline for Theme.notifTimeout; the bell in the notch counts unread ones; hover
// either to open the notifications panel (NotificationsPanel.qml). Do not disturb = no inline pop-ups
// (critical ones still show). Keeps the last 50 until closed.
// Command: `qs ipc call notifications dnd | clear` (open the panel with `qs ipc call notch toggle notifications`).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: (n) => {
            n.tracked = true
            root.unread += 1
            const all = server.trackedNotifications.values
            if (all.length > 50) all[0].dismiss()
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) {
                root.current = n
                root.fresh = true
                freshTimer.restart()
            }
        }
    }

    readonly property var list: server.trackedNotifications.values.slice().reverse()   // newest first
    property int unread: 0                  // arrived since the panel was last opened
    property bool dnd: false
    property var current: null              // the one shown inline in the notch
    property bool fresh: false              // inline display active
    property bool hold: false               // mouse on the inline notification: keep it
    Timer { id: freshTimer; interval: Theme.notifTimeout; onTriggered: if (!root.hold) root.fresh = false }
    onHoldChanged: if (!hold && !freshTimer.running) fresh = false
    readonly property bool currentCritical: current !== null && current.urgency === NotificationUrgency.Critical

    function markRead() { unread = 0; fresh = false }
    function clearAll() { for (const n of list.slice()) n.dismiss(); unread = 0; fresh = false }
    // the current one was closed elsewhere -> stop showing it
    onListChanged: if (current && list.indexOf(current) < 0) { current = null; fresh = false }

    // an icon that really exists, or "" (the caller then shows its own fallback). Theme icon names and
    // "image://icon/<name>" are checked against the icon theme -- a missing one would draw Qt's
    // magenta checkerboard.
    function resolve(s) {
        if (!s) return ""
        if (s.startsWith("image://icon/")) return Quickshell.iconPath(s.substring(13), true)
        if (s.startsWith("/")) return "file://" + s          // plain path (e.g. kitty's logo) -> a file URL
        if (s.startsWith("file:") || s.startsWith("image://")) return s
        return Quickshell.iconPath(s, true)
    }
    function iconFor(n) {
        if (!n) return ""
        return resolve(n.image) || resolve(n.appIcon) || resolve(n.desktopEntry)
    }

    IpcHandler {
        target: "notifications"
        function dnd(): void { root.dnd = !root.dnd }
        function clear(): void { root.clearAll() }
    }
}

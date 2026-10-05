// MediaPanel.qml -- now playing in the grown notch (MPRIS: browsers, mpv, Spotify, ...).
//   left: cover art, title / artist, seekable progress, previous / play-pause / next
//   right: every player (app) with what it is playing -- click one to control it
// Note: Firefox-based browsers (Zen) publish ONE player for the whole browser, which follows the tab
// that most recently started media; separate tabs/windows do not appear separately.
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris

Item {
    id: root
    readonly property var players: Mpris.players.values
    property var picked: null
    readonly property var player: {
        if (picked && players.indexOf(picked) >= 0) return picked
        for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
        return players.length ? players[0] : null
    }
    function mmss(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    // MPRIS does not push position updates: re-read it right away (panel opened, other player / track)
    // and then twice a second while the panel is open, playing or paused -- otherwise a stale position
    // against a new track's length can show a full bar
    Timer {
        interval: 500; repeat: true; triggeredOnStart: true
        running: root.player !== null
        onTriggered: root.player.positionChanged()
    }
    onPlayerChanged: if (player) player.positionChanged()
    Connections {
        target: root.player
        // (not on lengthChanged: without a reported length Quickshell ties length to position -> endless loop)
        function onTrackTitleChanged() { root.player.positionChanged() }
    }

    // track length. Quickshell's `length` equals the position when the player reports none, and Zen
    // drops the length after seeks / video changes -> read `mpris:length` (microseconds) from the
    // metadata and remember the last one seen for each track
    property var lenCache: ({})
    readonly property string trackKey: player ? player.identity + "|" + player.trackTitle : ""
    readonly property real metaLen: {
        const m = player ? player.metadata : null
        const v = m ? m["mpris:length"] : 0
        return v ? Number(v) / 1000000 : 0
    }
    function remember() { if (metaLen > 0 && trackKey) { const c = lenCache; c[trackKey] = metaLen; lenCache = c } }
    onMetaLenChanged: remember()
    onTrackKeyChanged: remember()
    readonly property real knownLen: metaLen > 0 ? metaLen : (lenCache[trackKey] || 0)


    // seeking by dragging the progress bar
    property bool dragging: false
    property real dragFrac: 0

    Text {
        visible: root.player === null
        anchors.centerIn: parent
        text: "Nothing is playing"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 14
    }

    Row {
        visible: root.player !== null
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 22; anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20

        Rectangle {   // cover art (gradient when the player gives none)
            id: art
            width: 110; height: 110; radius: 12
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.coral }
                GradientStop { position: 1; color: Theme.accentDeep }
            }
            Text { anchors.centerIn: parent; text: "󰝚"; color: Qt.alpha(Theme.text, 0.6); font.family: Theme.font; font.pixelSize: 36 }   // shows when there is no cover
            Rectangle { id: artMask; anchors.fill: parent; radius: art.radius; visible: false; layer.enabled: true }   // rounds the cover (clip: only cuts square)
            Image {
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 220; sourceSize.height: 220
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
            }
        }

        Column {
            width: parent.width - art.width - list.width - 2 * parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.player ? (root.player.trackTitle || root.player.identity) : ""
                color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.bold: true
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.player ? [root.player.trackArtist, root.player.trackAlbum].filter(x => x).join(" · ") : ""
                color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
            }
            Item {   // progress: click or DRAG to seek (when the player allows it); handle shows on hover
                id: prog
                width: parent.width; height: 16
                // length from root.knownLen (metadata + remembered per track); position beyond it = stale -> empty bar
                readonly property bool hasLength: root.player !== null && root.knownLen > 0 && root.player.position <= root.knownLen + 5
                readonly property bool canSeek: hasLength && root.player.canSeek
                readonly property real live: hasLength
                    ? Math.max(0, Math.min(1, root.player.position / root.knownLen)) : 0
                readonly property real frac: root.dragging ? root.dragFrac : live
                LedBar { anchors.verticalCenter: parent.verticalCenter; width: parent.width; segH: 10; frac: prog.frac }
                Rectangle {   // handle
                    visible: prog.canSeek && (seek.containsMouse || root.dragging)
                    x: parent.width * prog.frac - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4; height: 18; radius: 1   // seek notch
                    color: Theme.text
                }
                MouseArea {
                    id: seek
                    anchors.fill: parent
                    enabled: prog.canSeek
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function at(x) { return Math.max(0, Math.min(1, x / width)) }
                    onPressed: (m) => { root.dragFrac = at(m.x); root.dragging = true }
                    onPositionChanged: (m) => { if (root.dragging) root.dragFrac = at(m.x) }
                    onReleased: {
                        if (root.player) { root.player.position = root.knownLen * root.dragFrac; root.player.positionChanged() }
                        root.dragging = false
                    }
                    onCanceled: root.dragging = false
                }
            }
            Item {
                width: parent.width; height: 26
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20
                    Repeater {
                        model: [
                            { icon: "󰒮", ok: root.player && root.player.canGoPrevious, act: () => root.player.previous() },
                            { icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊", ok: root.player && root.player.canTogglePlaying, act: () => root.player.togglePlaying() },
                            { icon: "󰒭", ok: root.player && root.player.canGoNext, act: () => root.player.next() }
                        ]
                        delegate: Text {
                            required property var modelData
                            text: modelData.icon
                            color: !modelData.ok ? Theme.dim : (ctl.containsMouse ? Theme.coral : Theme.text)
                            font.family: Theme.font; font.pixelSize: 22
                            MouseArea { id: ctl; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; enabled: parent.modelData.ok; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.act() }
                        }
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: !root.player ? ""
                        : prog.hasLength ? root.mmss(root.dragging ? root.dragFrac * root.knownLen : root.player.position) + " / " + root.mmss(root.knownLen)
                        : (root.player.positionSupported ? root.mmss(root.player.position) : "")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
            }
        }


        Column {
            id: list
            width: 230
            anchors.top: parent.top          // players list = the cover's height: header + two keys (a third scrolls)
            spacing: 0
            PanelTitle { title: "Players"; action: "" + root.players.length }
            ScrollList {
                width: parent.width
                height: Math.min(contentHeight, 88)
                spacing: 4
                model: root.players
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: root.player === modelData
                    width: ListView.view.width - ListView.view.rightMargin
                    height: 42; radius: 2
                    color: on ? Qt.alpha(Theme.coral, 0.22) : (pm.containsMouse ? Theme.hover : Theme.raised)
                    Rectangle {   // LED: the player being controlled (same as the choice keys)
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: parent.on ? Theme.coral : Theme.dim
                    }
                    Text {   // playing / paused
                        x: 24; anchors.verticalCenter: parent.verticalCenter; width: 16
                        text: modelData.isPlaying ? "󰐊" : "󰏤"
                        color: modelData.isPlaying ? Theme.coral : Theme.muted
                        font.family: Theme.font; font.pixelSize: 15
                    }
                    Column {
                        x: 46; width: parent.width - 46 - 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: modelData.identity
                            color: parent.parent.on ? Theme.text : Theme.muted
                            font.family: Theme.font; font.pixelSize: 12; font.bold: true
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: modelData.trackTitle || "—"
                            color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked = modelData }
                }
            }
        }
    }
}

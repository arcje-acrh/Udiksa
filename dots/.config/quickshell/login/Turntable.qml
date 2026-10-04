// Turntable.qml -- the lock screen's media player, in the rice's flat retro-hardware style: a plain record that turns
// while the music plays (the cover is its label), a thin tonearm that moves from the outer groove to the inner one as
// the track plays (it swings away when paused), and under it the title, an LED progress bar and three small keys.
// Loaded by LoginScreen.qml (lock mode only). s = screen height / 768 like the rest of that file.
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris

Item {
    id: root
    property real s: 1
    property color fg: "#e8e8e8"
    property color accent: "#9ab0c8"
    property color dimc: "#6a7078"
    property string font: "Iosevka Nerd Font"

    // ---- the player ----
    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length ? ps[0] : null
    }
    readonly property bool has: player !== null && !!player.trackTitle
    readonly property bool playing: has && player.isPlaying
    readonly property string title: has ? player.trackTitle : ""
    readonly property string artist: has ? (player.trackArtist || "") : ""
    function mmss(t) { t = Math.max(0, Math.floor(t || 0)); return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0") }
    // MPRIS does not push the position: ask for it twice a second
    Timer { interval: 500; repeat: true; triggeredOnStart: true; running: root.has; onTriggered: root.player.positionChanged() }
    readonly property real metaLen: {
        const m = has ? player.metadata : null
        const v = m ? m["mpris:length"] : 0
        return v ? Number(v) / 1000000 : 0
    }
    readonly property real progress: has && metaLen > 0 ? Math.max(0, Math.min(1, player.position / metaLen)) : 0

    // ---- geometry: the record is the box; the arm and the text are drawn around it ----
    readonly property real dia: 300 * s
    readonly property real rad: dia / 2
    width: dia; height: dia
    opacity: has ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 700 } }

    // ---- the record ----
    Item {
        id: spin
        anchors.fill: parent
        property real angle: 0
        rotation: angle
        NumberAnimation on angle { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: true; paused: !root.playing }

        Rectangle { anchors.fill: parent; radius: root.rad; color: "#0b0b0e"; border.width: Math.max(1, root.s); border.color: Qt.alpha(root.fg, 0.16) }
        Repeater {                                   // three grooves, nothing more
            model: [0.88, 0.74, 0.60]
            delegate: Rectangle {
                required property real modelData
                anchors.centerIn: parent; width: root.dia * modelData; height: width; radius: width / 2
                color: "transparent"; border.width: Math.max(1, root.s); border.color: Qt.alpha(root.fg, 0.07)
            }
        }
        Rectangle { x: parent.width / 2 - width / 2; y: root.rad * 0.12; width: 2 * root.s; height: 14 * root.s; color: root.accent }   // one mark, so the turning shows

        // the label: the cover, in an accent ring
        Rectangle { anchors.centerIn: parent; width: root.dia * 0.40; height: width; radius: width / 2; color: root.accent }
        Item {
            anchors.centerIn: parent; width: root.dia * 0.37; height: width
            Rectangle { id: lmask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#16161a" }
            Image {
                anchors.fill: parent
                source: root.has ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true
                sourceSize.width: 240; sourceSize.height: 240
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: lmask }
            }
            Rectangle { anchors.centerIn: parent; width: 8 * root.s; height: width; radius: width / 2; color: "#050506" }   // spindle
        }
    }
    MouseArea {                                      // the label is a button: play / pause
        anchors.centerIn: parent; width: root.dia * 0.40; height: width
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.has && root.player.canTogglePlaying) root.player.togglePlaying()
    }

    // ---- the tonearm: pivot top right; the needle runs from the outer groove to the inner one ----
    readonly property real armDeg: -40
    readonly property real pivotX: rad + rad * 1.16 * Math.cos(-52 * Math.PI / 180)
    readonly property real pivotY: rad + rad * 1.16 * Math.sin(-52 * Math.PI / 180)
    property real needleR: playing ? rad * (0.90 - 0.44 * progress) : rad * 1.45
    Behavior on needleR { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
    readonly property real tipX: rad + needleR * Math.cos(armDeg * Math.PI / 180)
    readonly property real tipY: rad + needleR * Math.sin(armDeg * Math.PI / 180)
    readonly property real armLen: Math.hypot(tipX - pivotX, tipY - pivotY)
    readonly property real armAng: Math.atan2(tipY - pivotY, tipX - pivotX) * 180 / Math.PI
    Item {
        x: root.pivotX; y: root.pivotY; width: 0; height: 0
        rotation: root.armAng
        Rectangle { x: -root.rad * 0.14; y: -Math.max(1, root.s); width: root.armLen + root.rad * 0.14; height: 2 * Math.max(1, root.s); antialiasing: true; color: root.fg; opacity: 0.85 }
        Rectangle { x: root.armLen - 3 * root.s; y: -5 * root.s; width: 12 * root.s; height: 10 * root.s; color: root.accent }
    }
    Rectangle { x: root.pivotX - 8 * root.s; y: root.pivotY - 8 * root.s; width: 16 * root.s; height: width; radius: width / 2; color: "#0b0b0e"; border.width: Math.max(1, root.s); border.color: Qt.alpha(root.fg, 0.7) }

    // ---- under the record: title, LED progress, keys ----
    Column {
        x: 0; y: root.dia + 18 * root.s
        width: root.dia
        spacing: 6 * root.s
        Text { text: root.title; width: parent.width; elide: Text.ElideRight; color: root.fg; font { family: root.font; pixelSize: 15 * root.s; bold: true } }
        Row {
            spacing: 10 * root.s
            Rectangle { width: 22 * root.s; height: Math.max(1, root.s); color: root.accent; anchors.verticalCenter: parent.verticalCenter; visible: root.artist !== "" }
            Text { text: root.artist.toUpperCase(); visible: root.artist !== ""; width: Math.min(implicitWidth, root.dia - 40 * root.s); elide: Text.ElideRight; color: root.accent
                   font { family: root.font; pixelSize: 12 * root.s; letterSpacing: 2 * root.s } }
        }
        Row {                                        // LED progress bar: 30 little segments
            spacing: 2 * root.s
            Repeater {
                model: 30
                delegate: Rectangle {
                    required property int index
                    width: (root.dia - 29 * 2 * root.s) / 30; height: 4 * root.s
                    color: index < Math.round(root.progress * 30) ? root.accent : Qt.alpha(root.fg, 0.14)
                }
            }
        }
        Item { width: 1; height: 2 * root.s }
        Row {
            spacing: 6 * root.s
            Repeater {
                model: [
                    { glyph: "󰒮", ok: root.has && root.player.canGoPrevious, act: () => root.player.previous() },
                    { glyph: root.playing ? "󰏤" : "󰐊", ok: root.has && root.player.canTogglePlaying, act: () => root.player.togglePlaying(), led: true },
                    { glyph: "󰒭", ok: root.has && root.player.canGoNext, act: () => root.player.next() }
                ]
                delegate: Rectangle {
                    id: key
                    required property var modelData
                    width: 38 * root.s; height: 28 * root.s; radius: 2 * root.s
                    color: kma.containsMouse ? Qt.alpha(root.accent, 0.22) : Qt.alpha("#000000", 0.35)
                    border.width: Math.max(1, root.s); border.color: Qt.alpha(kma.containsMouse ? root.accent : root.fg, kma.containsMouse ? 0.9 : 0.3)
                    opacity: modelData.ok ? 1 : 0.35
                    Text { anchors.centerIn: parent; text: key.modelData.glyph; color: kma.containsMouse ? root.accent : root.fg; font { family: root.font; pixelSize: 15 * root.s } }
                    Rectangle { visible: key.modelData.led === true; x: parent.width - 8 * root.s; y: 4 * root.s; width: 4 * root.s; height: width; color: root.playing ? root.accent : Qt.alpha(root.fg, 0.2) }   // LED: lit while playing
                    MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: key.modelData.ok; onClicked: key.modelData.act() }
                }
            }
            Item { width: 8 * root.s; height: 1 }
            Text { anchors.verticalCenter: parent.verticalCenter; visible: root.metaLen > 0; text: root.mmss(root.player ? root.player.position : 0) + " / " + root.mmss(root.metaLen)
                   color: root.fg; opacity: 0.55; font { family: root.font; pixelSize: 12 * root.s } }
        }
    }
}

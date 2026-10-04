// Turntable.qml -- the lock screen's media player: a record in the theme's colours that spins while the music plays.
//   * the cover is the record's label
//   * a tonearm rests on the record and moves from the outer groove to the inner one as the track plays;
//     paused or stopped, it swings away. Three round keys on the right edge: previous / play-pause / next
//     (a click on the label also plays / pauses).
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
    // MPRIS does not push the position: ask for it twice a second (and when the track changes)
    Timer { interval: 500; repeat: true; triggeredOnStart: true; running: root.has; onTriggered: root.player.positionChanged() }
    readonly property real metaLen: {
        const m = has ? player.metadata : null
        const v = m ? m["mpris:length"] : 0
        return v ? Number(v) / 1000000 : 0
    }
    readonly property real progress: has && metaLen > 0 ? Math.max(0, Math.min(1, player.position / metaLen)) : 0

    // ---- geometry: the record is the box, everything else is drawn around it ----
    readonly property real dia: 330 * s
    readonly property real rad: dia / 2
    width: dia; height: dia
    opacity: has ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 700 } }
    transform: Translate { x: (1 - root.opacity) * -60 * root.s }

    // soft shadow under the record
    Rectangle { x: 6 * root.s; y: 10 * root.s; width: root.dia; height: root.dia; radius: root.rad; color: "#000000"; opacity: 0.35 }

    // ---- the spinning part ----
    Item {
        id: spin
        anchors.fill: parent
        property real angle: 0
        rotation: angle
        NumberAnimation on angle { from: 0; to: 360; duration: 11000; loops: Animation.Infinite; running: true; paused: !root.playing }

        Rectangle { anchors.fill: parent; radius: root.rad; color: Qt.darker(root.accent, 5.5); border.width: Math.max(1, root.s); border.color: Qt.alpha(root.accent, 0.55) }
        Repeater {                                   // a few grooves in the theme colour
            model: [0.86, 0.72, 0.58]
            delegate: Rectangle {
                required property real modelData
                anchors.centerIn: parent; width: root.dia * modelData; height: width; radius: width / 2
                color: "transparent"; border.width: Math.max(1, root.s); border.color: Qt.alpha(root.accent, 0.22)
            }
        }
        Rectangle { x: parent.width / 2 - width / 2; y: root.rad * 0.14; width: 5 * root.s; height: width; radius: width / 2; color: root.accent }   // a mark, so the turning shows

        // the label: the cover
        Rectangle { anchors.centerIn: parent; width: root.dia * 0.43; height: width; radius: width / 2; color: root.accent }
        Item {
            id: label
            anchors.centerIn: parent; width: root.dia * 0.41; height: width
            Rectangle { id: lmask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#16161a" }
            Image {
                anchors.fill: parent
                source: root.has ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true
                sourceSize.width: 260; sourceSize.height: 260
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: lmask }
            }
            Rectangle { anchors.centerIn: parent; width: 9 * root.s; height: width; radius: width / 2; color: Qt.darker(root.accent, 8) }   // spindle
        }
    }
    // the label is a button: play / pause
    MouseArea {
        anchors.centerIn: parent; width: root.dia * 0.41; height: width
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.has && root.player.canTogglePlaying) root.player.togglePlaying()
    }

    // ---- the tonearm: pivot top right; the needle runs from the outer groove to the inner one ----
    readonly property real armDeg: -40                                    // the line the needle follows, from the centre
    readonly property real pivotX: rad + rad * 1.18 * Math.cos(-52 * Math.PI / 180)
    readonly property real pivotY: rad + rad * 1.18 * Math.sin(-52 * Math.PI / 180)
    property real needleR: playing ? rad * (0.93 - 0.46 * progress) : rad * 1.45
    Behavior on needleR { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
    readonly property real tipX: rad + needleR * Math.cos(armDeg * Math.PI / 180)
    readonly property real tipY: rad + needleR * Math.sin(armDeg * Math.PI / 180)
    readonly property real armLen: Math.hypot(tipX - pivotX, tipY - pivotY)
    readonly property real armAng: Math.atan2(tipY - pivotY, tipX - pivotX) * 180 / Math.PI
    Item {
        x: root.pivotX; y: root.pivotY; width: 0; height: 0
        rotation: root.armAng
        Rectangle { x: -root.rad * 0.16; y: -3 * root.s; width: root.armLen + root.rad * 0.16; height: 6 * root.s; radius: 3 * root.s; color: root.fg; opacity: 0.85 }   // arm + counterweight stub
        Rectangle { x: -root.rad * 0.20; y: -6 * root.s; width: root.rad * 0.10; height: 12 * root.s; radius: 2 * root.s; color: root.fg; opacity: 0.55 }              // counterweight
        Rectangle { x: root.armLen - 8 * root.s; y: -6 * root.s; width: 18 * root.s; height: 12 * root.s; radius: 2 * root.s; color: root.accent }                       // headshell
    }
    Rectangle { x: root.pivotX - 13 * root.s; y: root.pivotY - 13 * root.s; width: 26 * root.s; height: width; radius: width / 2; color: "#121216"; border.width: 2; border.color: Qt.alpha(root.fg, 0.7) }
    Rectangle { x: root.pivotX - 4 * root.s; y: root.pivotY - 4 * root.s; width: 8 * root.s; height: width; radius: width / 2; color: root.accent }

    // ---- three round keys on the right edge ----
    Repeater {
        model: [
            { deg: -15, glyph: "󰒮", big: false, ok: root.has && root.player.canGoPrevious, act: () => root.player.previous() },
            { deg: 0,   glyph: root.playing ? "󰏤" : "󰐊", big: true, ok: root.has && root.player.canTogglePlaying, act: () => root.player.togglePlaying() },
            { deg: 15,  glyph: "󰒭", big: false, ok: root.has && root.player.canGoNext, act: () => root.player.next() }
        ]
        delegate: Rectangle {
            id: key
            required property var modelData
            readonly property real sz: (modelData.big ? 46 : 34) * root.s
            readonly property real rr: root.rad + 40 * root.s
            x: root.rad + rr * Math.cos(modelData.deg * Math.PI / 180) - sz / 2
            y: root.rad + rr * Math.sin(modelData.deg * Math.PI / 180) - sz / 2
            width: sz; height: sz; radius: sz / 2
            color: kma.containsMouse ? Qt.alpha(root.accent, 0.25) : Qt.alpha("#000000", 0.35)
            border.width: 1; border.color: Qt.alpha(kma.containsMouse ? root.accent : root.fg, kma.containsMouse ? 0.9 : 0.35)
            opacity: modelData.ok ? 1 : 0.35
            Text { anchors.centerIn: parent; text: key.modelData.glyph; color: kma.containsMouse ? root.accent : root.fg; font { family: root.font; pixelSize: (key.modelData.big ? 20 : 15) * root.s } }
            MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: key.modelData.ok; onClicked: key.modelData.act() }
        }
    }

    // ---- what is playing, under the record ----
    Column {
        x: 4 * root.s; y: root.dia + 16 * root.s
        spacing: 3 * root.s
        Text { text: root.title; width: root.dia; elide: Text.ElideRight; color: root.fg; font { family: root.font; pixelSize: 15 * root.s; bold: true } }
        Row {
            spacing: 14 * root.s
            Text { text: root.artist; visible: root.artist !== ""; width: Math.min(implicitWidth, root.dia * 0.6); elide: Text.ElideRight; color: root.accent; font { family: root.font; pixelSize: 12 * root.s; letterSpacing: 1 * root.s } }
            Text { visible: root.metaLen > 0; text: root.mmss(root.player ? root.player.position : 0) + " / " + root.mmss(root.metaLen); color: root.fg; opacity: 0.5; font { family: root.font; pixelSize: 12 * root.s } }
        }
    }
}

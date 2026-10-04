// LoginScreen.qml -- the ONE login / lock screen design (layout from qylock's "sword" theme, GPL-3.0,
// github.com/Darkkal44/qylock). Used twice:
//   * boot login: /var/lib/rice-greeter/shell.qml (greetd runs it in cage as user "greeter")
//   * lock screen: ~/.config/quickshell/Lock.qml (inside the running shell)
// rice-theme copies this folder to /var/lib/rice-greeter/ on every theme change, together with theme.json
// (colours for a dark scrim) and wallpaper.jpg, so edit it HERE, then run `rice-theme reapply`.
//
// Placement (s = screen height / 768, as in the original): clock top-left, name + password bottom-right,
// a hairline along the bottom with the session on the left (login only) and Restart / Shut Down on the right.
// Click the name = next user, click the session = next session. No messages: a wrong password shakes + clears.
import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

Item {
    id: root
    anchors.fill: parent

    property string mode: "login"                // "login" or "lock"
    property var colours: ({})                   // theme.json: fg, accent, dim, line, scrim
    property string wallpaper: ""
    property var users: []                       // [{ login, name }]
    property var sessions: []                    // [{ name, exec }]
    property int userIndex: 0
    property int sessionIndex: 0
    property bool busy: false                    // waiting for greetd / PAM
    property string host: ""                     // shown bottom-left after the session / WM name
    property string wm: "Hyprland"               // lock mode: the running WM (login mode shows the session)

    // battery + now playing, shown under the date
    readonly property var bat: UPower.displayDevice
    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length ? ps[0] : null
    }
    readonly property string batLine: bat && bat.isLaptopBattery !== false && bat.percentage > 0
        ? (bat.state === UPowerDeviceState.Charging ? "󰂄 " : "󰁹 ") + Math.round(bat.percentage * 100) + "%" : ""
    readonly property string mediaLine: player && player.trackTitle
        ? (player.isPlaying ? "󰝚 " : "󰏤 ") + player.trackTitle + (player.trackArtist ? " · " + player.trackArtist : "") : ""


    signal submit(string user, string password, int session)
    signal power(string action)                  // "reboot" | "poweroff"

    readonly property real s: height / 768
    readonly property color fg: (colours && colours.fg) || "#e8e8e8"
    readonly property color accent: (colours && colours.accent) || "#9ab0c8"
    readonly property color dimc: (colours && colours.dim) || "#6a7078"
    readonly property string font: "Iosevka Nerd Font"
    property real ui: 0

    function fail() {                            // wrong password: clear, shake, keep focus
        busy = false
        pw.text = ""
        pw.forceActiveFocus()
        shake.restart()
    }
    function focusField() { pw.forceActiveFocus() }
    function go() {
        if (busy || pw.text.length === 0) return
        busy = true
        const u = users.length ? users[userIndex].login : ""
        submit(u, pw.text, sessionIndex)
    }

    Component.onCompleted: { fade.start(); focusTimer.start() }
    Timer { id: focusTimer; interval: 300; onTriggered: pw.forceActiveFocus() }
    NumberAnimation { id: fade; target: root; property: "ui"; from: 0; to: 1; duration: 1400; easing.type: Easing.OutCubic }

    // ---- background: wallpaper + vignette + dark bottom edge ----
    Rectangle { anchors.fill: parent; color: (root.colours && root.colours.scrim) || "#08090c" }
    Image {
        anchors.fill: parent
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }
    Item {                                       // vignette (radial, transparent centre -> dark edges)
        anchors.fill: parent
        opacity: 0.75
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const g = getContext("2d")
                const r = Math.hypot(width, height) / 2
                const grd = g.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, r)
                grd.addColorStop(0, "rgba(0,0,0,0)")
                grd.addColorStop(1, "rgba(0,0,0,0.73)")
                g.fillStyle = grd
                g.fillRect(0, 0, width, height)
            }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 200 * root.s
        opacity: 0.65
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#dd000000" }
        }
    }

    // ---- lock screen only: the turntable (media player), bottom-left ----
    Loader {
        active: root.mode === "lock"
        source: "Turntable.qml"
        x: 70 * root.s
        y: root.height - 480 * root.s
        opacity: root.ui
        onLoaded: { item.s = Qt.binding(() => root.s); item.fg = Qt.binding(() => root.fg); item.accent = Qt.binding(() => root.accent); item.dimc = Qt.binding(() => root.dimc); item.font = root.font }
    }

    // ---- clock, top-left ----
    Column {
        anchors { left: parent.left; top: parent.top; leftMargin: 70 * root.s; topMargin: 60 * root.s }
        spacing: 8 * root.s
        opacity: root.ui
        Text {
            id: clock
            text: Qt.formatTime(new Date(), "HH:mm")
            color: root.fg
            font { family: root.font; pixelSize: 80 * root.s; bold: true; letterSpacing: -7 * root.s }   // tighter: Iosevka's monospace cells look wide this big
        }
        Row {
            spacing: 10 * root.s
            Rectangle { width: 22 * root.s; height: Math.max(1, root.s); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: date
                text: Qt.formatDate(new Date(), "dddd · MMMM d").toUpperCase()
                color: root.accent
                font { family: root.font; pixelSize: 13 * root.s; letterSpacing: 3 * root.s }
            }
        }
        Item { width: 1; height: 6 * root.s }
        Text {                                   // battery, then what's playing
            text: root.batLine
            visible: text !== ""
            color: root.fg
            opacity: 0.7
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width * 0.45)
            font { family: root.font; pixelSize: 13 * root.s; letterSpacing: 1 * root.s }
        }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: { const d = new Date(); clock.text = Qt.formatTime(d, "HH:mm"); date.text = Qt.formatDate(d, "dddd · MMMM d").toUpperCase() }
        }
    }

    // ---- name + password, bottom-right ----
    Column {
        id: panel
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 40 * root.s + shakeX; bottomMargin: 110 * root.s }
        width: 280 * root.s
        opacity: root.ui
        property real shakeX: 0

        Text {
            id: who
            anchors.right: parent.right
            text: root.users.length ? root.users[root.userIndex].name : ""
            color: root.fg
            font { family: root.font; pixelSize: 22 * root.s; letterSpacing: 2 * root.s; bold: true }
            scale: whoMa.containsMouse && root.users.length > 1 ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            transform: Translate { id: whoT }
            MouseArea {
                id: whoMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.users.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: swapUser.start()
            }
            SequentialAnimation {
                id: swapUser
                ParallelAnimation { NumberAnimation { target: who; property: "opacity"; to: 0; duration: 120 } NumberAnimation { target: whoT; property: "x"; to: 15 * root.s; duration: 120 } }
                ScriptAction { script: { root.userIndex = (root.userIndex + 1) % root.users.length; pw.text = ""; pw.forceActiveFocus() } }
                ParallelAnimation { NumberAnimation { target: who; property: "opacity"; to: 1; duration: 180 } NumberAnimation { target: whoT; property: "x"; to: 0; duration: 180 } }
            }
        }

        Item { width: 1; height: 22 * root.s }

        Item {
            width: parent.width
            height: 36 * root.s
            TextInput {
                id: pw
                anchors { left: parent.left; right: arrow.left; rightMargin: 12 * root.s; verticalCenter: parent.verticalCenter }
                color: "transparent"
                echoMode: TextInput.NoEcho
                font { family: root.font; pixelSize: 14 * root.s }
                focus: true
                clip: true
                cursorVisible: false
                cursorDelegate: Item {}
                enabled: !root.busy
                Keys.onReturnPressed: root.go()
                Keys.onEnterPressed: root.go()
                Keys.onEscapePressed: text = ""
                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 8 * root.s
                    Repeater {
                        model: pw.text.length
                        delegate: Text { text: "✦"; color: root.fg; font: pw.font }
                    }
                    Text {
                        id: star
                        text: "✦"
                        color: root.accent
                        font: pw.font
                        visible: pw.activeFocus
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: star.visible
                            NumberAnimation { from: 1; to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.2; to: 1; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enter password"
                    color: root.fg
                    opacity: pw.text.length === 0 && !pw.activeFocus ? 0.25 : 0
                    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutSine } }
                    font { family: root.font; pixelSize: 14 * root.s; letterSpacing: 2 * root.s }
                }
            }
            MouseArea { anchors.fill: pw; cursorShape: Qt.IBeamCursor; onClicked: pw.forceActiveFocus() }
            Text {
                id: arrow
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: root.busy ? "…" : "→"
                color: root.accent
                font { family: root.font; pixelSize: 16 * root.s }
                opacity: pw.text.length > 0 ? 1.0 : 0.3
                Behavior on opacity { NumberAnimation { duration: 200 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.go() }
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(1, root.s)
            color: pw.activeFocus ? root.accent : root.dimc
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: panel; property: "shakeX"; to: 10 * root.s; duration: 50 }
        NumberAnimation { target: panel; property: "shakeX"; to: -10 * root.s; duration: 50 }
        NumberAnimation { target: panel; property: "shakeX"; to: 5 * root.s; duration: 50 }
        NumberAnimation { target: panel; property: "shakeX"; to: -5 * root.s; duration: 50 }
        NumberAnimation { target: panel; property: "shakeX"; to: 0; duration: 50 }
    }

    // ---- bottom hairline: session (login only) left, power right ----
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 40 * root.s; rightMargin: 40 * root.s; bottomMargin: 30 * root.s }
        height: Math.max(1, root.s)
        color: root.fg
        opacity: 0.08 * root.ui
    }
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 40 * root.s }
        height: 40 * root.s
        opacity: root.ui * 0.8

        Item {
            id: sess
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            visible: root.mode === "lock" || root.sessions.length > 0
            width: sessRow.implicitWidth
            height: sessRow.implicitHeight
            scale: sessMa.containsMouse ? 1.05 : 1.0
            Row {
                id: sessRow
                spacing: 10 * root.s
                transform: Translate { id: sessT }
                Text { text: "◈"; color: root.accent; font.pixelSize: 10 * root.s; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    id: sessName
                    text: (root.mode === "lock" ? root.wm : (root.sessions.length ? root.sessions[root.sessionIndex].name : "")) + (root.host ? "  ·  " + root.host : "")
                    color: root.fg
                    opacity: sessMa.containsMouse ? 1.0 : 0.6
                    font { family: root.font; pixelSize: 12 * root.s; letterSpacing: 1 * root.s }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: sessMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.mode === "login" && root.sessions.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: swapSession.start()
            }
            SequentialAnimation {
                id: swapSession
                ParallelAnimation { NumberAnimation { target: sessName; property: "opacity"; to: 0; duration: 120 } NumberAnimation { target: sessT; property: "x"; to: 10 * root.s; duration: 120 } }
                ScriptAction { script: root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length }
                ParallelAnimation { NumberAnimation { target: sessName; property: "opacity"; to: 0.6; duration: 180 } NumberAnimation { target: sessT; property: "x"; to: 0; duration: 180 } }
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 28 * root.s
            Repeater {
                model: [{ label: "Restart", act: "reboot" }, { label: "Shut Down", act: "poweroff" }]
                delegate: Text {
                    required property var modelData
                    text: modelData.label
                    color: root.fg
                    opacity: ma.containsMouse ? 0.9 : 0.4
                    scale: ma.containsMouse ? 1.1 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    font { family: root.font; pixelSize: 12 * root.s; letterSpacing: 1 * root.s }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.power(modelData.act) }
                }
            }
        }
    }

    // rounded screen corners, the same as the desktop's (rice-theme puts the radius in SCREEN pixels into theme.json
    // "corner"; dividing by the device pixel ratio gives this screen's units, in the greeter and the lock alike)
    Item {
        id: corners
        anchors.fill: parent
        z: 1000
        readonly property real r: ((root.colours && root.colours.corner) || 0) / Screen.devicePixelRatio
        visible: r > 0
        Repeater {
            model: [[0, 0, 0], [1, 0, 90], [1, 1, 180], [0, 1, 270]]
            delegate: Shape {
                required property var modelData
                x: modelData[0] ? corners.width - corners.r : 0
                y: modelData[1] ? corners.height - corners.r : 0
                width: corners.r; height: corners.r
                rotation: modelData[2]
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "black"; strokeColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: corners.r; y: 0 }
                    PathArc { x: 0; y: corners.r; radiusX: corners.r; radiusY: corners.r; direction: PathArc.Counterclockwise }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
    }
}

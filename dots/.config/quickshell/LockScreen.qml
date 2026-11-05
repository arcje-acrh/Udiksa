// LockScreen.qml -- the lock overlay on one screen (Lock.qml makes one per screen; key / idle / lid locks).
// The desktop you left (a screenshot taken just before locking), blurred and dimmed, and on top:
//   centre    clock with ticking seconds, date, a greeting | the music card (blurred cover glow, progress,
//             equaliser while playing) | your name, the password line, the face unlock note
//   left      weather (now + 4 days, sunrise / sunset) | today (agenda items + holidays)
//   right     system (battery, CPU, memory as LED bars; Wi-Fi, Bluetooth, Tailscale, uptime) | notifications
// Cards slide in one by one after the blur; unlocking blurs back out into the same desktop. Colours: Theme.qml.
// Face unlock only on Space (empty field): the note says so. A wrong password shakes + clears.
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

Item {
    id: root
    anchors.fill: parent

    property string shot: ""                     // screenshot of this screen ("" / missing = the greeter wallpaper)
    property string name: ""
    property string face: ""                     // "" none | "ready" | "scan" | "ok" | "miss"
    property bool leaving: false                 // unlocked: blur back out (Lock.qml drops the lock right after)
    property bool busy: false                    // waiting for PAM
    signal submit(string password)
    signal faceRetry()                           // Space in the empty field / click on the note
    signal power(string action)                  // "reboot" | "poweroff"

    readonly property real s: height / 768
    readonly property real side: 330 * s         // width of the left / right card columns
    FontLoader { id: pixel; source: "login/DepartureNarrow.otf" }   // the greeter pixel font, 75 % width
    readonly property string pf: pixel.status === FontLoader.Ready ? pixel.name : "Departure Mono"
    property real ui: 0                          // 0 = the desktop as you left it, 1 = locked

    function fail() {                            // wrong password: clear, shake, keep focus
        busy = false
        pw.text = ""
        pw.forceActiveFocus()
        shake.restart()
    }
    function go() {
        if (busy || pw.text.length === 0) return
        busy = true
        submit(pw.text)
    }

    Component.onCompleted: { enter.start(); focusTimer.start() }
    Timer { id: focusTimer; interval: 300; onTriggered: pw.forceActiveFocus() }
    NumberAnimation { id: enter; target: root; property: "ui"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
    NumberAnimation { id: leave; target: root; property: "ui"; to: 0; duration: 400; easing.type: Easing.InOutCubic }
    onLeavingChanged: if (leaving) { enter.stop(); leave.start() }

    // ---- live data: time, CPU / memory / uptime (every 2 s while locked) ----
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    property real cpu: 0
    property real memUsed: 0
    property real memTotal: 0
    property real uptime: 0
    property var cpuLast: null
    Process {
        id: sample
        running: true
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; cat /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                const c = l[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0)
                if (root.cpuLast) {
                    const dt = total - root.cpuLast.total
                    if (dt > 0) root.cpu = 1 - (idle - root.cpuLast.idle) / dt
                }
                root.cpuLast = { idle: idle, total: total }
                const kb = s => Number((s.match(/(\d+)/) || [0, 0])[1])
                root.memTotal = kb(l[1]); root.memUsed = root.memTotal - kb(l[2])
                root.uptime = Number(l[3].split(" ")[0])
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: sample.running = true }

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat && bat.isLaptopBattery !== false && bat.percentage > 0
    readonly property var wifi: {
        const ds = Networking.devices.values
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) {
            const ns = ds[i].networks.values
            for (let j = 0; j < ns.length; j++) if (ns[j].connected) return ns[j]
        }
        return null
    }
    readonly property int btCount: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values.filter(d => d.connected).length : 0
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => !/playerctld/i.test((p.dbusName || "") + (p.identity || "")))
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length ? ps[0] : null
    }
    function hm(sec) { const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60); return h ? h + " h " + m + " m" : m + " m" }
    function mmss(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ":" + (sec % 60 < 10 ? "0" : "") + sec % 60 }

    // ---- background: the desktop, blurred in ----
    Rectangle { anchors.fill: parent; color: Theme.bg }
    Image {
        id: desk
        anchors.fill: parent
        source: root.shot ? "file://" + root.shot : ""
        onStatusChanged: if (status === Image.Error) source = "file:///var/lib/rice-greeter/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: desk
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.ui
        saturation: -0.3 * root.ui
    }
    Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.5 * root.ui }
    Rectangle {                                  // a soft accent wash from the top: the "lit" feel
        anchors.fill: parent
        opacity: 0.18 * root.ui
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.coral }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }

    // ---- the overlay ----
    Item {
        anchors.fill: parent
        opacity: Math.min(1, root.ui * 1.4)

        // ======== centre: clock ========
        Column {
            id: clockCol
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 44 * root.s }
            spacing: 4 * root.s
            transform: Translate { y: -20 * root.s * (1 - root.ui) }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * root.s
                Text {
                    id: hhmm
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: Theme.text
                    font.family: root.pf; font.pixelSize: Math.round(121 * root.s)
                    font.letterSpacing: -3 * root.s
                }
                Text {                      // seconds: ticks with a small drop
                    id: secs
                    anchors { baseline: hhmm.baseline }
                    text: Qt.formatTime(root.now, "ss")
                    color: Theme.coral
                    font.family: root.pf; font.pixelSize: Math.round(33 * root.s)
                    onTextChanged: tick.restart()
                    transform: Translate { id: secT }
                    SequentialAnimation {
                        id: tick
                        NumberAnimation { target: secT; property: "y"; from: -6 * root.s; to: 0; duration: 260; easing.type: Easing.OutBack }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * root.s
                Rectangle { width: 26 * root.s; height: Math.max(1, root.s); color: Theme.coral; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.now, "dddd · MMMM d").toUpperCase()
                    color: Theme.coral
                    font.family: root.pf; font.pixelSize: Math.round(15 * root.s)
                    font.letterSpacing: 2 * root.s
                }
                Rectangle { width: 26 * root.s; height: Math.max(1, root.s); color: Theme.coral; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6 * root.s
                text: {
                    const h = root.now.getHours()
                    return ((h < 5 ? "Up late" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening")
                        + (root.name ? ", " + root.name.split(" ")[0] : "")).toUpperCase()
                }
                color: Theme.text
                opacity: 0.6
                font { family: root.pf; pixelSize: 14 * root.s; letterSpacing: 1 * root.s }
            }
        }

        // ======== left: weather, today ========
        Column {
            anchors { left: parent.left; top: parent.top; leftMargin: 40 * root.s; topMargin: 44 * root.s }
            width: root.side
            spacing: 14 * root.s

            LockCard {
                visible: Weather.wanted && Weather.ok
                width: parent.width; s: root.s; delay: 150; from: -40 * root.s
                glyph: "󰖐"; title: "Weather"; note: Weather.w ? Weather.w.name : ""
                Row {
                    spacing: 14 * root.s
                    Text { text: Weather.icon(Weather.now.code, Weather.now.day); color: Theme.coral; font { family: root.pf; pixelSize: 38 * root.s } }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: Weather.deg(Weather.now.temp || 0); color: Theme.text; font.family: root.pf; font.pixelSize: Math.round(33 * root.s) }
                        Text { text: Weather.words(Weather.now.code); color: Theme.muted; font { family: root.pf; pixelSize: 12 * root.s } }
                    }
                }
                Text {
                    width: parent.width
                    text: "feels " + Weather.deg(Weather.now.feels || 0) + "  ·  󰖎 " + Math.round(Weather.now.humidity || 0) + "%  ·  󰖝 " + Math.round(Weather.now.wind || 0) + " km/h"
                    color: Theme.text; opacity: 0.7
                    font { family: root.pf; pixelSize: 11 * root.s }
                }
                Row {                            // next days
                    width: parent.width
                    Repeater {
                        model: Weather.days.slice(1, 5)
                        delegate: Column {
                            required property var modelData
                            width: parent.width / 4
                            spacing: 3 * root.s
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd").toUpperCase(); color: Theme.muted; font { family: root.pf; pixelSize: 10 * root.s; letterSpacing: 1.5 * root.s } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.icon(modelData.code, true); color: Theme.text; font { family: root.pf; pixelSize: 18 * root.s } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.deg(modelData.max) + " " + Weather.deg(modelData.min); color: Theme.text; opacity: 0.75; font { family: root.pf; pixelSize: 10 * root.s } }
                        }
                    }
                }
                Text {
                    visible: !!Weather.sun.rise
                    text: "󰖜 " + (Weather.sun.rise || "") + "    󰖛 " + (Weather.sun.set || "")
                    color: Theme.muted
                    font { family: root.pf; pixelSize: 11 * root.s }
                }
            }

            LockCard {
                id: today
                width: parent.width; s: root.s; delay: 300; from: -40 * root.s
                glyph: "󰃶"; title: "Today"
                readonly property var list: {
                    const d = root.now
                    return Agenda.holidaysOn(d).map(h => ({ time: "", text: h.name, kind: "holiday" }))
                        .concat(Agenda.itemsOn(d).map(i => ({ time: i.time, text: i.text, kind: i.kind })))
                }
                note: list.length ? list.length + (list.length === 1 ? " item" : " items") : ""
                Text {
                    visible: today.list.length === 0
                    text: "Nothing planned"
                    color: Theme.text; opacity: 0.55
                    font { family: root.pf; pixelSize: 12 * root.s }
                }
                Repeater {
                    model: today.list.slice(0, 5)
                    delegate: Row {
                        required property var modelData
                        spacing: 10 * root.s
                        width: today.width - 32 * root.s
                        Text {
                            width: 44 * root.s
                            text: modelData.time || "all day"
                            color: modelData.kind === "holiday" ? Theme.amber : Theme.coral
                            font { family: root.pf; pixelSize: 11 * root.s }
                        }
                        Text {
                            width: parent.width - 54 * root.s
                            text: modelData.text
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: root.pf; pixelSize: 12 * root.s }
                        }
                    }
                }
            }
        }

        // ======== right: system, notifications ========
        Column {
            anchors { right: parent.right; top: parent.top; rightMargin: 40 * root.s; topMargin: 44 * root.s }
            width: root.side
            spacing: 14 * root.s

            LockCard {
                width: parent.width; s: root.s; delay: 220; from: 40 * root.s
                glyph: "󰍛"; title: "System"; note: "up " + root.hm(root.uptime)
                Repeater {
                    model: [
                        { k: "BAT", v: root.hasBat ? root.bat.percentage : -1,
                          t: root.hasBat ? Math.round(root.bat.percentage * 100) + "%" + (root.bat.state === UPowerDeviceState.Charging ? " 󰂄" : root.bat.timeToEmpty > 0 ? "  " + root.hm(root.bat.timeToEmpty) : "") : "" },
                        { k: "CPU", v: root.cpu, t: Math.round(root.cpu * 100) + "%" },
                        { k: "MEM", v: root.memTotal ? root.memUsed / root.memTotal : 0, t: (root.memUsed / 1048576).toFixed(1) + " / " + Math.round(root.memTotal / 1048576) + " G" }
                    ]
                    delegate: Row {
                        required property var modelData
                        visible: modelData.v >= 0
                        spacing: 10 * root.s
                        Text { width: 32 * root.s; text: modelData.k; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter; font { family: root.pf; pixelSize: 10 * root.s; letterSpacing: 1.5 * root.s } }
                        LedBar { width: root.side - 32 * root.s - 130 * root.s; segH: Math.round(10 * root.s); frac: modelData.v; anchors.verticalCenter: parent.verticalCenter }
                        Text { width: 78 * root.s; horizontalAlignment: Text.AlignRight; text: modelData.t; color: Theme.text; anchors.verticalCenter: parent.verticalCenter; font { family: root.pf; pixelSize: 11 * root.s } }
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 6 * root.s
                    Repeater {
                        model: [
                            root.wifi ? "󰤨  " + root.wifi.name : "󰤭  offline",
                            "󰂯  " + (root.btCount ? root.btCount + " connected" : (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "on" : "off")),
                            Tailscale.installed ? "󰖂  " + (Tailscale.running ? Tailscale.onlineCount + " online" : "off") : ""
                        ].filter(t => t !== "")
                        delegate: Rectangle {
                            required property string modelData
                            width: chip.implicitWidth + 16 * root.s; height: 24 * root.s
                            radius: 6 * root.s
                            color: Qt.alpha(Theme.text, 0.07)
                            Text { id: chip; anchors.centerIn: parent; text: modelData; color: Theme.text; font { family: root.pf; pixelSize: 11 * root.s } }
                        }
                    }
                }
            }

            LockCard {
                id: notes
                width: parent.width; s: root.s; delay: 370; from: 40 * root.s
                glyph: "󰂚"; title: "Notifications"
                note: Notifs.list.length ? "" + Notifs.list.length : ""
                Text {
                    visible: Notifs.list.length === 0
                    text: "All caught up"
                    color: Theme.text; opacity: 0.55
                    font { family: root.pf; pixelSize: 12 * root.s }
                }
                Repeater {
                    model: Notifs.list.slice(0, 4)
                    delegate: Column {
                        required property var modelData
                        width: notes.width - 32 * root.s
                        spacing: 2 * root.s
                        Text { text: (modelData.appName || "Notification").toUpperCase(); color: Theme.coral; font { family: root.pf; pixelSize: 10 * root.s; letterSpacing: 1.5 * root.s } }
                        Text { width: parent.width; text: modelData.summary || ""; elide: Text.ElideRight; color: Theme.text; font { family: root.pf; pixelSize: 12 * root.s } }
                    }
                }
            }
        }

        // ======== centre: music ========
        Item {
            id: music
            visible: root.player !== null && (root.player.trackTitle || "") !== ""
            width: 410 * root.s; height: 132 * root.s
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 20 * root.s }
            property real shown: 0
            opacity: shown
            scale: 0.94 + 0.06 * shown
            Component.onCompleted: musicIn.start()
            SequentialAnimation { id: musicIn; PauseAnimation { duration: 260 } NumberAnimation { target: music; property: "shown"; to: 1; duration: 650; easing.type: Easing.OutBack } }

            // the glow: the cover, blurred big behind the card
            Image {
                id: glowSrc
                anchors.fill: parent
                source: art.source
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            MultiEffect {
                anchors { fill: parent; margins: -24 * root.s }
                source: glowSrc
                visible: art.status === Image.Ready
                blurEnabled: true; blurMax: 64; blur: 1
                saturation: 0.4
                opacity: root.player && root.player.isPlaying ? 0.55 : 0.3
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }
            Rectangle {
                anchors.fill: parent
                radius: 16 * root.s
                color: Qt.alpha(Theme.surface, 0.62)
                border { width: 1; color: Qt.alpha(Theme.text, 0.1) }
            }
            Rectangle {                          // cover
                id: cover
                anchors { left: parent.left; leftMargin: 16 * root.s; verticalCenter: parent.verticalCenter }
                width: 100 * root.s; height: width; radius: 10 * root.s
                color: Theme.raised
                Text { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "󰝚"; color: Theme.muted; font { family: root.pf; pixelSize: 34 * root.s } }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player ? (root.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask }
                }
                Rectangle { id: coverMask; anchors.fill: parent; radius: cover.radius; visible: false; layer.enabled: true }
            }
            Column {
                anchors { left: cover.right; leftMargin: 16 * root.s; right: parent.right; rightMargin: 16 * root.s; verticalCenter: parent.verticalCenter }
                spacing: 6 * root.s
                Item {
                    width: parent.width; height: title.implicitHeight
                    Text {
                        id: title
                        width: parent.width - eq.width - 10 * root.s
                        text: root.player ? root.player.trackTitle : ""
                        color: Theme.text
                        elide: Text.ElideRight
                        font { family: root.pf; pixelSize: 17 * root.s }
                    }
                    Row {                        // equaliser: dances while playing
                        id: eq
                        anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 3 * root.s }
                        spacing: 2 * root.s
                        Repeater {
                            model: [430, 310, 520, 370]
                            delegate: Rectangle {
                                required property int modelData
                                width: 3 * root.s; radius: 1
                                height: 4 * root.s
                                anchors.bottom: parent.bottom
                                color: Theme.coral
                                SequentialAnimation on height {
                                    loops: Animation.Infinite
                                    running: root.player !== null && root.player.isPlaying
                                    NumberAnimation { to: 14 * root.s; duration: modelData; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 4 * root.s; duration: modelData * 0.8; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
                    color: Theme.muted
                    elide: Text.ElideRight
                    font { family: root.pf; pixelSize: 12 * root.s }
                }
                Item {                           // progress (when the player reports a length)
                    width: parent.width; height: 14 * root.s
                    visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
                    Timer { interval: 1000; repeat: true; running: music.visible && root.player && root.player.isPlaying; onTriggered: root.player.positionChanged() }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: Math.max(1, 2 * root.s); radius: height; color: Qt.alpha(Theme.text, 0.15) }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                        height: Math.max(1, 2 * root.s); radius: height
                        color: Theme.coral
                        Behavior on width { NumberAnimation { duration: 900 } }
                    }
                }
                Item {
                    width: parent.width; height: 28 * root.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.player && root.player.lengthSupported && root.player.length > 0 ? root.mmss(root.player.position) + " / " + root.mmss(root.player.length) : ""
                        color: Theme.dim
                        font { family: root.pf; pixelSize: 10 * root.s }
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 4 * root.s
                        Repeater {
                            model: [
                                { g: "󰒮", act: "previous", show: root.player && root.player.canGoPrevious },
                                { g: root.player && root.player.isPlaying ? "󰏤" : "󰐊", act: "toggle", show: true },
                                { g: "󰒭", act: "next", show: root.player && root.player.canGoNext }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 28 * root.s; height: width; radius: 6 * root.s
                                color: btn.containsMouse ? Qt.alpha(Theme.text, 0.12) : modelData.act === "toggle" ? Qt.alpha(Theme.coral, 0.18) : "transparent"
                                opacity: modelData.show ? 1 : 0.3
                                Text { anchors.centerIn: parent; text: modelData.g; color: modelData.act === "toggle" ? Theme.coral : Theme.text; font { family: root.pf; pixelSize: 15 * root.s } }
                                MouseArea {
                                    id: btn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: modelData.show
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const p = root.player
                                        if (modelData.act === "previous") p.previous()
                                        else if (modelData.act === "next") p.next()
                                        else p.togglePlaying()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ======== centre bottom: name, password, face note ========
        Column {
            id: panel
            anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: shakeX; bottom: parent.bottom; bottomMargin: 92 * root.s }
            width: 300 * root.s
            spacing: 12 * root.s
            property real shakeX: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.name.toUpperCase()
                color: Theme.text
                font.family: root.pf; font.pixelSize: Math.round(22 * root.s)
                font.letterSpacing: 3 * root.s
            }
            Item {
                width: parent.width
                height: 34 * root.s
                TextInput {
                    id: pw
                    anchors { left: parent.left; right: arrow.left; rightMargin: 12 * root.s; verticalCenter: parent.verticalCenter }
                    color: "transparent"
                    echoMode: TextInput.NoEcho
                    font { family: root.pf; pixelSize: 14 * root.s }
                    focus: true
                    clip: true
                    cursorVisible: false
                    cursorDelegate: Item {}
                    enabled: !root.busy
                    Keys.onReturnPressed: root.go()
                    Keys.onEnterPressed: root.go()
                    Keys.onEscapePressed: text = ""
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space && text.length === 0 && (root.face === "ready" || root.face === "miss")) { root.faceRetry(); event.accepted = true }
                    }
                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 8 * root.s
                        Repeater {
                            model: pw.text.length
                            delegate: Text { text: "✦"; color: Theme.text; font: pw.font }
                        }
                        Text {
                            id: star
                            text: "✦"
                            color: Theme.coral
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
                        color: Theme.text
                        opacity: pw.text.length === 0 && !pw.activeFocus ? 0.3 : 0
                        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutSine } }
                        font { family: root.pf; pixelSize: 14 * root.s; letterSpacing: 2 * root.s }
                    }
                }
                MouseArea { anchors.fill: pw; cursorShape: Qt.IBeamCursor; onClicked: pw.forceActiveFocus() }
                Text {
                    id: arrow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root.busy ? "…" : "→"
                    color: Theme.coral
                    font { family: root.pf; pixelSize: 16 * root.s }
                    opacity: pw.text.length > 0 ? 1.0 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.go() }
                }
            }
            Rectangle {                          // the line: dims while the face light glides along it, fills on a match
                width: parent.width
                height: Math.max(1, root.s)
                color: pw.activeFocus && root.face !== "scan" && root.face !== "ok" ? Theme.coral : Theme.dim
                Behavior on color { ColorAnimation { duration: 300 } }
                clip: true
                Rectangle {
                    id: glint
                    width: 70 * root.s; height: parent.height
                    opacity: root.face === "scan" ? 0.9 : 0
                    Behavior on opacity { NumberAnimation { duration: 500 } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Theme.text }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    NumberAnimation on x {
                        loops: Animation.Infinite
                        running: glint.opacity > 0
                        from: -glint.width; to: glint.parent.width
                        duration: 1800; easing.type: Easing.InOutSine
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    width: root.face === "ok" ? parent.width : 0
                    color: Theme.text
                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }
            }
            Text {                               // face unlock note
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.face === "ready" ? "Press space for face unlock" : root.face === "scan" ? "Looking for you…"
                    : root.face === "ok" ? "Welcome back" : root.face === "miss" ? "Didn't recognise you · space to try again" : " "
                color: Theme.text
                font { family: root.pf; pixelSize: 11 * root.s; letterSpacing: 1 * root.s }
                opacity: root.face !== "" ? (noteMa.containsMouse ? 0.85 : 0.5) : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                MouseArea {
                    id: noteMa
                    anchors.fill: parent
                    hoverEnabled: root.face === "ready" || root.face === "miss"
                    enabled: hoverEnabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.faceRetry(); pw.forceActiveFocus() }
                }
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

        // ======== bottom: when it locked (left), power (right) ========
        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 40 * root.s }
            text: "󰌾  locked since " + since
            readonly property string since: Qt.formatTime(new Date(), "HH:mm")   // set once, when the lock appears
            color: Theme.text; opacity: 0.35
            font { family: root.pf; pixelSize: 11 * root.s; letterSpacing: 1 * root.s }
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; margins: 40 * root.s }
            spacing: 28 * root.s
            Repeater {
                model: [{ label: "Restart", act: "reboot" }, { label: "Shut Down", act: "poweroff" }]
                delegate: Text {
                    required property var modelData
                    text: modelData.label
                    color: Theme.text
                    opacity: ma.containsMouse ? 0.9 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    font { family: root.pf; pixelSize: 12 * root.s; letterSpacing: 1 * root.s }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.power(modelData.act) }
                }
            }
        }
    }
}

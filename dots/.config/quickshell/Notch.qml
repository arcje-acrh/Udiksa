// Notch.qml -- the notch and its panel engine (Dynamic-Island style, user design 2026-09-25).
//   Resting: one slim row: workspaces, now playing, window title, clock (centre), status icons.
//   Panels: hovering an item (Theme.hoverOpenDelay) or clicking it GROWS the notch downward to that
//     panel's height (Theme.panelHeight) and shows ONLY that panel (the top row fades out). GROW ONLY:
//     a panel is never narrower than the resting notch. It closes Theme.hoverCloseDelay after the mouse
//     leaves the notch (or Esc). Only the open panel is loaded (nothing runs for closed ones).
//   Key feedback (volume, mute, mic, brightness, keyboard light, Caps/Num Lock; data in Osd.qml): the
//     notch does NOT grow; the clock slides to the left, everything else fades, and the level bar shows
//     in the slim notch for Theme.feedbackTime. An open panel wins over key feedback.
// It hangs from the top edge: concave ears + coral outline + light shadow (deeper while a panel is open).
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    readonly property real ear: Theme.islandRadius     // the concave top corners where it meets the screen edge = the same radius as its bottom corners (Settings > Windows > Corners)
    property int restWidth: 800            // set by Bar.qml (Theme.notchFraction x screen width, at least minRestWidth)
    property int maxWidth: 100000          // set by Bar.qml: the screen width minus a margin (portrait / small screens)
    // the least the resting row needs so nothing overlaps: the clock in the middle, with room on each side for the
    // wider of workspaces (left) and status icons (right); now playing / window title shrink or hide by themselves
    readonly property int minRestWidth: Math.ceil(clockRow.width + 2 * Math.max(20 + workspaces.width + 18, 24 + statusIcons.width + 18) + 12)

    // ---------- panel state ----------
    property string panel: ""              // open panel id ("" = resting)
    property string loaded: ""             // panel whose content exists (kept until the close animation ends)
    property string pending: ""            // hovered item waiting for the open delay
    readonly property bool feedback: Osd.shown && panel === ""
    // a new notification shows inline (Notifs.qml) unless a panel is open or a key feedback is showing
    readonly property bool notifShow: Notifs.fresh && Notifs.current !== null && panel === "" && !Osd.shown
    readonly property bool inlineMode: feedback || notifShow   // clock to the left, resting items away

    property bool pinned: false            // opened by NotchCtl (keybind/script): no hover-close until hovered once
    // opened by a click (or keybind/launcher), not by hovering: a click OUTSIDE the notch closes it
    // (Bar.qml's focus grab). Hover-opened panels close when the mouse leaves instead, and never grab.
    property bool clickOpened: false

    function hoverIn(id) { if (panel !== "") return; pending = id; openTimer.restart() }
    function hoverOut(id) { if (panel === "" && pending === id) openTimer.stop() }
    function open(id) {
        clickOpened = true
        if (Theme.panelHeight[id] === undefined) return
        openTimer.stop(); unloadTimer.stop(); pinned = false; loaded = id; panel = id
    }
    function close() { panel = ""; pinned = false; unloadTimer.restart() }

    Connections {
        target: NotchCtl
        function onOpenRequested(id) { root.open(id); root.pinned = true }
        function onToggleRequested(id) { if (root.panel === id) root.close(); else { root.open(id); root.pinned = true } }
        function onCloseRequested() { root.close() }
    }

    Timer { id: openTimer; interval: Theme.hoverOpenDelay; onTriggered: { root.open(root.pending); root.clickOpened = false } }
    Timer { id: unloadTimer; interval: Theme.notchAnim; onTriggered: if (root.panel === "") root.loaded = "" }
    HoverHandler { id: hover; onHoveredChanged: if (hovered) root.pinned = false }
    Timer {
        interval: Theme.hoverCloseDelay
        running: root.panel !== "" && !hover.hovered && !root.pinned && !root.panelBusy
        onTriggered: root.close()
    }
    focus: true
    Keys.onEscapePressed: root.close()

    // a panel may ask for more room (e.g. the Wi-Fi sign-in form) with `wantHeight`, and may hold the
    // notch open with `busy` (e.g. while you type a password) -- both optional properties of the panel
    readonly property var panelItem: panelLoader.item
    readonly property int panelH: loaded === "" ? 0
        : (panelItem && panelItem.wantHeight > 0 ? panelItem.wantHeight : Theme.panelHeight[loaded])
    readonly property bool panelBusy: panelItem !== null && panelItem.busy === true

    // grow only: a wide panel (e.g. System) asks for more width with `wantWidth`; a new notification
    // makes the notch "breathe" a little wider while it shows
    // ... but never wider than the screen (a rotated / small screen): the panel's own layout shrinks with it
    readonly property int panelW: loaded === "" || !panelItem || !(panelItem.wantWidth > 0) ? restWidth : Math.min(maxWidth, Math.max(restWidth, panelItem.wantWidth))
    // inline notification (line breaks -> " · "): the notch grows a little wider (80..200 px extra), and TALLER for a
    // long text (wraps to at most 3 lines) instead of ever wider
    readonly property string notifText: Notifs.current
        ? ((Notifs.current.summary || "") + (Notifs.current.body ? "  " + Notifs.current.body : "")).replace(/<[^>]*>/g, "").replace(/\s*\n+\s*/g, "  ·  ")
        : ""
    TextMetrics { id: nfMetrics; font.family: Theme.font; font.pixelSize: 12; text: root.notifText }
    readonly property int notifExtra: Math.max(80, Math.min(200, Math.ceil(20 + clockRow.width + 28 + 18 + 10 + nfApp.implicitWidth + 10
        + nfMetrics.advanceWidth + (Notifs.unread > 1 ? 40 : 0) + 24 - restWidth)))
    // the text's room (the notch at its target width, minus clock, icon, app name, +N) and how many lines it needs there
    readonly property real nfTextW: Math.max(120, restWidth + notifExtra - (20 + clockRow.width + 28) - 24 - 18 - nfApp.implicitWidth - (Notifs.unread > 1 ? 50 : 0) - 20)
    readonly property string notifSummary: Notifs.current ? (Notifs.current.summary || "").replace(/<[^>]*>/g, "").replace(/\s*\n+\s*/g, "  ") : ""
    readonly property string notifBody: Notifs.current ? (Notifs.current.body || "").replace(/<[^>]*>/g, "").replace(/\s*\n+\s*/g, "  ") : ""
    Text { id: nfProbe; visible: false; width: root.nfTextW; wrapMode: Text.WordWrap; maximumLineCount: 2; text: root.notifText
           font.family: Theme.font; font.pixelSize: 12 }
    // body under the title row, as wide as the notification from the icon's right edge on
    Text { id: nfBodyProbe; visible: false; width: root.nfTextW + nfApp.implicitWidth + 10; wrapMode: Text.WordWrap; maximumLineCount: 2
           text: root.notifBody; font.family: Theme.font; font.pixelSize: 12 }
    // tall = it does not fit on one line AND there is a body: title row on top (like a short one), the body under it
    readonly property bool notifTall: notifBody !== "" && nfProbe.lineCount > 1
    readonly property int notifH: notifTall ? nfBodyProbe.lineCount * 16 + 1 : 0
    width: panel !== "" ? panelW : Math.min(maxWidth, restWidth + (notifShow ? notifExtra : 0))
    // smooth for panels (opening AND closing: `loaded` stays set until the close has finished); the
    // little overshoot "breath" only for an inline notification
    Behavior on width {
        NumberAnimation {
            duration: root.loaded !== "" ? Theme.notchAnim : Theme.notchAnim + 120
            easing.type: root.loaded !== "" ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 1.4
        }
    }
    height: panel !== "" ? panelH : Theme.stripHeight + (notifShow ? notifH : 0)
    Behavior on height { NumberAnimation { duration: Theme.notchAnim; easing.type: Easing.OutCubic } }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---------- shape ----------
    Rectangle { id: sizer; anchors.fill: parent; color: "transparent"; radius: Theme.islandRadius }
    // soft shadow BELOW the notch only: it starts well under the top edge (so nothing bleeds sideways along
    // the screen edge next to the ears) and is much lighter on light themes (user 2026-09-26: "weird shadow")
    RectangularShadow {
        anchors.fill: sizer
        anchors.topMargin: Math.min(sizer.height * 0.5, 40)
        anchors.leftMargin: 10; anchors.rightMargin: 10
        radius: Theme.islandRadius
        blur: root.panel !== "" ? 26 : 12
        offset: Qt.vector2d(0, root.panel !== "" ? 6 : 2)
        color: Qt.alpha(Theme.shadow, Theme.light ? (root.panel !== "" ? 0.14 : 0.06) : (root.panel !== "" ? 0.36 : 0.18))
        Behavior on blur { NumberAnimation { duration: Theme.notchAnim } }
    }

    // ONE outline: concave ears -> sides -> rounded bottom corners -> ears. Filled with the
    // background colour, stroked in coral (open path: no line along the screen edge). Follows the size.
    readonly property real r: Theme.islandRadius
    readonly property real e: ear
    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // fill (closed along the top edge)
            fillColor: Theme.bg; strokeColor: "transparent"
            startX: -root.e; startY: 0
            PathArc { x: 0; y: root.e; radiusX: root.e; radiusY: root.e; direction: PathArc.Clockwise }
            PathLine { x: 0; y: root.height - root.r }
            PathArc { x: root.r; y: root.height; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
            PathLine { x: root.width - root.r; y: root.height }
            PathArc { x: root.width; y: root.height - root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
            PathLine { x: root.width; y: root.e }
            PathArc { x: root.width + root.e; y: 0; radiusX: root.e; radiusY: root.e; direction: PathArc.Clockwise }
            PathLine { x: -root.e; y: 0 }
        }
        ShapePath {   // coral outline (open)
            fillColor: "transparent"; strokeColor: Qt.alpha(Theme.coral, 0.6); strokeWidth: 1.5
            startX: -root.e; startY: 0
            PathArc { x: 0; y: root.e; radiusX: root.e; radiusY: root.e; direction: PathArc.Clockwise }
            PathLine { x: 0; y: root.height - root.r }
            PathArc { x: root.r; y: root.height; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
            PathLine { x: root.width - root.r; y: root.height }
            PathArc { x: root.width; y: root.height - root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
            PathLine { x: root.width; y: root.e }
            PathArc { x: root.width + root.e; y: 0; radiusX: root.e; radiusY: root.e; direction: PathArc.Clockwise }
        }
    }

    // ---------- the resting top row ----------
    Item {
        id: strip
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.stripHeight
        // coming back after a panel: only once the notch is back at its resting width (a wide panel
        // shrinks sideways), so the clock and icons never slide or overlap
        readonly property bool settled: Math.abs(root.width - Math.min(root.maxWidth, root.restWidth + (root.notifShow ? root.notifExtra : 0))) < 1.5
                                         && (root.height < Theme.stripHeight + 1.5 || root.notifShow)
        opacity: root.panel === "" && settled ? 1 : 0
        enabled: root.panel === ""
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // everything except the clock steps aside for key feedback
        Item {
            anchors.fill: parent
            opacity: root.inlineMode ? 0 : 1
            enabled: !root.inlineMode
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Workspaces {
                id: workspaces
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
            }
            // room between the workspaces and the clock, shared by now playing and the window title
            readonly property real leftSpace: width / 2 - clockRow.width / 2 - 26 - (workspaces.x + workspaces.width + 18)
            MediaChip {
                id: media
                anchors.left: workspaces.right; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                maxTextWidth: Math.max(0, Math.min(160, parent.leftSpace - 30))
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIn("media"); onExited: root.hoverOut("media"); onClicked: root.open("media")
                }
            }
            WindowTitle {   // gets what now playing leaves; hidden when that is too little to read
                readonly property real room: parent.leftSpace - media.width - 24
                visible: room >= 60
                anchors.right: parent.horizontalCenter; anchors.rightMargin: clockRow.width / 2 + 26
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Math.min(implicitWidth, room))
                horizontalAlignment: Text.AlignRight
            }
            Status {
                id: statusIcons
                anchors.right: parent.right; anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                openPanel: root.panel
                onHoverIn: (id) => root.hoverIn(id)
                onHoverOut: (id) => root.hoverOut(id)
                onClicked: (id) => root.open(id)
            }
        }

        // clock: centre at rest, slides to the left edge during key feedback
        Row {
            id: clockRow
            // only the slide to the left (key feedback / notification) is animated, via `shift`;
            // width changes (panels opening / closing) move it instantly with the notch -- animating
            // x itself made the date trail behind and slide after the notch had settled
            property real shift: root.inlineMode ? 1 : 0
            Behavior on shift { NumberAnimation { duration: Theme.notchAnim; easing.type: Easing.OutCubic } }
            x: 20 * shift + (parent.width - width) / 2 * (1 - shift)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.text
                font.family: Theme.font; font.pixelSize: 15; font.bold: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                color: Theme.muted
                font.family: Theme.font; font.pixelSize: 12
            }
            Text {   // running countdown timer (Agenda.qml): time left, amber while paused
                visible: Agenda.timerOn
                anchors.verticalCenter: parent.verticalCenter
                property real tick: Date.now()
                Timer { interval: 1000; repeat: true; running: Agenda.timerOn && !Agenda.timerPaused; onTriggered: parent.tick = Date.now() }
                text: "󱎫 " + Agenda.fmt(Agenda.timerPaused ? Agenda.timerLeft : Agenda.timerEnd - tick)
                color: Agenda.timerPaused ? Theme.amber : Theme.coral
                font.family: Theme.font; font.pixelSize: 12; font.bold: true
            }
        }
        MouseArea {
            anchors.fill: clockRow; anchors.margins: -6
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled: !root.inlineMode
            onEntered: root.hoverIn("clock"); onExited: root.hoverOut("clock"); onClicked: root.open("clock")
        }

        // inline key feedback -- inside the slim notch, in the space right of the clock.
        //   level (volume, brightness, ...): icon, bar, value fill that space
        //   on/off (mic, Caps/Num Lock, airplane): icon + text, centred in that space
        Item {
            id: fb
            x: 20 + clockRow.width + 28
            width: parent.width - x - 24
            height: parent.height
            opacity: root.feedback ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.feedback ? Theme.notchAnim * 0.35 : 0 }
                    NumberAnimation { duration: 160 }
                }
            }
            Row {
                visible: Osd.showBar
                anchors.fill: parent
                spacing: 12
                Text {
                    id: fbIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; horizontalAlignment: Text.AlignHCenter
                    text: Osd.icon
                    color: Osd.off ? Theme.dim : Theme.text
                    font.family: Theme.font; font.pixelSize: 16
                }
                LedBar {   // track: retro LED segments; volume above 100 % in amber
                    anchors.verticalCenter: parent.verticalCenter
                    width: fb.width - fbIcon.width - fbVal.width - 2 * parent.spacing
                    segH: 12
                    readonly property bool hasMark: Osd.mark > 0 && Osd.mark < 1
                    frac: hasMark ? Osd.level : Osd.level
                    safeFrac: hasMark ? Osd.mark : 1
                    off: Osd.off
                }
                Text {
                    id: fbVal
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110; horizontalAlignment: Text.AlignRight
                    text: Osd.label
                    color: Osd.off ? Theme.muted : Theme.text
                    font.family: Theme.font; font.pixelSize: 13; font.bold: true
                }
            }
            Row {
                visible: !Osd.showBar
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Osd.icon
                    color: Osd.off ? Theme.dim : (Osd.warn ? Theme.amber : Theme.coral)
                    font.family: Theme.font; font.pixelSize: 16
                }
                Rectangle {   // picked colour
                    visible: Osd.swatch !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 2
                    color: Osd.swatch !== "" ? Osd.swatch : "transparent"
                    border.width: 1; border.color: Theme.hover
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Osd.label
                    color: Osd.off ? Theme.muted : (Osd.warn ? Theme.amber : Theme.text)
                    font.family: Theme.font; font.pixelSize: 13; font.bold: true
                }
            }
        }

        // inline notification -- a new one pops in right of the clock: icon, app, message, +N.
        // Hover (or click) = the notifications panel; the mouse on it keeps it showing.
        Item {
            id: nf
            x: 20 + clockRow.width + 28
            width: parent.width - x - 24
            height: root.height             // taller than the strip when the text wraps
            opacity: root.notifShow ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.notifShow ? Theme.notchAnim * 0.35 : 0 }
                    NumberAnimation { duration: 180 }
                }
            }
            HoverHandler { onHoveredChanged: Notifs.hold = hovered }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: root.hoverIn("notifications"); onExited: root.hoverOut("notifications")
                onClicked: root.open("notifications")
            }
            Row {
                id: nfRow
                anchors.top: parent.top
                height: Theme.stripHeight          // the title row: level with the clock; a tall body goes under it
                width: parent.width
                spacing: 10
                Item {   // app icon, pops in
                    id: nfIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    scale: root.notifShow ? 1 : 0.4
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    IconImage {
                        id: nfImg
                        anchors.fill: parent
                        source: Notifs.iconFor(Notifs.current)
                        visible: source != ""
                    }
                    Text {   // no icon: a bell
                        visible: !nfImg.visible
                        anchors.centerIn: parent
                        text: "󰂚"; color: Notifs.currentCritical ? Theme.warn : Theme.coral
                        font.family: Theme.font; font.pixelSize: 16
                    }
                }
                Text {
                    id: nfApp
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.current ? (Notifs.current.appName || "Notification") : ""
                    color: Notifs.currentCritical ? Theme.warn : Theme.coral
                    font.family: Theme.font; font.pixelSize: 12; font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - nfIcon.width - nfApp.width - (nfMore.visible ? nfMore.width + 10 : 0) - 2 * parent.spacing
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    text: root.notifTall ? root.notifSummary : root.notifText
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: root.notifTall
                }
                Rectangle {   // "+N" more unread
                    id: nfMore
                    visible: Notifs.unread > 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: nfMoreT.implicitWidth + 12; height: 18; radius: 9
                    color: Qt.alpha(Theme.coral, 0.2)
                    Text { id: nfMoreT; anchors.centerIn: parent; text: "+" + (Notifs.unread - 1); color: Theme.coral; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                }
            }
            Text {   // tall notification: the body, under the title row, left edge = the app name
                visible: root.notifTall
                x: nfIcon.width + nfRow.spacing
                y: Theme.stripHeight - 4
                width: parent.width - x
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                text: root.notifBody
                color: Qt.alpha(Theme.text, 0.8); font.family: Theme.font; font.pixelSize: 12
            }
        }
    }

    // ---------- the open panel ----------
    // contents fade in once the notch has mostly grown, and fade out at once when it closes
    property bool contentShown: false
    onPanelChanged: { if (panel === "") contentShown = false; else showContent.restart() }
    Timer { id: showContent; interval: Theme.notchAnim * 0.45; onTriggered: root.contentShown = root.panel !== "" }
    Item {
        anchors.fill: parent
        clip: true
        opacity: root.contentShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.contentShown ? 200 : 110 } }
        Loader {
            id: panelLoader
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: root.panelH                // the panel's own size (the notch reveals it while growing)
            active: root.loaded !== ""
            sourceComponent: ({
                battery: batteryPanel, power: powerPanel, volume: volumePanel, wifi: wifiPanel,
                bluetooth: bluetoothPanel, clock: clockPanel, media: mediaPanel, notifications: notificationsPanel, system: systemPanel, tailscale: tailscalePanel, launcher: launcherPanel, usage: usagePanel
            })[root.loaded] ?? null
        }
    }
    Component { id: batteryPanel;   BatteryPanel {} }
    Component { id: powerPanel;     PowerPanel { onDone: root.close() } }
    Component { id: volumePanel;    VolumePanel {} }
    Component { id: wifiPanel;      WifiPanel {} }
    Component { id: bluetoothPanel; BluetoothPanel {} }
    Component { id: clockPanel;     ClockPanel {} }
    Component { id: mediaPanel;     MediaPanel {} }
    Component { id: notificationsPanel; NotificationsPanel {} }
    Component { id: systemPanel;    SystemPanel { onOpenPanel: (id) => root.open(id) } }
    Component { id: usagePanel;     UsagePanel {} }
    Component { id: tailscalePanel; TailscalePanel {} }
    Component { id: launcherPanel;  LauncherPanel { onDone: root.close() } }
}

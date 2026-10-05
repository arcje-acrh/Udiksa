// ThemeSwitcher.qml -- the theme + wallpaper switcher, FULL SCREEN (user 2026-09-26: no pop-up sheet).
// Super+T (`qs ipc call themes toggle`); Super+Shift+T = next wallpaper (udiksa theme next).
//   A row of tall parallelograms across the middle of the screen, edge to edge (no gaps), the active one large in the
//   centre with its details (name, colour dots, dark/light, wallpapers, where the colours come from). Behind it:
//   the highlighted wallpaper, blurred and darkened, cross-fading as you browse.
//   step 1  themes           step 2  that theme's wallpapers; Enter/click applies: the wallpaper grows out
//                                    from the centre (awww) while every colour switches (udiksa theme apply).
//   keys    ← → (or wheel) browse, Enter pick, Esc / Backspace back or close, Home = the theme in use
// Data: `udiksa theme list` (themes, wallpapers, 640x400 previews in ~/.cache/rice/thumbs, swatches).
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property bool shown: false            // on screen (open, or still fading out)
    property var themes: []
    property int step: 1                  // 1 themes, 2 wallpapers
    property int themeIdx: 0
    property string currentWall: ""
    readonly property var theme: themes.length ? themes[Math.max(0, Math.min(themeIdx, themes.length - 1))] : null
    readonly property string exe: Quickshell.env("HOME") + "/.local/lib/udiksa/theme"
    function toggle() { if (open) close(); else show() }
    function show() { lister.running = true; step = 1; open = true; shown = true }
    function close() { open = false; hideTimer.restart() }
    Timer { id: hideTimer; interval: 380; onTriggered: if (!root.open) root.shown = false }

    Process {
        id: lister
        command: [root.exe, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.themes = j.themes
                    root.currentWall = j.current && j.current.wallpaper ? j.current.wallpaper : ""
                    const i = j.themes.findIndex(t => t.current)
                    root.themeIdx = i >= 0 ? i : 0
                    strip.currentIndex = root.themeIdx
                    strip.rise()
                } catch (e) { root.themes = [] }
            }
        }
    }
    Process { id: applier }
    function apply(path) {
        applier.command = [root.exe, "apply", path, "--pos", "0.500,0.500"]
        applier.running = true
        close()
    }
    function pick(i) {
        if (step === 1) {
            themeIdx = i
            step = 2
            const cur = themes[i].wallpapers.indexOf(currentWall)
            strip.currentIndex = cur >= 0 ? cur : 0
            strip.rise()
        } else if (theme) {
            apply(theme.wallpapers[i])
        }
    }
    function back() {
        if (step === 2) { step = 1; strip.currentIndex = themeIdx; strip.rise() }
        else close()
    }
    function toCurrent() {
        const i = themes.findIndex(t => t.current)
        if (step === 1 && i >= 0) strip.currentIndex = i
    }

    // the item under the centre: a theme (step 1) or a wallpaper (step 2)
    readonly property var hiTheme: step === 1 ? themes[strip.currentIndex] : theme
    readonly property string hiThumb: {
        if (step === 2) return theme && theme.thumbs ? (theme.thumbs[strip.currentIndex] || "") : ""
        const t = themes[strip.currentIndex]
        if (!t || !t.thumbs || !t.thumbs.length) return ""
        const i = t.current ? t.wallpapers.indexOf(currentWall) : -1
        return t.thumbs[i >= 0 ? i : 0]
    }

    IpcHandler {
        target: "themes"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.close() }
    }

    PanelWindow {
        id: win
        visible: root.shown
        WlrLayershell.namespace: "shell-themes"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusiveZone: -1
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"

        CornerArcs { z: 100; opacity: stage.opacity }   // rounded screen corners stay while it covers the screen

        Item {
            id: stage
            anchors.fill: parent
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.open ? 260 : 300; easing.type: Easing.OutCubic } }
            focus: root.open
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Left) { strip.decrementCurrentIndex(); e.accepted = true }
                else if (e.key === Qt.Key_Right) { strip.incrementCurrentIndex(); e.accepted = true }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.pick(strip.currentIndex); e.accepted = true }
                else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Backspace) { root.back(); e.accepted = true }
                else if (e.key === Qt.Key_Home) { root.toCurrent(); e.accepted = true }
            }

            // ---------- backdrop: the highlighted wallpaper, blurred + darkened, cross-fading ----------
            Rectangle { anchors.fill: parent; color: Theme.bg }
            Item {
                id: backdrop
                anchors.fill: parent
                property string src: root.hiThumb
                property bool flip: false
                onSrcChanged: { flip = !flip; (flip ? bgA : bgB).source = src ? "file://" + src : "" }
                Image { id: bgA; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 640; visible: false }
                Image { id: bgB; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 640; visible: false }
                MultiEffect {
                    anchors.fill: parent; source: bgA
                    blurEnabled: true; blur: 1.0; blurMax: 64; saturation: -0.1
                    opacity: backdrop.flip ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 420 } }
                }
                MultiEffect {
                    anchors.fill: parent; source: bgB
                    blurEnabled: true; blur: 1.0; blurMax: 64; saturation: -0.1
                    opacity: backdrop.flip ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 420 } }
                }
            }
            Rectangle { anchors.fill: parent; color: Theme.bg; opacity: Theme.light ? 0.45 : 0.62 }
            MouseArea { anchors.fill: parent; onClicked: root.close() }     // click outside the cards = close

            // ---------- top line: where you are + count ----------
            Text {
                x: 64; y: 54
                text: root.step === 1 ? "THEMES" : "THEMES  ›  " + (root.theme ? root.theme.name.toUpperCase() : "") + "  ›  WALLPAPERS"
                color: Theme.muted; font.family: Theme.font; font.pixelSize: 13; font.bold: true; font.letterSpacing: 3
            }
            Row {   // position: one LED per item, the current one lit (retro, like the notch's level bars)
                anchors.right: parent.right; anchors.rightMargin: 64; y: 52
                spacing: 10
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: strip.count
                        delegate: Rectangle {
                            required property int index
                            readonly property bool lit: index === strip.currentIndex
                            width: 4; height: 14; radius: 1
                            color: lit ? Theme.coral : Theme.raised
                            Rectangle { visible: parent.lit; anchors.fill: parent; anchors.margins: -2; radius: 2; z: -1; color: Qt.alpha(Theme.coral, 0.3) }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(strip.currentIndex + 1).padStart(2, "0") + "/" + String(strip.count).padStart(2, "0")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 14; font.bold: true
                }
            }

            // ---------- the parallelogram strip ----------
            PathView {
                id: strip
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -40
                height: hexH * 1.5
                // tall parallelograms (user 2026-09-26): neighbours share their slanted sides, so the row has no
                // gaps. Item width = top side + slant; spacing along the track = width - slant.
                readonly property real hexW: 300
                readonly property real hexH: 420
                readonly property real slant: 64
                readonly property real pitch: hexW - slant
                readonly property real bigScale: 1.42
                model: root.step === 1 ? root.themes
                     : (root.theme ? root.theme.wallpapers.map((w, i) => ({ path: w, thumb: root.theme.thumbs[i] })) : [])
                pathItemCount: Math.min(count, Math.ceil(width / pitch) + 2)
                preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 380
                snapMode: PathView.SnapToItem
                readonly property real span: pathItemCount * pitch
                path: Path {
                    startX: strip.width / 2 - strip.span / 2; startY: strip.height / 2
                    PathLine { x: strip.width / 2 + strip.span / 2; y: strip.height / 2 }
                }
                // one entrance motion when the strip (re)fills: every hexagon rises into place, from the centre out
                property int riseTick: 0
                function rise() { riseTick++ }
                WheelHandler {
                    onWheel: (w) => { if (w.angleDelta.y + w.angleDelta.x > 0) strip.decrementCurrentIndex(); else strip.incrementCurrentIndex() }
                }

                delegate: Item {
                    id: hex
                    required property var modelData
                    required property int index
                    readonly property bool isCur: PathView.isCurrentItem
                    readonly property string thumbSrc: {
                        if (root.step !== 1) return modelData.thumb || ""
                        const i = modelData.current ? modelData.wallpapers.indexOf(root.currentWall) : -1
                        return modelData.thumbs ? modelData.thumbs[i >= 0 ? i : 0] : ""
                    }
                    width: strip.hexW; height: strip.hexH
                    z: isCur ? 10 : 1
                    scale: isCur ? strip.bigScale : 1.0
                    Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                    // rise-in (staggered by distance from the centre)
                    property real lift: 0
                    transform: Translate { y: hex.lift }
                    Connections {
                        target: strip
                        function onRiseTickChanged() {
                            const d = Math.abs(hex.index - strip.currentIndex)
                            riseAnim.stop(); hex.lift = 90; hex.opacity = 0
                            riseDelay.duration = Math.min(d, 8) * 45
                            riseAnim.start()
                        }
                    }
                    SequentialAnimation {
                        id: riseAnim
                        PauseAnimation { id: riseDelay; duration: 0 }
                        ParallelAnimation {
                            NumberAnimation { target: hex; property: "lift"; to: 0; duration: 520; easing.type: Easing.OutCubic }
                            NumberAnimation { target: hex; property: "opacity"; to: 1; duration: 360 }
                        }
                    }

                    // the parallelogram (shape below): mask + outline
                    readonly property real cut: 0
                    // parallelogram corners (all slant the same way, neighbours share the slanted sides: no gaps)
                    readonly property real tl: strip.slant
                    readonly property real tr: width
                    readonly property real br: width - strip.slant
                    readonly property real bl: 0
                    Shape {
                        id: mask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "white"; strokeWidth: -1
                            startX: hex.tl; startY: 0
                            PathLine { x: hex.tr; y: 0 }
                            PathLine { x: hex.br; y: hex.height }
                            PathLine { x: hex.bl; y: hex.height }
                            PathLine { x: hex.tl; y: 0 }
                        }
                    }
                    Item {
                        id: content
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle { anchors.fill: parent; color: Theme.surface }
                        Image {
                            anchors.fill: parent
                            source: hex.thumbSrc ? "file://" + hex.thumbSrc : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.height: 480
                        }
                        Rectangle {   // side hexagons darker
                            anchors.fill: parent
                            color: "#000000"
                            opacity: hex.isCur ? 0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 260 } }
                        }
                        Rectangle {   // the active one: a dark fade at the bottom for its details
                            visible: hex.isCur
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: parent.height * 0.5
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.alpha("#000000", 0.78) }
                            }
                        }
                    }
                    MultiEffect { anchors.fill: parent; source: content; maskEnabled: true; maskSource: mask }
                    Shape {   // outline: a thin seam between neighbours, the accent on the active one
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: hex.isCur ? Theme.coral : Qt.alpha(Theme.bg, 0.9)
                            strokeWidth: hex.isCur ? 2.5 : 2
                            joinStyle: ShapePath.MiterJoin
                            startX: hex.tl; startY: 0
                            PathLine { x: hex.tr; y: 0 }
                            PathLine { x: hex.br; y: hex.height }
                            PathLine { x: hex.bl; y: hex.height }
                            PathLine { x: hex.tl; y: 0 }
                        }
                    }

                    // details, inside the active hexagon
                    Column {
                        visible: hex.isCur
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 22
                        width: parent.width - 36
                        spacing: 6
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            text: root.step === 1 ? (hex.modelData.name || "") : (root.theme ? root.theme.name : "")
                            color: "#ffffff"; font.family: Theme.font; font.pixelSize: 17; font.bold: true
                        }
                        Row {   // main colours as small square chips
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Repeater {
                                model: root.hiTheme ? root.hiTheme.swatch : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 12; height: 12; radius: 1
                                    color: modelData
                                    border.width: 1; border.color: Qt.alpha("#000000", 0.6)
                                }
                            }
                        }
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                            text: {
                                const t = root.hiTheme
                                if (!t) return ""
                                if (root.step === 2) return "wallpaper " + (strip.currentIndex + 1) + " of " + strip.count
                                return t.wallpapers.length + " WALLPAPERS"
                            }
                            color: Qt.alpha("#ffffff", 0.75); font.family: Theme.font; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: hex.isCur ? root.pick(hex.index) : (strip.currentIndex = hex.index)
                    }
                }
            }

            // ---------- under the strip: a retro plate with the active one's details + its FULL palette ----------
            component Led: Row {   // LED + label, lit = accent
                property string label: ""
                property bool lit: false
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: parent.lit ? Theme.coral : Theme.raised
                    border.width: 1; border.color: parent.lit ? Qt.lighter(Theme.coral, 1.3) : Theme.hover
                    Rectangle { visible: parent.parent.lit; anchors.centerIn: parent; width: 18; height: 18; radius: 9; z: -1; color: Qt.alpha(Theme.coral, 0.25) }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.label; color: parent.lit ? Theme.text : Theme.dim; font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
            }
            component Chip: Rectangle {   // a colour as a small bevelled key
                property color c: "black"
                width: 22; height: 22; radius: 2
                color: c
                border.width: 1; border.color: Qt.alpha("#000000", 0.55)
                Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: Qt.alpha("#ffffff", 0.25) }   // light top edge
            }
            Rectangle {
                id: plate
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: strip.bottom; anchors.topMargin: -6
                width: plateCol.width + 48; height: plateCol.height + 32
                radius: 3
                color: Qt.alpha(Theme.surface, 0.9)
                border.width: 1; border.color: Theme.hover
                Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: Qt.alpha(Theme.text, 0.10) }
                MouseArea { anchors.fill: parent }
                Column {
                    id: plateCol
                    anchors.centerIn: parent
                    spacing: 12
                    Item {
                        width: Math.max(nameT.width + leds.width + 40, pal.width); height: nameT.height
                        Text {
                            id: nameT
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            text: root.hiTheme ? root.hiTheme.name.toUpperCase() : ""
                            color: Theme.text; font.family: Theme.font; font.pixelSize: 26; font.bold: true; font.letterSpacing: 2
                        }
                        Row {
                            id: leds
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 18
                            Led { label: "DARK"; lit: !!root.hiTheme && root.hiTheme.mode !== "light" }
                            Led { label: "LIGHT"; lit: !!root.hiTheme && root.hiTheme.mode === "light" }
                            Led { label: "IN USE"; lit: !!root.hiTheme && root.hiTheme.current }
                        }
                    }
                    Row {   // the full palette: 8 UI colours | 8 normal + 8 bright terminal colours
                        id: pal
                        spacing: 16
                        Column {
                            spacing: 5
                            Text { text: "INTERFACE"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                            Row { spacing: 3; Repeater { model: root.hiTheme ? root.hiTheme.ui : []; delegate: Chip { required property var modelData; c: modelData } } }
                        }
                        Rectangle { width: 1; height: 44; anchors.bottom: parent.bottom; color: Theme.hover }
                        Column {
                            spacing: 5
                            Text { text: "TERMINAL"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                            Row { spacing: 3; Repeater { model: root.hiTheme ? root.hiTheme.ansi.slice(0, 8) : []; delegate: Chip { required property var modelData; c: modelData } } }
                        }
                        Column {
                            spacing: 5
                            Text { text: "BRIGHT"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                            Row { spacing: 3; Repeater { model: root.hiTheme ? root.hiTheme.ansi.slice(8, 16) : []; delegate: Chip { required property var modelData; c: modelData } } }
                        }
                    }
                    Text {
                        text: {
                            const t = root.hiTheme
                            if (!t) return ""
                            return (t.source === "preset" ? "PRESET COLOURS · TUNED TO EACH WALLPAPER" : t.source === "pinned" ? "HAND-MADE COLOURS" : "COLOURS FROM THE WALLPAPER")
                                 + "  ·  " + t.wallpapers.length + " WALLPAPERS"
                        }
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                    }
                }
            }

            // ---------- key hints ----------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 56
                spacing: 30
                Repeater {
                    model: root.step === 1
                        ? [["←  →", "browse"], ["Enter", "wallpapers"], ["Home", "theme in use"], ["Esc", "close"]]
                        : [["←  →", "browse"], ["Enter", "apply"], ["Esc", "back to themes"]]
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        Rectangle {   // retro key cap
                            width: kt.implicitWidth + 16; height: 22; radius: 3
                            color: Theme.raised; border.width: 1; border.color: Theme.hover
                            Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: Qt.alpha(Theme.text, 0.12) }
                            Text { id: kt; anchors.centerIn: parent; text: modelData[0]; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
                    }
                }
            }
        }
    }
}

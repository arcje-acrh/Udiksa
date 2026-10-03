// SideArt.qml -- art for the empty strip beside the notch (one per side, placed by Bar.qml).
// Outer edge: a small label (left: distro logo + name; right: today's weather + place). Between label and notch:
// art for the empty band: a heraldic frieze (swords, fleurs-de-lis, crown, shield; the label on a ribbon banner), a traditional scroll frieze, circuit traces, constellations or stars (Settings > Windows > Bar art). Static.
// Colours come from Theme, so it follows the theme. Static: redrawn only when the theme or the width changes.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string side: "left"
    readonly property bool isLeft: side === "left"
    // display name from the system (full name of the account, else the login name capitalised)
    property string user: { const u = Quickshell.env("USER") || ""; return u.charAt(0).toUpperCase() + u.slice(1) }
    Process {
        running: root.isLeft
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: { const n = text.trim(); if (n) root.user = n } }
    }
    // the empty band above the windows: the notch strip + the gap under it (hypr general.lua gaps_out.top = 10)
    height: Theme.stripHeight + 10
    clip: true

    // "heraldic" style: the label sits on a swallow-tailed ribbon banner, so it is part of the art
    readonly property bool framed: Prefs.v.art === "heraldic"
    readonly property int labelMargin: framed ? 24 : 14
    readonly property bool labelShown: isLeft || Weather.ok
    readonly property real ribbonW: labelShown ? label.width + 2 * labelMargin : 0

    Canvas {
        id: ribbon
        visible: root.framed && root.labelShown
        y: 9; height: 22
        x: root.isLeft ? 6 : root.width - width - 6
        width: root.ribbonW
        function rgba(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }
        function shape(ctx, x0, y0, x1, y1, t) {       // banner with swallowtail ends
            ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y0); ctx.lineTo(x1 - t, (y0 + y1) / 2); ctx.lineTo(x1, y1)
            ctx.lineTo(x0, y1); ctx.lineTo(x0 + t, (y0 + y1) / 2); ctx.closePath()
        }
        onPaint: {
            const ctx = getContext("2d"), w = width, h = height
            ctx.clearRect(0, 0, w, h)
            if (w < 30) return
            shape(ctx, 1, 1, w - 1, h - 1, 8)
            ctx.fillStyle = rgba(Theme.bg, 0.92); ctx.fill()
            ctx.fillStyle = rgba(Theme.coral, 0.14); ctx.fill()
            ctx.strokeStyle = rgba(Theme.amber, 0.95); ctx.lineWidth = 1.2; ctx.stroke()
            shape(ctx, 4, 4, w - 4, h - 4, 7)           // inner rule
            ctx.strokeStyle = rgba(Theme.amber, 0.4); ctx.lineWidth = 1; ctx.stroke()
            ctx.fillStyle = rgba(Theme.coral, 1)          // small diamonds at both ends
            for (const x of [14, w - 14]) { ctx.beginPath(); ctx.moveTo(x, h / 2 - 3); ctx.lineTo(x + 3, h / 2); ctx.lineTo(x, h / 2 + 3); ctx.lineTo(x - 3, h / 2); ctx.closePath(); ctx.fill() }
        }
        onWidthChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Connections { target: Theme; function onCChanged() { ribbon.requestPaint() } }
    }

    Row {
        id: label
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.isLeft ? parent.left : undefined
        anchors.right: root.isLeft ? undefined : parent.right
        anchors.leftMargin: root.labelMargin + (root.framed ? 6 : 0)
        anchors.rightMargin: root.labelMargin + (root.framed ? 6 : 0)
        layoutDirection: root.isLeft ? Qt.LeftToRight : Qt.RightToLeft

        Text {
            visible: root.isLeft || Weather.ok
            anchors.verticalCenter: parent.verticalCenter
            text: root.isLeft ? "\uf303" : Weather.icon(Weather.now.code, Weather.now.day)   // Arch logo | weather icon
            color: Theme.coral
            font.family: Theme.font; font.pixelSize: 17
        }
        Text {
            visible: root.isLeft || Weather.ok
            anchors.verticalCenter: parent.verticalCenter
            text: root.isLeft ? root.user : Weather.deg(Weather.now.temp ?? 0)
            color: Theme.text
            font.family: Theme.font; font.pixelSize: 13; font.bold: true
        }
        Text {
            visible: !root.isLeft && Weather.ok && Weather.wanted
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.w.name + " · " + Weather.words(Weather.now.code)
            color: Theme.muted
            font.family: Theme.font; font.pixelSize: 11
        }
    }

    Canvas {
        id: art
        readonly property real edge: root.framed ? (root.labelShown ? root.ribbonW + 6 + 10 : 14) : label.width + 28
        x: root.isLeft ? edge : 0
        width: Math.max(0, root.width - edge - 14)
        height: parent.height

        function rgba(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }
        readonly property string style: Prefs.v.art
        onStyleChanged: requestPaint()
        function rnd(i) { const v = Math.sin(i * 127.1 + 311.7) * 43758.5453; return v - Math.floor(v) }   // stable pseudo-random 0..1
        function px(t, w) { return root.isLeft ? w - t * w : t * w }       // t: 0 at the notch .. 1 at the label
        function dot(ctx, x, y, r, c, a) { ctx.fillStyle = rgba(c, a); ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI); ctx.fill() }
        function sparkle(ctx, x, y, r, a) {      // four-point sparkle (concave star) with a soft glow
            const g = ctx.createRadialGradient(x, y, 0, x, y, r * 2.6)
            g.addColorStop(0, rgba(Theme.amber, a * 0.45)); g.addColorStop(1, rgba(Theme.amber, 0))
            ctx.fillStyle = g
            ctx.beginPath(); ctx.arc(x, y, r * 2.6, 0, 2 * Math.PI); ctx.fill()
            ctx.fillStyle = rgba(Theme.text, a)
            ctx.beginPath()
            ctx.moveTo(x, y - r); ctx.quadraticCurveTo(x, y, x + r, y); ctx.quadraticCurveTo(x, y, x, y + r)
            ctx.quadraticCurveTo(x, y, x - r, y); ctx.quadraticCurveTo(x, y, x, y - r)
            ctx.fill()
        }

        // star chart: nodes joined by hairlines, brighter stars with halos and rings
        function constellations(ctx, w, h) {
            const top = 5, bot = h - 14, pts = []
            for (let x = 0, i = 0; x < w; i++, x += 22 + rnd(i) * 26) pts.push([x, top + rnd(i * 3 + 1) * (bot - top), i])
            ctx.lineWidth = 1
            for (let i = 0; i < pts.length - 1; i++) {
                if (rnd(pts[i][2] * 5) < 0.18) continue                      // some gaps: several separate constellations
                ctx.strokeStyle = rgba(Theme.amber, 0.38)
                ctx.beginPath(); ctx.moveTo(pts[i][0], pts[i][1]); ctx.lineTo(pts[i + 1][0], pts[i + 1][1]); ctx.stroke()
                if (i + 2 < pts.length && rnd(pts[i][2] * 9) < 0.25) {
                    ctx.beginPath(); ctx.moveTo(pts[i][0], pts[i][1]); ctx.lineTo(pts[i + 2][0], pts[i + 2][1]); ctx.stroke()
                }
            }
            pts.forEach(p => {
                const big = rnd(p[2] * 7) > 0.7
                if (big) { sparkle(ctx, p[0], p[1], 3.5, 0.95); ctx.strokeStyle = rgba(Theme.coral, 0.45); ctx.beginPath(); ctx.arc(p[0], p[1], 6.5, 0, 2 * Math.PI); ctx.stroke() }
                else dot(ctx, p[0], p[1], 1.2 + rnd(p[2]) * 0.9, rnd(p[2] * 2) > 0.5 ? Theme.amber : Theme.text, 0.9)
            })
            for (let i = 0; i < w / 10; i++) dot(ctx, rnd(i + 90) * w, 3 + rnd(i * 4 + 90) * (bot - 3), 0.6, Theme.text, 0.4)   // dust
        }
        // traditional scroll frieze (rinceau, as on temple friezes and old manuscripts): a vine stem with alternating spirals,
        // leaves and dotted buds, ending in a small diamond ornament beside the label
        function traditional(ctx, w, h) {
            const P = 76, c = 17, A = 5, end = w - 16
            const y = x => c + A * Math.sin(2 * Math.PI * x / P)
            ctx.lineWidth = 1.2; ctx.strokeStyle = rgba(Theme.coral, 0.95)
            ctx.beginPath(); ctx.moveTo(0, y(0))
            for (let x = 2; x <= end; x += 2) ctx.lineTo(x, y(x))
            ctx.stroke()
            for (let k = 0; ; k++) {
                const xc = P / 4 + k * P, xt = 3 * P / 4 + k * P          // crest (up) and trough (down)
                if (xc > end - 6) break
                spiral(ctx, xc, y(xc), -1)
                if (xt <= end - 6) spiral(ctx, xt, y(xt), 1)
                const xz = k * P + P / 2                                  // leaves at the zero crossings
                if (xz > 6 && xz < end - 6) { leaf(ctx, xz, c, -1); leaf(ctx, xz, c, 1) }
                for (let d = 0; d < 3; d++) {                              // three little dots around each crest
                    dot(ctx, xc + (d - 1) * 6, y(xc) - 9 - (d === 1 ? 1 : 0), 0.9, Theme.text, 0.75)
                }
            }
            // end ornament: a diamond with a ring and two dots
            const ex = w - 7, ey = c
            ctx.strokeStyle = rgba(Theme.amber, 0.95); ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(ex, ey - 6); ctx.lineTo(ex + 4.5, ey); ctx.lineTo(ex, ey + 6); ctx.lineTo(ex - 4.5, ey); ctx.closePath(); ctx.stroke()
            dot(ctx, ex, ey, 1.6, Theme.coral, 1)
            dot(ctx, ex - 11, ey, 1.1, Theme.amber, 0.9)
        }
        // a spiral curl growing from the stem point (x, y); dir -1 = curling upwards, 1 = downwards
        function spiral(ctx, x, y, dir) {
            ctx.strokeStyle = rgba(Theme.amber, 0.95); ctx.lineWidth = 1.1
            ctx.beginPath()
            const cx = x, cy = y + dir * 5
            for (let t = 0; t <= 3.3 * Math.PI; t += 0.2) {
                const r = 5 - 1.3 * t / Math.PI, a = -dir * Math.PI / 2 + dir * t * (1)
                const px = cx + Math.cos(a) * r, py = cy + Math.sin(a) * r
                if (t === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
            }
            ctx.stroke()
            dot(ctx, cx, cy, 0.9, Theme.coral, 1)
        }
        // a pointed leaf leaning away from the stem (dir -1 up, 1 down)
        function leaf(ctx, x, y, dir) {
            ctx.fillStyle = rgba(Theme.coral, 0.3); ctx.strokeStyle = rgba(Theme.amber, 0.9); ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(x, y)
            ctx.quadraticCurveTo(x + 7, y + dir * 1, x + 8, y + dir * 9)
            ctx.quadraticCurveTo(x - 1, y + dir * 6, x, y)
            ctx.fill(); ctx.stroke()
        }
        // circuit-board traces with 45 degree bends, vias and pads
        function circuit(ctx, w, h) {
            const rails = 4, top = 6, bot = h - 15
            ctx.lineWidth = 1
            for (let r = 0; r < rails; r++) {
                let x = 0, y = top + r * (bot - top) / (rails - 1), i = 0
                ctx.strokeStyle = rgba(r % 2 ? Theme.amber : Theme.coral, 0.6)
                ctx.beginPath(); ctx.moveTo(x, y)
                while (x < w - 10) {
                    x += 14 + rnd(r * 31 + i) * 36
                    ctx.lineTo(x, y)
                    if (rnd(r * 17 + i + 5) > 0.45) {                         // bend: diagonal step up or down, then straight again
                        const d = (rnd(r * 13 + i) > 0.5 ? 1 : -1) * (4 + Math.floor(rnd(r * 7 + i) * 2) * 3)
                        if (y + d > top && y + d < bot) { x += Math.abs(d); y += d; ctx.lineTo(x, y) }
                    }
                    i++
                }
                ctx.stroke()
                ctx.fillStyle = rgba(Theme.bg, 1); ctx.beginPath(); ctx.arc(x, y, 3, 0, 2 * Math.PI); ctx.fill()           // end pad
                ctx.strokeStyle = rgba(Theme.coral, 0.9); ctx.beginPath(); ctx.arc(x, y, 3, 0, 2 * Math.PI); ctx.stroke()
                for (let v = 0; v < 3; v++) dot(ctx, 10 + rnd(r * 3 + v + 40) * (w - 30), y, 1.4, Theme.text, 0.7)       // vias
            }
        }
        // heraldic frieze, as carved on castle gates and temple walls: crossed swords, fleurs-de-lis, a crown and a shield in a
        // row over a Greek-key band
        function heraldic(ctx, w, h) {
            const seq = ["swords", "fleur", "crown", "fleur", "shield", "fleur"], gap = 34, cy = 14
            ctx.lineJoin = "round"
            for (let i = 0, x = 22; x < w - 14; i++, x += gap) {
                const k = seq[i % seq.length]
                if (k === "swords") swords(ctx, x, cy); else if (k === "fleur") fleur(ctx, x, cy)
                else if (k === "crown") crown(ctx, x, cy); else shield(ctx, x, cy)
                if (x + gap < w - 14) { ctx.fillStyle = rgba(Theme.amber, 0.9); ctx.beginPath(); ctx.moveTo(x + gap / 2, cy - 2); ctx.lineTo(x + gap / 2 + 2, cy); ctx.lineTo(x + gap / 2, cy + 2); ctx.lineTo(x + gap / 2 - 2, cy); ctx.fill() }
            }
            // Greek key (meander) along the bottom
            ctx.strokeStyle = rgba(Theme.amber, 0.7); ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(0, 28.5); ctx.lineTo(w, 28.5)
            for (let x = 4; x < w - 8; x += 8) {
                ctx.moveTo(x, 28.5); ctx.lineTo(x, 23.5); ctx.lineTo(x + 6, 23.5); ctx.lineTo(x + 6, 26.5); ctx.lineTo(x + 3, 26.5); ctx.lineTo(x + 3, 25)
            }
            ctx.stroke()
        }
        function crown(ctx, x, y) {
            ctx.beginPath(); ctx.moveTo(x - 7, y + 6); ctx.lineTo(x - 8, y - 4); ctx.lineTo(x - 4, y); ctx.lineTo(x, y - 6)
            ctx.lineTo(x + 4, y); ctx.lineTo(x + 8, y - 4); ctx.lineTo(x + 7, y + 6); ctx.closePath()
            ctx.fillStyle = rgba(Theme.coral, 0.4); ctx.fill(); ctx.strokeStyle = rgba(Theme.amber, 1); ctx.lineWidth = 1.2; ctx.stroke()
            ctx.beginPath(); ctx.moveTo(x - 7.4, y + 3); ctx.lineTo(x + 7.4, y + 3); ctx.stroke()
            for (const p of [[-8, -4], [0, -6], [8, -4]]) dot(ctx, x + p[0], y + p[1], 1.4, Theme.text, 1)
            dot(ctx, x, y + 4.6, 0.9, Theme.text, 0.9)
        }
        function swords(ctx, x, y) {
            ctx.lineWidth = 1.5; ctx.strokeStyle = rgba(Theme.amber, 1)
            ctx.beginPath(); ctx.moveTo(x - 8, y + 8); ctx.lineTo(x + 8, y - 8); ctx.moveTo(x + 8, y + 8); ctx.lineTo(x - 8, y - 8); ctx.stroke()
            ctx.lineWidth = 1.3; ctx.strokeStyle = rgba(Theme.coral, 1)             // cross-guards
            ctx.beginPath(); ctx.moveTo(x - 7, y + 2.5); ctx.lineTo(x - 2.5, y + 7); ctx.moveTo(x + 7, y + 2.5); ctx.lineTo(x + 2.5, y + 7); ctx.stroke()
            dot(ctx, x - 8.5, y + 8.5, 1.3, Theme.text, 1); dot(ctx, x + 8.5, y + 8.5, 1.3, Theme.text, 1)   // pommels
        }
        function fleur(ctx, x, y) {
            ctx.fillStyle = rgba(Theme.coral, 0.5); ctx.strokeStyle = rgba(Theme.amber, 1); ctx.lineWidth = 1.1
            ctx.beginPath(); ctx.moveTo(x, y - 8); ctx.quadraticCurveTo(x + 4, y - 3, x, y + 3); ctx.quadraticCurveTo(x - 4, y - 3, x, y - 8); ctx.fill(); ctx.stroke()
            for (const s of [-1, 1]) {
                ctx.beginPath(); ctx.moveTo(x + s * 1, y + 2); ctx.quadraticCurveTo(x + s * 9, y + 1, x + s * 7, y - 6); ctx.quadraticCurveTo(x + s * 3, y - 3, x + s * 1, y + 2)
                ctx.fill(); ctx.stroke()
            }
            ctx.beginPath(); ctx.moveTo(x - 4.5, y + 3.5); ctx.lineTo(x + 4.5, y + 3.5); ctx.moveTo(x, y + 3.5); ctx.lineTo(x, y + 8); ctx.stroke()
        }
        function shield(ctx, x, y) {
            ctx.beginPath(); ctx.moveTo(x - 6, y - 7); ctx.lineTo(x + 6, y - 7); ctx.lineTo(x + 6, y); ctx.quadraticCurveTo(x + 6, y + 6, x, y + 9)
            ctx.quadraticCurveTo(x - 6, y + 6, x - 6, y); ctx.closePath()
            ctx.fillStyle = rgba(Theme.coral, 0.3); ctx.fill(); ctx.strokeStyle = rgba(Theme.amber, 1); ctx.lineWidth = 1.2; ctx.stroke()
            ctx.beginPath(); ctx.moveTo(x, y - 7); ctx.lineTo(x, y + 8); ctx.moveTo(x - 6, y - 2); ctx.lineTo(x + 6, y - 2); ctx.stroke()
            dot(ctx, x - 3, y - 4.5, 0.9, Theme.text, 1); dot(ctx, x + 3, y - 4.5, 0.9, Theme.text, 1)
        }
        function stars(ctx, w, h) {
            for (let i = 0; i < Math.floor(w / 6); i++) {
                const tt = Math.pow(rnd(i + 1), 1.7), x = px(tt, w), y = 4 + rnd(i * 3 + 2) * (h - 16), a = 0.25 + 0.65 * (1 - 0.8 * tt)
                if (i % 7 === 3) { sparkle(ctx, x, y, 2.5 + (i % 3) * 1.4 + 1.5 * (1 - tt), a); continue }
                ctx.fillStyle = rgba(i % 4 === 0 ? Theme.coral : Theme.amber, a * (i % 3 === 0 ? 1 : 0.6))
                ctx.fillRect(Math.round(x), Math.round(y), i % 5 === 0 ? 2 : 1, i % 5 === 0 ? 2 : 1)
            }
        }

        onPaint: {
            const ctx = getContext("2d"), w = width, h = height
            ctx.clearRect(0, 0, w, h)
            if (w < 30 || style === "none") return
            // every style is drawn the same way round (left to right) and mirrored for the left side
            ctx.save()
            if (root.isLeft) { ctx.translate(w, 0); ctx.scale(-1, 1) }
            if (style === "heraldic") heraldic(ctx, w, h)
            else if (style === "traditional") traditional(ctx, w, h)
            else if (style === "circuit") circuit(ctx, w, h)
            else if (style === "constellations") constellations(ctx, w, h)
            else stars(ctx, w, h)
            ctx.restore()
            // fade: nothing hard at the notch end or at the label end
            ctx.globalCompositeOperation = "destination-in"
            const m = ctx.createLinearGradient(px(0, w), 0, px(1, w), 0)
            m.addColorStop(0, "rgba(0,0,0,0)"); m.addColorStop(0.1, "rgba(0,0,0,1)")
            if (style !== "traditional" && style !== "heraldic") { m.addColorStop(0.75, "rgba(0,0,0,1)"); m.addColorStop(1, "rgba(0,0,0,0)") }   // traditional / heraldic end in their own ornaments
            ctx.fillStyle = m; ctx.fillRect(0, 0, w, h)
            ctx.globalCompositeOperation = "source-over"
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Theme; function onCChanged() { art.requestPaint() } }
    }
}

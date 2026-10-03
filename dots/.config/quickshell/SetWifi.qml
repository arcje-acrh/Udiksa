// SetWifi.qml -- Settings > Wi-Fi (nmcli): on/off, the current connection, networks in range (connect; a
// password box opens for secured new ones), saved networks (connect, auto-connect, change password, forget),
// hidden networks. Enterprise (eduroam-style) sign-in: the Wi-Fi panel in the notch.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

SetPage {
    id: page
    property var nets: []             // [{ ssid, signal, security, inUse }]
    property var saved: []            // [{ name, uuid, auto }]
    property string ip: ""
    property string msg: ""
    property string asking: ""        // ssid whose password box is open
    property bool scanning: false

    function fields(l) {              // nmcli -t -e yes: ':' separates, '\:' is a colon inside a field
        const out = []; let cur = ""
        for (let i = 0; i < l.length; i++) {
            if (l[i] === "\\" && i + 1 < l.length) { cur += l[++i]; continue }
            if (l[i] === ":") { out.push(cur); cur = ""; continue }
            cur += l[i]
        }
        out.push(cur); return out
    }
    function refresh(rescan) {
        scanning = !!rescan
        lister.command = ["sh", "-c", "nmcli -t -e yes -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan " + (rescan ? "yes" : "auto") +
            "; echo ===; nmcli -t -e yes -f NAME,UUID,TYPE,AUTOCONNECT con show; echo ===; nmcli -t -f IP4.ADDRESS dev show wlo1 | head -1"]
        lister.running = true
    }
    Component.onCompleted: refresh(false)
    Timer { interval: 15000; running: true; repeat: true; onTriggered: page.refresh(false) }
    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = text.split("===\n")
                    const seen = {}, nets = []
                    ;(p[0] || "").trim().split("\n").filter(l => l).forEach(l => {
                        const f = page.fields(l)
                        if (!f[1] || seen[f[1]]) return
                        seen[f[1]] = true
                        nets.push({ inUse: f[0] === "*", ssid: f[1], signal: Number(f[2]), security: f[3] })
                    })
                    page.nets = nets.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
                    page.saved = (p[1] || "").trim().split("\n").map(l => page.fields(l)).filter(f => f[2] === "802-11-wireless")
                        .map(f => ({ name: f[0], uuid: f[1], auto: f[3] === "yes" }))
                    page.ip = ((p[2] || "").split(":")[1] || "").trim()
                } catch (e) { page.msg = "Could not read the network list: " + e }
                page.scanning = false
            }
        }
    }
    Process {
        id: act
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.msg = text.trim().split("\n").slice(-1)[0].replace(/^Error: /, "") }
        onExited: (code) => { if (code === 0) page.msg = "Done."; page.refresh(false) }
    }
    function run(cmd, note) { msg = note || "Working…"; act.command = cmd; act.running = true }
    function isSaved(ssid) { return saved.some(s => s.name === ssid) }
    function connect(n) {
        if (isSaved(n.ssid)) run(["nmcli", "con", "up", "id", n.ssid], "Connecting to " + n.ssid + "…")
        else if (!n.security || n.security === "--") run(["nmcli", "dev", "wifi", "connect", n.ssid], "Connecting to " + n.ssid + "…")
        else asking = n.ssid
    }
    readonly property var current: nets.find(n => n.inUse) || null

    SetGroup { title: "Wi-Fi" }
    SetRow {
        title: "Wi-Fi"
        desc: page.current ? "Connected to " + page.current.ssid + "  ·  " + page.current.signal + " %" + (page.ip ? "  ·  " + page.ip : "") : (Networking.wifiEnabled ? "Not connected" : "Off")
        Row {
            spacing: 8
            SetButton { visible: page.current !== null; text: "Disconnect"; onClicked: page.run(["nmcli", "dev", "disconnect", "wlo1"]) }
            Seg { options: ["On", "Off"]; current: Networking.wifiEnabled ? 0 : 1; onPicked: (i) => Networking.wifiEnabled = (i === 0) }
        }
    }
    SetRow {
        visible: page.msg !== ""
        title: page.msg
    }

    SetGroup { title: "Networks in range"; action: page.scanning ? "scanning…" : "scan again"; onActionClicked: page.refresh(true) }
    Repeater {
        model: page.nets
        delegate: Column {
            id: netCol
            required property var modelData
            width: parent.width
            SetRow {
                title: netCol.modelData.ssid
                desc: netCol.modelData.signal + " %  ·  " + (netCol.modelData.security && netCol.modelData.security !== "--" ? netCol.modelData.security : "open") + (page.isSaved(netCol.modelData.ssid) ? "  ·  saved" : "")
                SetButton { text: netCol.modelData.inUse ? "Connected" : "Connect"; accent: !netCol.modelData.inUse; enabled: !netCol.modelData.inUse; onClicked: page.connect(netCol.modelData) }
            }
            SetRow {
                visible: page.asking === netCol.modelData.ssid
                height: visible ? implicitHeight : 0
                title: "Password for " + netCol.modelData.ssid
                Row {
                    spacing: 6
                    SetInput { id: pw; width: 260; password: true; placeholder: "password"; onAccepted: go.clicked() }
                    SetButton { id: go; text: "Connect"; accent: true; enabled: pw.text.length >= 8
                        onClicked: { page.run(["nmcli", "dev", "wifi", "connect", netCol.modelData.ssid, "password", pw.text], "Connecting to " + netCol.modelData.ssid + "…"); page.asking = ""; pw.text = "" } }
                    SetButton { text: "Cancel"; onClicked: page.asking = "" }
                }
            }
        }
    }

    SetGroup { title: "Saved networks" }
    Repeater {
        model: page.saved
        delegate: Column {
            id: savCol
            required property var modelData
            width: parent.width
            property bool editing: false
            SetRow {
                title: savCol.modelData.name
                desc: savCol.modelData.auto ? "connects by itself" : "only when you choose it"
                Row {
                    spacing: 6
                    Seg { options: ["Auto", "Manual"]; current: savCol.modelData.auto ? 0 : 1
                        onPicked: (i) => page.run(["nmcli", "con", "modify", savCol.modelData.uuid, "connection.autoconnect", i === 0 ? "yes" : "no"]) }
                    SetButton { text: "Password"; onClicked: savCol.editing = !savCol.editing }
                    SetButton { text: "Connect"; onClicked: page.run(["nmcli", "con", "up", "uuid", savCol.modelData.uuid], "Connecting…") }
                    SetButton { text: "Forget"; warn: true; onClicked: page.run(["nmcli", "con", "delete", "uuid", savCol.modelData.uuid]) }
                }
            }
            SetRow {
                visible: savCol.editing
                height: visible ? implicitHeight : 0
                title: "New password"
                Row {
                    spacing: 6
                    SetInput { id: npw; width: 260; password: true; placeholder: "new password" }
                    SetButton { text: "Save"; accent: true; enabled: npw.text.length >= 8
                        onClicked: { page.run(["nmcli", "con", "modify", savCol.modelData.uuid, "wifi-sec.psk", npw.text]); npw.text = ""; savCol.editing = false } }
                }
            }
        }
    }

    SetGroup { title: "Hidden network" }
    SetRow {
        title: "Add a hidden network"
        desc: "Its name is not broadcast, so type it exactly. Leave the password empty for an open network."
        Row {
            spacing: 6
            SetInput { id: hs; width: 200; placeholder: "network name" }
            SetInput { id: hp; width: 200; password: true; placeholder: "password" }
            SetButton { text: "Connect"; accent: true; enabled: hs.text.trim() !== ""
                onClicked: { page.run(["nmcli", "dev", "wifi", "connect", hs.text.trim()].concat(hp.text ? ["password", hp.text] : []).concat(["hidden", "yes"]), "Connecting…"); hp.text = "" } }
        }
    }
}

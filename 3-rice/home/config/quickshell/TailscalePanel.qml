// TailscalePanel.qml -- Tailscale in the grown notch (hover the 󰖂 icon). Data + actions: Tailscale.qml.
//   left   your devices (online first): OS icon + name, Tailscale IP or last seen; click = copy its IP
//   right  Tailscale on/off (tailscale up/down), this device (󰌢, click = copy IP), exit node
//          (None + devices that offer one; "allow LAN access" while one is used), accept routes,
//          Tailscale DNS, shields up. Signed out: a "Sign in" button opens the login page.
import QtQuick

Item {
    id: root
    Component.onCompleted: { Tailscale.watchers += 1; Tailscale.refresh() }
    Component.onDestruction: Tailscale.watchers -= 1
    property string copied: ""                // brief "copied" note
    Timer { id: clearCopied; interval: 1500; onTriggered: root.copied = "" }
    function copy(what, text) { Tailscale.copy(text); root.copied = what; clearCopied.restart() }
    // OS logo for a device row
    function osIcon(os) {
        const o = (os || "").toLowerCase()
        if (o === "linux") return "󰌽"
        if (o === "android") return "󰀲"
        if (o === "windows") return "󰍲"
        if (o === "macos") return "󰀵"
        if (o === "ios") return "󰀷"
        return "󰍹"
    }

    Row {
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14

        // ---------- devices ----------
        Card {
            id: devCard
            width: (parent.width - parent.spacing) * 0.58; height: parent.height
            spacing: 4
            PanelTitle {
                title: "Devices · " + Tailscale.onlineCount + " online"
                action: root.copied !== "" ? "copied " + root.copied : "click to copy IP"
                busy: root.copied !== ""
            }
            ScrollList {
                id: devList
                width: parent.width
                height: devCard.height - 2 * devCard.pad - 22 - 4
                model: Tailscale.peers
                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width - ListView.view.rightMargin
                    icon: root.osIcon(modelData.os)
                    title: modelData.name
                    active: Tailscale.exitNodeId === modelData.id
                    dim: !modelData.online
                    note: (Tailscale.exitNodeId === modelData.id ? "exit node · " : "")
                        + (modelData.online ? modelData.ip : "offline · " + Tailscale.ago(modelData.lastSeen))
                    onClicked: if (modelData.ip) root.copy(modelData.name, modelData.ip)
                }
                Text {
                    parent: devList
                    visible: devList.count === 0
                    anchors.centerIn: parent
                    text: Tailscale.running ? "No other devices yet" : "Tailscale is off"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
            }
        }

        // ---------- this device + settings ----------
        Column {
            width: (parent.width - parent.spacing) * 0.42; height: parent.height
            spacing: 8

            Toggle {
                visible: Tailscale.backend !== "NeedsLogin"
                width: parent.width; label: "Tailscale"
                checked: Tailscale.running
                onToggled: Tailscale.setUp(!Tailscale.running)
            }
            Rectangle {   // signed out
                visible: Tailscale.backend === "NeedsLogin"
                width: parent.width; height: 40; radius: 2
                color: lm.containsMouse ? Theme.amber : Theme.coral
                Text { anchors.centerIn: parent; text: "Sign in to Tailscale"; color: Theme.bg; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Tailscale.login() }
            }

            Card {
                width: parent.width
                height: 64
                spacing: 3
                Item {
                    width: parent.width; height: 18
                    Row {
                        spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌢"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 15 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Tailscale.selfName || "this device"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                    }
                    Text {
                        anchors.right: parent.right
                        text: Tailscale.selfIPs.length ? Tailscale.selfIPs[0] : "—"
                        color: im.containsMouse ? Theme.coral : Theme.amber
                        font.family: Theme.font; font.pixelSize: 12; font.bold: true
                        MouseArea { id: im; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Tailscale.selfIPs.length) root.copy("this IP", Tailscale.selfIPs[0]) }
                    }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: Tailscale.tailnet + (Tailscale.magicDNS ? " · MagicDNS" : "")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                }
            }

            // exit node
            Text { text: "EXIT NODE"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 1 }
            Flow {
                width: parent.width
                spacing: 6
                Seg {   // exit node keys (retro style, like every choice)
                    readonly property var opts: [{ id: "", name: "None", ip: "" }].concat(Tailscale.exitOptions)
                    options: opts.map(o => o.name)
                    current: opts.findIndex(o => o.id === Tailscale.exitNodeId)
                    onPicked: (i) => { if (i !== current) Tailscale.setExit(opts[i].ip) }
                }
                Text {
                    visible: Tailscale.exitOptions.length === 0
                    height: 28; verticalAlignment: Text.AlignVCenter
                    text: "no device offers one"
                    color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                }
            }

            Grid {
                width: parent.width
                columns: 2; columnSpacing: 8; rowSpacing: 8
                readonly property real cellW: (width - columnSpacing) / 2
                Toggle {
                    visible: Tailscale.exitNodeId !== ""
                    width: parent.cellW; label: "LAN access"
                    checked: !!Tailscale.prefs.ExitNodeAllowLANAccess
                    onToggled: Tailscale.setPref("exit-node-allow-lan-access", !Tailscale.prefs.ExitNodeAllowLANAccess)
                }
                Toggle {
                    width: parent.cellW; label: "Accept routes"
                    checked: !!Tailscale.prefs.RouteAll
                    onToggled: Tailscale.setPref("accept-routes", !Tailscale.prefs.RouteAll)
                }
                Toggle {
                    width: parent.cellW; label: "Tailscale DNS"
                    checked: !!Tailscale.prefs.CorpDNS
                    onToggled: Tailscale.setPref("accept-dns", !Tailscale.prefs.CorpDNS)
                }
                Toggle {
                    width: parent.cellW; label: "Shields up"
                    checked: !!Tailscale.prefs.ShieldsUp
                    onToggled: Tailscale.setPref("shields-up", !Tailscale.prefs.ShieldsUp)
                }
            }
        }
    }
}

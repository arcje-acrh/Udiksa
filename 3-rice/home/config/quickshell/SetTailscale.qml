// SetTailscale.qml -- Settings > Tailscale (new 2026-09-28, the full version of the notch Tailscale panel): on / off,
// sign in, this device, exit node (+ LAN access), accept routes, Tailscale DNS, shields up, and every device in your
// tailnet with its address (click = copy). Data + actions: Tailscale.qml (no sudo: you are Tailscale's operator).
import QtQuick
import Quickshell

SetPage {
    id: page
    Component.onCompleted: { Tailscale.watchers += 1; Tailscale.refresh() }
    Component.onDestruction: Tailscale.watchers -= 1
    property string copied: ""
    Timer { id: unCopy; interval: 1500; onTriggered: page.copied = "" }
    function copy(t) { Tailscale.copy(t); copied = t; unCopy.restart() }
    readonly property var p: Tailscale.prefs
    readonly property var exitOpts: [{ name: "None", ip: "" }].concat(Tailscale.exitOptions.map(o => ({ name: o.name, ip: o.ip, online: o.online })))

    component Toggle_: SetRow {
        id: tg
        property bool on: false
        signal flipped(bool on)
        Seg { options: ["On", "Off"]; current: tg.on ? 0 : 1; onPicked: (i) => tg.flipped(i === 0) }
    }

    SetRow {
        visible: !Tailscale.installed
        title: "Tailscale is not installed"
        desc: "Install the tailscale package (Apps > Install and remove), then: sudo systemctl enable --now tailscaled; sudo tailscale up; sudo tailscale set --operator=$USER"
    }

    SetGroup { title: "Connection"; visible: Tailscale.installed }
    SetRow {
        visible: Tailscale.installed
        title: "Tailscale"
        desc: Tailscale.backend === "NeedsLogin" ? "Signed out."
            : Tailscale.running ? "Connected to " + (Tailscale.tailnet || "your tailnet") + (Tailscale.magicDNS ? " (MagicDNS on)" : "") + "."
            : Tailscale.backend === "Starting" ? "Starting…" : "Off."
        Row {
            spacing: 8
            SetButton { visible: Tailscale.backend === "NeedsLogin"; text: "Sign in"; accent: true; onClicked: Tailscale.login() }
            Seg { visible: Tailscale.backend !== "NeedsLogin"; options: ["On", "Off"]; current: Tailscale.running ? 0 : 1; onPicked: (i) => Tailscale.setUp(i === 0) }
        }
    }
    SetRow {
        visible: Tailscale.running
        title: "This device"
        desc: Tailscale.selfName + (page.copied !== "" && Tailscale.selfIPs.indexOf(page.copied) >= 0 ? "  ·  copied" : "  ·  click an address to copy it")
        Row {
            spacing: 6
            Repeater { model: Tailscale.selfIPs; delegate: SetButton { required property var modelData; text: modelData; onClicked: page.copy(modelData) } }
        }
    }

    SetGroup { title: "Routing and DNS"; visible: Tailscale.running }
    SetRow {
        visible: Tailscale.running
        title: "Exit node"
        desc: Tailscale.exitNode ? "All your internet traffic goes out through " + Tailscale.exitNode.name + "." : "Only tailnet traffic uses Tailscale."
        Column {
            spacing: 6
            Repeater {
                model: page.exitOpts
                delegate: SetButton {
                    required property var modelData
                    width: 320
                    text: modelData.name + (modelData.ip && modelData.online === false ? "  (offline)" : "")
                    accent: (Tailscale.exitNode ? Tailscale.exitNode.ip : "") === modelData.ip
                    onClicked: Tailscale.setExit(modelData.ip)
                }
            }
        }
    }
    Toggle_ {
        visible: Tailscale.running && Tailscale.exitNode !== null
        title: "Reach your local network"
        desc: "While an exit node is used: printers, NAS and other devices at home stay reachable."
        on: !!page.p.ExitNodeAllowLANAccess
        onFlipped: (on) => Tailscale.setPref("exit-node-allow-lan-access", on)
    }
    Toggle_ {
        visible: Tailscale.running
        title: "Use routes from other devices"
        desc: "Networks that other devices share (subnet routes)."
        on: !!page.p.RouteAll
        onFlipped: (on) => Tailscale.setPref("accept-routes", on)
    }
    Toggle_ {
        visible: Tailscale.running
        title: "Tailscale DNS"
        desc: "Device names (MagicDNS) and the tailnet's DNS settings."
        on: !!page.p.CorpDNS
        onFlipped: (on) => Tailscale.setPref("accept-dns", on)
    }
    Toggle_ {
        visible: Tailscale.running
        title: "Shields up"
        desc: "Block every incoming connection from the tailnet (you can still reach others)."
        on: !!page.p.ShieldsUp
        onFlipped: (on) => Tailscale.setPref("shields-up", on)
    }

    SetGroup { title: "Devices (" + Tailscale.onlineCount + " of " + Tailscale.peers.length + " online)"; visible: Tailscale.running }
    Repeater {
        model: Tailscale.running ? Tailscale.peers : []
        delegate: SetRow {
            required property var modelData
            title: modelData.name + "  ·  " + modelData.os
            desc: (modelData.online ? "online" : "last seen " + Tailscale.ago(modelData.lastSeen)) + (modelData.dns ? "  ·  " + modelData.dns : "")
                  + (modelData.exitOption ? "  ·  can be an exit node" : "")
            SetButton {
                enabled: modelData.ip !== ""
                text: page.copied === modelData.ip && modelData.ip !== "" ? "copied" : modelData.ip
                accent: modelData.online
                onClicked: page.copy(modelData.ip)
            }
        }
    }
}

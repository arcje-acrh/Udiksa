// SetBluetooth.qml -- Settings > Bluetooth: on/off, your devices (connect / disconnect, battery, trust, forget)
// and new devices nearby (scanning runs while this tab is open; Pair = pair + trust + connect).
import QtQuick
import Quickshell
import Quickshell.Bluetooth

SetPage {
    id: page
    readonly property var ad: Bluetooth.defaultAdapter
    Component.onCompleted: if (ad && ad.enabled) ad.discovering = true
    Component.onDestruction: if (ad) ad.discovering = false
    readonly property var all: ad ? ad.devices.values : []
    readonly property var mine: all.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || (a.name || "").localeCompare(b.name || ""))
    readonly property var nearby: all.filter(d => !d.paired && d.deviceName).sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    function kindIcon(d) {
        const i = d.icon || ""
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "󰋋"
        if (i.indexOf("keyboard") >= 0) return "󰌌"
        if (i.indexOf("mouse") >= 0) return "󰍽"
        if (i.indexOf("phone") >= 0) return "󰏲"
        if (i.indexOf("computer") >= 0) return "󰌢"
        if (i.indexOf("audio") >= 0 || i.indexOf("speaker") >= 0) return "󰓃"
        if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0) return "󰊴"
        return "󰂯"
    }

    SetGroup { title: "Bluetooth" }
    SetRow {
        title: "Bluetooth"
        desc: !page.ad ? "No Bluetooth adapter found." : page.ad.enabled ? (page.mine.filter(d => d.connected).length + " connected  ·  " + (page.ad.discovering ? "looking for devices" : "not scanning")) : "Off"
        Seg { options: ["On", "Off"]; current: page.ad && page.ad.enabled ? 0 : 1
            onPicked: (i) => { if (page.ad) { Bt.power(page.ad, i === 0); if (i === 0) page.ad.discovering = true } } }
    }

    SetGroup { title: "Your devices" }
    SetRow { visible: page.mine.length === 0; title: "None paired yet"; desc: "Put a device in pairing mode; it shows up under Nearby." }
    Repeater {
        model: page.mine
        delegate: SetRow {
            required property var modelData
            title: page.kindIcon(modelData) + "  " + (modelData.name || modelData.address)
            desc: (modelData.connected ? "connected" : "not connected") + (modelData.batteryAvailable ? "  ·  battery " + Math.round(modelData.battery * 100) + " %" : "")
                + (modelData.trusted ? "  ·  trusted (connects by itself)" : "")
            Row {
                spacing: 6
                SetButton { text: modelData.trusted ? "Untrust" : "Trust"; onClicked: modelData.trusted = !modelData.trusted }
                SetButton { text: modelData.connected ? "Disconnect" : "Connect"; accent: !modelData.connected; onClicked: modelData.connected ? modelData.disconnect() : modelData.connect() }
                SetButton { text: "Forget"; warn: true; onClicked: modelData.forget() }
            }
        }
    }

    SetGroup { title: "Nearby"; action: page.ad && page.ad.discovering ? "scanning…" : "scan"; onActionClicked: if (page.ad) page.ad.discovering = !page.ad.discovering }
    SetRow { visible: page.nearby.length === 0; title: "Nothing new found"; desc: "Make sure the device is in pairing mode (often: hold its power or Bluetooth button)." }
    Repeater {
        model: page.nearby
        delegate: SetRow {
            required property var modelData
            title: page.kindIcon(modelData) + "  " + (modelData.name || modelData.address)
            desc: modelData.pairing ? "pairing…" : modelData.address
            SetButton { text: "Pair"; accent: true; onClicked: { modelData.trusted = true; modelData.pair() } }
        }
    }
}

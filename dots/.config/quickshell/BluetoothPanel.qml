// BluetoothPanel.qml -- Bluetooth in the grown notch (BlueZ via Quickshell.Bluetooth).
//   left card: devices (scans while open); click = connect / disconnect; a new device = pair + trust + connect
//   right column: Bluetooth on/off, visible to others, adapter details
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    id: root
    readonly property var ad: Bluetooth.defaultAdapter
    Component.onCompleted: if (ad && ad.enabled) { ad.pairable = true; ad.discovering = true }   // pairable: BlueZ can be left "Pairable: no", then pairing silently fails
    Component.onDestruction: if (ad) ad.discovering = false

    // Samsung Galaxy Buds = a paired device that offers Samsung's buds control service (UUID 2e73a4ad-..., what
    // Galaxy Buds Client talks to; BlueZ lists it for every Galaxy Buds model), or one the client already manages
    property var budsMacs: []
    Process {
        running: true
        command: ["sh", "-c", "bluetoothctl devices Paired | while read -r _ m _; do bluetoothctl info \"$m\" | grep -qi 2e73a4ad-332d-41fc-90e2-16bef06523f2 && echo \"$m\"; done; python3 -I -c \"import json,os;print(*[d['MacAddress'] for d in json.load(open(os.path.expanduser('~/.local/share/GalaxyBudsClient/settings.json'))).get('Devices',[])],sep='\\\\n')\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.budsMacs = text.trim().toUpperCase().split(/\s+/) }
    }
    function isBuds(d) { return budsMacs.indexOf((d.address || "").toUpperCase()) >= 0 }

    readonly property var devs: {
        if (!ad) return []
        const ds = ad.devices.values.filter(d => d.paired || d.trusted || d.connected || d.deviceName)   // skip nameless beacons
        ds.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""))
        return ds
    }
    readonly property int connectedCount: devs.filter(d => d.connected).length
    // device-type logo from BlueZ's icon name
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

    Row {
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14

        Card {
            id: devCard
            width: (parent.width - parent.spacing) * 0.62; height: parent.height
            spacing: 2
            PanelTitle {
                title: "Devices"
                action: root.ad && root.ad.discovering ? "scanning ↻" : "scan ↻"
                busy: root.ad && root.ad.discovering
                onActionClicked: if (root.ad) root.ad.discovering = !root.ad.discovering
            }
            ScrollList {
                id: devList
                width: parent.width
                height: devCard.height - 2 * devCard.pad - 22 - 2
                model: root.devs
                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width - ListView.view.rightMargin
                    icon: root.kindIcon(modelData)
                    title: modelData.name
                    active: modelData.connected
                    actionIcon: modelData.paired || modelData.trusted ? "󰆴" : ""      // forget (also a stale "trusted but not paired" entry: it connects and drops until forgotten)
                    action2Icon: root.isBuds(modelData) ? "󰒓" : ""                    // Galaxy Buds settings (Galaxy Buds Client)
                    note: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting ? "…"
                        : modelData.connected ? "connected" + (modelData.batteryAvailable ? " · battery " + Math.round(modelData.battery * 100) + "%" : "")
                        : (modelData.paired ? "paired" : "click to pair")
                    onClicked: {
                        if (modelData.connected) modelData.disconnect()
                        else if (modelData.paired) modelData.connect()
                        else { modelData.trusted = true; modelData.pair() }
                    }
                    onActionClicked: modelData.forget()
                    onAction2Clicked: Quickshell.execDetached(["sh", "-c", "galaxybudsclient app -a || galaxybudsclient"])
                }
                Text {
                    parent: devList
                    visible: devList.count === 0
                    anchors.centerIn: parent
                    text: root.ad && root.ad.enabled ? "No devices yet…" : "Bluetooth is off"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
            }
        }

        Column {
            width: (parent.width - parent.spacing) * 0.38; height: parent.height
            spacing: 8
            Toggle {
                width: parent.width; label: "Bluetooth"
                checked: root.ad ? root.ad.enabled : false
                onToggled: if (root.ad) Bt.power(root.ad, !root.ad.enabled)
            }
            Toggle {
                width: parent.width; label: "Visible to others"
                checked: root.ad ? root.ad.discoverable : false
                onToggled: if (root.ad) root.ad.discoverable = !root.ad.discoverable
            }
            Card {
                width: parent.width; height: parent.height - 2 * 40 - 2 * parent.spacing
                spacing: 6
                Row { width: parent.width; Text { width: parent.width / 2; text: "Adapter"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                      Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: root.ad ? root.ad.name : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true } }
                Row { width: parent.width; Text { width: parent.width / 2; text: "Connected"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                      Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: String(root.connectedCount); color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true } }
                Row { width: parent.width; Text { width: parent.width / 2; text: "State"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                      Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: root.ad ? BluetoothAdapterState.toString(root.ad.state) : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true } }
            }
        }
    }
}

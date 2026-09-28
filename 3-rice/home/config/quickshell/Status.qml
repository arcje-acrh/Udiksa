// Status.qml -- right side of the notch: System (GPU mode + S/B/T), Wi-Fi, Bluetooth, Tailscale, Bluetooth, volume, battery (+ %), power, notifications bell (far right).
// Every icon opens its panel in the notch: hover (after Theme.hoverOpenDelay) or click.
// Scroll on the volume icon still changes the volume directly.
// Data comes from Quickshell's own modules (no helper tools): Networking, Bluetooth, Pipewire, UPower.
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Row {
    id: root
    spacing: 16
    readonly property int iconSize: 16
    property string openPanel: ""          // the notch's open panel (colours its icon)
    signal hoverIn(string id)
    signal hoverOut(string id)
    signal clicked(string id)

    // one hover/click target around an icon
    component Target: MouseArea {
        required property string panel
        anchors.fill: parent; anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverIn(panel)
        onExited: root.hoverOut(panel)
        onClicked: root.clicked(panel)
    }
    function tint(id, base) { return root.openPanel === id ? Theme.coral : base }

    // ---------- System (modes): icon shows the GPU mode; red = NVIDIA driver missing (ASUS laptops only) ----------
    Item {
        visible: Power.asus || Power.gfx
        anchors.verticalCenter: parent.verticalCenter
        width: sysRow.width; height: 18
        Row {
            id: sysRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font; font.pixelSize: root.iconSize
                text: Power.gpuError ? "󰍛" : "󰢮"
                color: root.tint("system", Power.gpuError ? Theme.warn
                     : Power.gpuMode === "AsusMuxDgpu" ? Theme.coral
                     : Power.gpuMode === "Integrated" ? Theme.muted : Theme.text)
            }
            Text {   // mode initial: S / B / T
                anchors.verticalCenter: parent.verticalCenter
                text: Power.modeLabels[Power.mode] ? Power.modeLabels[Power.mode].charAt(0) : ""
                color: root.tint("system", Theme.muted)
                font.family: Theme.font; font.pixelSize: 11; font.bold: true
            }
        }
        Target { panel: "system" }
    }

    // ---------- Wi-Fi ----------
    readonly property var wifiDevice: {
        const ds = Networking.devices.values
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) return ds[i]
        return null
    }
    readonly property var wiredDevice: {
        const ds = Networking.devices.values
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wired && ds[i].connected) return ds[i]
        return null
    }
    readonly property bool wifiUp: wifiDevice !== null && wifiDevice.connected
    readonly property real wifiSignal: {   // 0..1 of the connected network
        if (!wifiDevice) return 0
        const ns = wifiDevice.networks.values
        for (let i = 0; i < ns.length; i++) if (ns[i].connected) return ns[i].signalStrength
        return 0
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font; font.pixelSize: root.iconSize
        text: root.wifiUp ? ["󰤟", "󰤢", "󰤥", "󰤨"][Math.max(0, Math.min(3, Math.floor(root.wifiSignal * 4 - 0.001)))]
              : (root.wiredDevice ? "󰈀" : "󰤭")
        color: root.tint("wifi", (root.wifiUp || root.wiredDevice) ? Theme.text : Theme.dim)
        Target { panel: "wifi" }
    }

    // ---------- Bluetooth ----------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property bool btConnected: {
        if (!btAdapter) return false
        const ds = btAdapter.devices.values
        for (let i = 0; i < ds.length; i++) if (ds[i].connected) return true
        return false
    }
    Text {
        visible: root.btAdapter !== null        // no Bluetooth adapter = no icon
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font; font.pixelSize: root.iconSize
        text: !root.btOn ? "󰂲" : (root.btConnected ? "󰂱" : "󰂯")
        color: root.tint("bluetooth", root.btOn ? Theme.text : Theme.dim)
        Target { panel: "bluetooth" }
    }

    // ---------- Tailscale: white = connected, coral = through an exit node, grey = off ----------
    Text {
        visible: Tailscale.installed && Tailscale.backend !== ""
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font; font.pixelSize: root.iconSize
        text: "󰖂"
        color: root.tint("tailscale", !Tailscale.running ? Theme.dim : (Tailscale.exitNodeId !== "" ? Theme.coral : Theme.text))
        Target { panel: "tailscale" }
    }

    // ---------- Volume ----------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    Text {
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font; font.pixelSize: root.iconSize
        text: root.muted ? "󰖁" : (root.vol < 0.34 ? "󰕿" : (root.vol < 0.67 ? "󰖀" : "󰕾"))
        color: root.tint("volume", root.muted ? Theme.dim : Theme.text)
        Target {
            panel: "volume"
            onWheel: (w) => {
                if (!root.sink || !root.sink.audio) return
                const step = w.angleDelta.y > 0 ? 0.05 : -0.05
                root.sink.audio.volume = Math.max(0, Math.min(1.25, root.vol + step))   // up to 125 %
            }
        }
    }

    // ---------- Battery ----------
    readonly property var bat: UPower.displayDevice
    readonly property bool batPresent: bat !== null && bat.isPresent
    readonly property real batPct: bat ? Math.round(bat.percentage * 100) : 0   // percentage is 0..1 (verified on screen)
    readonly property bool charging: bat !== null && bat.state === UPowerDeviceState.Charging
    readonly property color batColor: root.tint("battery", Theme.text)   // always white (user request), coral while its panel is open
    Item {
        visible: root.batPresent
        anchors.verticalCenter: parent.verticalCenter
        width: batRow.width; height: batRow.height
        Target { panel: "battery" }
        Row {
            id: batRow
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font; font.pixelSize: root.iconSize
                readonly property var levels: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
                text: root.charging ? "󰂄" : levels[Math.max(0, Math.min(9, Math.floor(root.batPct / 10) - (root.batPct >= 100 ? 0 : 1) + (root.batPct < 10 ? 1 : 0)))]
                color: root.batColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font; font.pixelSize: 12
                text: root.batPct + "%"
                color: root.batColor
            }
        }
    }

    // ---------- Power ----------
    Text {
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font; font.pixelSize: root.iconSize
        text: "󰐥"
        color: root.tint("power", Theme.text)
        Target { panel: "power" }
    }

    // ---------- Notifications: bell with the unread count (󰂛 = do not disturb) ----------
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: bell.width + (badge.visible ? badge.width - 4 : 0); height: 18
        Text {
            id: bell
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font; font.pixelSize: root.iconSize
            text: Notifs.dnd ? "󰂛" : (Notifs.unread > 0 ? "󰂞" : "󰂚")
            color: root.tint("notifications", Notifs.dnd ? Theme.dim : (Notifs.unread > 0 ? Theme.coral : Theme.text))
        }
        Rectangle {
            id: badge
            visible: Notifs.unread > 0 && !Notifs.dnd
            x: bell.width - 6; y: -3
            width: Math.max(14, cnt.implicitWidth + 6); height: 14; radius: 7
            color: Theme.coral
            Text { id: cnt; anchors.centerIn: parent; text: Notifs.unread > 9 ? "9+" : Notifs.unread; color: Theme.bg; font.family: Theme.font; font.pixelSize: 9; font.bold: true }
        }
        Target { panel: "notifications" }
    }
}

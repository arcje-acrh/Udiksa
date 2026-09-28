// WifiAdvanced.qml -- the "Advanced" settings of a Wi-Fi network, used by the sign-in form and by a
// saved network's settings (WifiPanel.qml):
//   connect automatically, IP (automatic / manual address + gateway), DNS, MAC address (default /
//   random / stable / real), metered connection.
// args() returns them as nmcli settings; load(values) fills them from `nmcli -g` output.
import QtQuick

Column {
    id: root
    spacing: 8
    property bool auto: true
    property int ipMode: 0                 // 0 automatic (DHCP), 1 manual
    property int mac: 0                    // 0 default, 1 random, 2 stable, 3 real
    property int metered: 0                // 0 auto-detect, 1 yes, 2 no
    readonly property var macValues: ["", "random", "stable", "permanent"]
    readonly property var meteredValues: ["unknown", "yes", "no"]

    function reset() { auto = true; ipMode = 0; mac = 0; metered = 0; addr.text = ""; gw.text = ""; dns.text = "" }
    // values: [autoconnect, ipv4.method, ipv4.addresses, ipv4.gateway, ipv4.dns, cloned-mac-address, metered]
    function load(v) {
        auto = v[0] !== "no"
        ipMode = v[1] === "manual" ? 1 : 0
        addr.text = (v[2] || "").split(",")[0].trim(); gw.text = v[3] || ""; dns.text = (v[4] || "").replace(/,/g, " ")
        mac = Math.max(0, macValues.indexOf(v[5] || ""))
        metered = Math.max(0, meteredValues.indexOf(v[6] || "unknown"))
    }
    function args() {
        const d = dns.text.trim().split(/[ ,]+/).filter(x => x).join(",")
        let a = ["connection.autoconnect", auto ? "yes" : "no", "connection.metered", meteredValues[metered]]
        a = a.concat(ipMode === 1
            ? ["ipv4.method", "manual", "ipv4.addresses", addr.text.trim(), "ipv4.gateway", gw.text.trim(), "ipv4.dns", d, "ipv4.ignore-auto-dns", "yes"]
            : ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", d, "ipv4.ignore-auto-dns", d ? "yes" : "no"])
        a.push("802-11-wireless.cloned-mac-address", macValues[mac])
        return a
    }
    function valid() { return ipMode === 0 || (addr.text.trim().indexOf("/") > 0) }

    component Label: Text {
        width: 150; anchors.verticalCenter: parent.verticalCenter
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }

    Row { Label { text: "Connect automatically" } Seg { options: ["Yes", "No"]; current: root.auto ? 0 : 1; onPicked: (i) => root.auto = i === 0 } }
    Row { Label { text: "IP address" } Seg { options: ["Automatic (DHCP)", "Manual"]; current: root.ipMode; onPicked: (i) => root.ipMode = i } }
    Field { id: addr; visible: root.ipMode === 1; label: "Address / prefix"; placeholder: "192.168.1.50/24" }
    Field { id: gw; visible: root.ipMode === 1; label: "Gateway"; placeholder: "192.168.1.1" }
    Field { id: dns; label: "DNS servers"; placeholder: root.ipMode === 1 ? "1.1.1.1 8.8.8.8" : "optional -- empty = the network's own" }
    Row { Label { text: "MAC address" } Seg { options: ["Default", "Random", "Stable", "Real"]; current: root.mac; onPicked: (i) => root.mac = i } }
    Row { Label { text: "Metered" } Seg { options: ["Auto", "Yes", "No"]; current: root.metered; onPicked: (i) => root.metered = i } }
}

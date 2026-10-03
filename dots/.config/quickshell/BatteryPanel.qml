// BatteryPanel.qml -- one row across the grown notch: big %, charge gauge + status line, charge limit.
// Data: UPower. Charge limit: `asusctl battery limit N` -> asusd writes the kernel's
// charge_control_end_threshold (asus-wmi -> the laptop's embedded controller stops charging there),
// saves it in /etc/asusd/asusd.ron and re-applies it every boot. "100% once" = Power.chargeOnce() (oneshot + restore).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root
    readonly property var bat: UPower.displayDevice
    readonly property real pct: bat ? bat.percentage : 0              // 0..1
    readonly property int state: bat ? bat.state : 0
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property real rate: bat ? Math.abs(bat.changeRate) : 0   // W

    function hm(secs) {
        if (!secs || secs <= 0) return ""
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60)
        return h > 0 ? h + " h " + m + " m" : m + " m"
    }
    readonly property string status: {
        if (!bat) return "No battery"
        if (full) return "Fully charged"
        if (charging) return "Charging · +" + rate.toFixed(0) + " W" + (bat.timeToFull > 0 ? " · full in " + hm(bat.timeToFull) : "")
        if (!Power.unplugged) return "Plugged in · not charging"
        return "On battery · −" + rate.toFixed(0) + " W" + (bat.timeToEmpty > 0 ? " · " + hm(bat.timeToEmpty) + " left" : "")
    }

    // charge limit: read on open, set on click
    readonly property var limits: [60, 80, 100]   // the ONLY values this laptop's EC honours (90/95 tested 2026-09-26: ignored)
    property int limit: -1
    Process {
        running: true
        command: ["asusctl", "battery", "info"]
        stdout: StdioCollector { onStreamFinished: { const m = text.match(/(\d+)%/); if (m) root.limit = parseInt(m[1]) } }
    }
    function setLimit(v) {
        Power.cancelOnce(false)             // picking a limit ends a running "100% once": the new choice wins
        root.limit = v
        Quickshell.execDetached(["asusctl", "battery", "limit", String(v)])
    }

    Row {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 22; anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20

        Text {
            id: big
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.pct * 100) + "%"
            color: Theme.text
            font.family: Theme.font; font.pixelSize: 30; font.bold: true
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - big.width - seg.width - 2 * parent.spacing
            spacing: 9
            LedBar {   // gauge: retro LED segments; the charge limit shows as a grey segment
                width: parent.width
                segH: 12
                frac: root.pct
                mark: root.limit > 0 && root.limit < 100 ? root.limit / 100 : -1
            }
            Item {
                width: parent.width; height: 16
                Text {
                    anchors.left: parent.left
                    text: root.status; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 12; font.bold: true
                }
                Row {   // right end of the status line: "100% once" (below a 100% limit) + health
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Rectangle {   // one full charge, then the limit applies again (asusctl battery oneshot)
                        visible: (root.limit > 0 && root.limit < 100) || Power.oneshotRestore > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: once.implicitWidth + 16; height: 20; radius: 2; KeyEdge {}
                        color: om.containsMouse ? Theme.hover : Theme.raised
                        Text { id: once; anchors.centerIn: parent; text: Power.oneshotRestore > 0 ? "100% once · back to " + Power.oneshotRestore + "% · cancel" : "charge to 100% once"; color: Theme.amber; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                        MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Power.oneshotRestore === 0) { Power.chargeOnce(root.limit); root.limit = 100 } else { root.limit = Power.oneshotRestore; Power.cancelOnce(true) } } }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.bat && root.bat.healthSupported
                        text: root.bat ? "Health " + Math.round(root.bat.healthPercentage) + "%" : ""
                        color: Theme.muted
                        font.family: Theme.font; font.pixelSize: 12
                    }
                }
            }
        }
        Column {
            id: seg
            visible: Power.asus                 // the charge limit needs asusctl (ASUS laptops)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text { text: "CHARGE LIMIT"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 1 }
            Seg {
                options: root.limits.map(v => v + "%")
                current: root.limits.indexOf(root.limit)
                onPicked: (i) => root.setLimit(root.limits[i])
            }
        }
    }
}

// SetAbout.qml -- Settings > About: you (account) and this machine (model, CPU, GPU, memory, disks, display,
// battery health, software versions). One shell command collects "section|label|value" lines on open.
// Last: "Hardware support" -- what the rice found here (the notch and Settings show only these) and the guide
// for adding support for other devices (docs/HARDWARE.md in the repo, also on GitHub).
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    property var info: []              // [{ sec, label, value }]
    Process {
        running: true
        command: ["bash", "-c", String.raw`
u=$(id -un); g=$(getent passwd "$u")
echo "You|Name|$(echo "$g" | cut -d: -f5 | cut -d, -f1)"
echo "You|User|$u  (uid $(id -u))"
echo "You|Groups|$(id -Gn | tr ' ' ', ')"
echo "You|Shell|$(echo "$g" | cut -d: -f7)"
echo "You|Home|$HOME"
echo "Machine|Model|$(cat /sys/class/dmi/id/sys_vendor) $(cat /sys/class/dmi/id/product_name)"
echo "Machine|BIOS|$(cat /sys/class/dmi/id/bios_version)  ($(cat /sys/class/dmi/id/bios_date))"
echo "Machine|Hostname|$(cat /etc/hostname)"
echo "Machine|Processor|$(lscpu | sed -n 's/^Model name: *//p')  ·  $(nproc) cores"
lspci | grep -iE 'vga|3d|display' | sed 's/^[^:]*: [^:]*: //' | while read -r l; do echo "Machine|Graphics|$l"; done
command -v supergfxctl >/dev/null && echo "Machine|GPU mode|$($HOME/.local/bin/gpu-state mode 2>/dev/null) · dGPU $($HOME/.local/bin/gpu-state dgpu 2>/dev/null)"
echo "Machine|Memory|$(awk '/MemTotal/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
lsblk -dno MODEL,SIZE -e 7,11 | sed 's/  */ /g' | while read -r l; do echo "Machine|Disk|$l"; done
hyprctl monitors -j | python3 -c 'import sys,json;[print("Machine|Display|%s %dx%d @ %.0f Hz · scale %.2f" % (m["name"],m["width"],m["height"],m["refreshRate"],m["scale"])) for m in json.load(sys.stdin)]'
b=$(upower -e | grep -m1 battery); [ -n "$b" ] && upower -i "$b" | awk -F': +' '/energy-full:/{f=$2} /energy-full-design:/{d=$2} /capacity:/{c=$2} /technology:/{t=$2} END{print "Machine|Battery|health " c "  ·  " f " of " d "  ·  " t}'
echo "Software|System|$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')  ·  kernel $(uname -r)"
echo "Software|Desktop|Hyprland $(hyprctl version -j | python3 -c 'import sys,json;print(json.load(sys.stdin)["version"])')  ·  $(qs --version | head -1 | cut -d' ' -f1-2)"
echo "Software|Packages|$(pacman -Qq | wc -l) installed  ·  $(pacman -Qeq | wc -l) by you  ·  $(pacman -Qmq | wc -l) from AUR"
echo "Software|Theme|$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.local/state/rice/theme.json")))["theme"])' 2>/dev/null)"
echo "Software|Up since|$(uptime -s)  ($(uptime -p | sed 's/^up //'))"
`]
        stdout: StdioCollector {
            onStreamFinished: page.info = text.trim().split("\n").filter(l => l.split("|").length >= 3).map(l => { const p = l.split("|"); return { sec: p[0], label: p[1], value: p.slice(2).join("|").trim() } })
        }
    }
    Repeater {
        model: page.info
        delegate: Column {
            required property var modelData
            required property int index
            width: parent.width
            SetGroup { visible: index === 0 || page.info[index - 1].sec !== modelData.sec; height: visible ? 46 : 0; title: modelData.sec === "You" ? "You" : modelData.sec === "Machine" ? "This machine" : "Software" }
            Item {
                width: parent.width; height: 34
                Text { width: 170; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                Text { x: 170; width: parent.width - 170; anchors.verticalCenter: parent.verticalCenter; text: modelData.value || "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.raised; opacity: 0.4 }
            }
        }
    }

    // ---------- hardware support: what was found (Power.qml) + how to add more ----------
    readonly property string guide: Quickshell.env("HOME") + "/Udiksa/docs/HARDWARE.md"
    readonly property var found: [
        ["Performance modes", Power.asus ? "ASUS (asusctl): modes, CPU watts, fan curves" : Power.ppd ? "power-profiles-daemon: modes" : ""],
        ["GPU switching", Power.gfx ? "supergfxctl: " + Power.gfxModes.map(m => Power.gpuLabels[m] || m).join(" / ") : ""],
        ["Laptop screen", Power.panel ? Power.panelName + (Power.panelSwitch ? " · " + Power.hzLow + " / " + Power.hzHigh + " Hz" : "") : ""],
        ["Keyboard light", Power.kbd ? (Power.asus ? "colours + brightness (rice-kbd)" : "brightness") : ""],
        ["Touchpad", Power.touchpad ? "yes" : ""],
        ["Battery", Power.battery ? "yes" + (Power.asus ? " · charge limit" : "") : ""],
        ["Lid", Power.lid ? "yes" : ""],
        ["Fans", Power.asus ? "speeds + curves" : Power.fans ? "speeds (no control)" : ""],
        ["Wi-Fi / Bluetooth", [Power.wifi ? "Wi-Fi" : "", Power.bt ? "Bluetooth" : ""].filter(x => x).join(" · ")],
        ["Slash lid light", Power.slash ? "yes" : ""]
    ]
    SetGroup { title: "Hardware support" }
    Text {
        width: parent.width; wrapMode: Text.Wrap
        text: "The notch and Settings show only what works on this machine. Not found here = hidden."
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
        bottomPadding: 8
    }
    Repeater {
        model: page.found
        delegate: Item {
            required property var modelData
            width: parent.width; height: 30
            Text { width: 170; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Text {
                x: 170; width: parent.width - 170; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                text: modelData[1] || "not found"; color: modelData[1] ? Theme.text : Theme.dim
                font.family: Theme.font; font.pixelSize: 13; font.bold: modelData[1] !== ""
            }
        }
    }
    SetRow {
        title: "Add support for your device"
        desc: "Fan control on ThinkPad / Dell, another keyboard-light tool, charge limits on other brands…: a short guide shows where each part of the rice looks for hardware and how to plug in your own tool."
        Row {
            spacing: 8
            SetButton { text: "Open the guide"; icon: "󰈙"; onClicked: page.host.edit(page.guide) }
            SetButton { text: "On GitHub"; icon: "󰊤"; onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/arcje-acrh/Udiksa/blob/main/docs/HARDWARE.md"]) }
        }
    }
}

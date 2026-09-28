// SetAbout.qml -- Settings > About: you (account) and this machine (model, CPU, GPU, memory, disks, display,
// battery health, software versions). One shell command collects "section|label|value" lines on open.
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
echo "Machine|GPU mode|$($HOME/.local/bin/gpu-state mode 2>/dev/null) · dGPU $($HOME/.local/bin/gpu-state dgpu 2>/dev/null)"
echo "Machine|Memory|$(awk '/MemTotal/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
lsblk -dno MODEL,SIZE -e 7,11 | sed 's/  */ /g' | while read -r l; do echo "Machine|Disk|$l"; done
hyprctl monitors -j | python3 -c 'import sys,json;[print("Machine|Display|%s %dx%d @ %.0f Hz · scale %.2f" % (m["name"],m["width"],m["height"],m["refreshRate"],m["scale"])) for m in json.load(sys.stdin)]'
b=$(upower -e | grep -m1 battery); upower -i "$b" | awk -F': +' '/energy-full:/{f=$2} /energy-full-design:/{d=$2} /capacity:/{c=$2} /technology:/{t=$2} END{print "Machine|Battery|health " c "  ·  " f " of " d "  ·  " t}'
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
}

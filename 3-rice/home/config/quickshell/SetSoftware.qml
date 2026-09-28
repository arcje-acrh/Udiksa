// SetSoftware.qml -- Settings > Software: packages you installed yourself (pacman -Qe), searchable, "Apps only"
// = packages with an app launcher entry; AUR ones are marked. Pick one -> exactly what `pacman -Rns` would take
// with it (or why it can't go); Remove -> confirm click -> pkexec (the shell's password prompt) -> snapper
// makes its pre/post snapshot automatically. Core system packages are protected.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    property var pkgs: []             // [{ name, version, desc, size, aur, app }]
    property string query: ""
    property bool appsOnly: true
    property var sel: null
    property var preview: []          // packages that would go
    property string blocked: ""       // why it can't be removed
    property string status: ""
    readonly property var core: ["base", "base-devel", "linux", "linux-firmware", "linux-headers", "glibc", "pacman", "systemd", "sudo", "grub",
        "efibootmgr", "btrfs-progs", "hyprland", "quickshell-git", "greetd", "cage", "kitty", "networkmanager", "pipewire", "wireplumber",
        "intel-ucode", "mkinitcpio", "snapper", "snap-pac", "polkit", "dkms", "asusctl", "supergfxctl", "nvidia-open-dkms", "bash"]

    Process {
        id: lister
        running: true
        command: ["sh", "-c", "apps=$(pacman -Qqo /usr/share/applications/*.desktop 2>/dev/null | sort -u | tr '\\n' ' '); aur=$(pacman -Qmq | tr '\\n' ' '); " +
                  "echo \"APPS $apps\"; echo \"AUR $aur\"; LC_ALL=C pacman -Qi $(pacman -Qeq) | grep -E '^(Name|Version|Description|Installed Size)'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.split("\n")
                const apps = (L[0] || "").replace(/^APPS /, "").split(" ")
                const aur = (L[1] || "").replace(/^AUR /, "").split(" ")
                const out = []; let cur = null
                for (const l of L.slice(2)) {
                    const m = l.match(/^([\w ]+?)\s*:\s(.*)$/); if (!m) continue
                    if (m[1] === "Name") { cur = { name: m[2], version: "", desc: "", size: "" }; out.push(cur) }
                    else if (cur && m[1] === "Version") cur.version = m[2]
                    else if (cur && m[1] === "Description") cur.desc = m[2]
                    else if (cur && m[1] === "Installed Size") cur.size = m[2].replace(" ", " ")
                }
                out.forEach(p => { p.aur = aur.indexOf(p.name) >= 0; p.app = apps.indexOf(p.name) >= 0 })
                page.pkgs = out
            }
        }
    }
    Process {
        id: previewer
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.trim().split("\n").filter(l => l)
                if (L.some(l => l.startsWith("error"))) {
                    const who = L.filter(l => l.startsWith("::")).map(l => (l.match(/required by (\S+)/) || [])[1]).filter(x => x)
                    page.blocked = "Needed by " + who.slice(0, 6).join(", ") + (who.length > 6 ? " and " + (who.length - 6) + " more" : "") + "."
                    page.preview = []
                } else { page.blocked = ""; page.preview = L }
            }
        }
    }
    Process {
        id: remover
        stdout: StdioCollector { onStreamFinished: page.status = text.trim().split("\n").slice(-1)[0] || "" }
        onExited: (code) => { page.status = code === 0 ? "Removed " + page.sel.name + "." : "Not removed (cancelled or failed)."; page.sel = null; lister.running = true }
    }
    function pick(p) {
        sel = p; preview = []; blocked = ""; status = ""
        if (core.indexOf(p.name) >= 0) { blocked = "Part of the core system; remove it from a terminal if you really mean it."; return }
        previewer.command = ["sh", "-c", "LC_ALL=C pacman -Rs --print \"$1\" 2>&1", "_", p.name]
        previewer.running = true
    }
    function remove() {
        status = "Waiting for your password…"
        remover.command = ["pkexec", "pacman", "-Rns", "--noconfirm", sel.name]
        remover.running = true
    }
    // ---- install: search the repositories (pacman -Ss), install with pkexec; AUR via yay in a terminal ----
    property var found: []
    Process {
        id: searcher
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.split("\n"), out = []
                for (let i = 0; i < L.length; i++) {
                    const m = L[i].match(/^(\S+)\/(\S+)\s+(\S+)(.*)$/)
                    if (m) out.push({ repo: m[1], name: m[2], version: m[3], installed: /\[installed/.test(m[4]), desc: (L[i + 1] || "").trim() })
                }
                page.found = out.slice(0, 30)
            }
        }
    }
    function search(q) { if (q.trim().length < 2) { found = []; return } searcher.command = ["pacman", "-Ss", "--color", "never", q.trim()]; searcher.running = true }
    Process {
        id: installer
        onExited: (code) => { page.status = code === 0 ? "Installed." : "Not installed (cancelled or failed)."; lister.running = true; page.search(iq.text) }
    }
    function install(name) { status = "Waiting for your password…"; installer.command = ["pkexec", "pacman", "-S", "--noconfirm", "--needed", name]; installer.running = true }

    readonly property var shown: pkgs.filter(p => (!appsOnly || p.app) && (query === "" || (p.name + " " + p.desc).toLowerCase().indexOf(query.toLowerCase()) >= 0))

    SetGroup { title: "Install" }
    SetRow {
        title: "Find software"
        desc: "Searches the Arch repositories. Not there? The AUR button runs yay in a terminal."
        Row {
            spacing: 8
            SetInput { id: iq; width: 260; placeholder: "name or keyword"; onAccepted: page.search(text) }
            SetButton { text: "Search"; onClicked: page.search(iq.text) }
            SetButton { text: "AUR"; enabled: iq.text.trim() !== ""; onClicked: Quickshell.execDetached(["kitty", "--class", "rice-script", "-e", "bash", "-c", "yay \"$1\"; read -rp 'Done. Press Enter to close.'", "_", iq.text.trim()]) }
        }
    }
    Repeater {
        model: page.found
        delegate: SetRow {
            required property var modelData
            title: modelData.name + "   " + modelData.version
            desc: modelData.repo + "  ·  " + modelData.desc
            SetButton { text: modelData.installed ? "Installed" : "Install"; accent: !modelData.installed; enabled: !modelData.installed && !installer.running; onClicked: page.install(modelData.name) }
        }
    }
    SetGroup { title: "Installed by you" }
    SetRow {
        title: "Uninstall"
        desc: page.pkgs.length + " packages (" + page.pkgs.filter(p => p.app).length + " apps). Dependencies they pulled in are removed with them."
        Row {
            spacing: 8
            SetInput { width: 220; placeholder: "search…"; onTextChanged: page.query = text }
            Seg { options: ["Apps", "All"]; current: page.appsOnly ? 0 : 1; onPicked: (i) => page.appsOnly = (i === 0) }
        }
    }
    Rectangle {   // the picked package: what would be removed
        visible: page.sel !== null || page.status !== ""
        width: parent.width; height: visible ? box.implicitHeight + 28 : 0
        color: Theme.surface; radius: 2; border.width: 1; border.color: Theme.raised
        Column {
            id: box
            x: 16; y: 14; width: parent.width - 32
            spacing: 8
            Text { visible: page.sel !== null; text: page.sel ? page.sel.name + "  " + page.sel.version : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
            Text {
                visible: page.sel !== null; width: parent.width; wrapMode: Text.WordWrap
                text: page.blocked !== "" ? page.blocked
                    : page.preview.length ? "Removes " + page.preview.length + " package" + (page.preview.length === 1 ? "" : "s") + ": " + page.preview.map(x => x.replace(/-[^-]+-[^-]+$/, "")).join(", ")
                    : "Checking…"
                color: page.blocked !== "" ? Theme.warn : Theme.muted; font.family: Theme.font; font.pixelSize: 12
            }
            Text { visible: page.status !== ""; text: page.status; color: Theme.amber; font.family: Theme.font; font.pixelSize: 12 }
            Row {
                visible: page.sel !== null
                spacing: 8
                SetButton { text: "Remove"; icon: "󰆴"; warn: true; enabled: page.blocked === "" && page.preview.length > 0 && !remover.running; onClicked: page.remove() }
                SetButton { text: "Cancel"; onClicked: { page.sel = null; page.status = "" } }
            }
        }
    }
    Repeater {
        model: page.shown
        delegate: Item {
            required property var modelData
            width: parent.width; height: 44
            HoverHandler { id: hv }
            Rectangle { anchors.fill: parent; color: page.sel && page.sel.name === modelData.name ? Theme.raised : hv.hovered ? Theme.surface : "transparent" }
            Text { x: 10; width: 260; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
            Text { x: 280; width: 60; anchors.verticalCenter: parent.verticalCenter; text: modelData.aur ? "AUR" : ""; color: Theme.amber; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
            Text { x: 340; width: parent.width - 340 - 120; anchors.verticalCenter: parent.verticalCenter; text: modelData.desc; color: Theme.muted; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 11 }
            Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: modelData.size; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.pick(modelData) }
        }
    }
}

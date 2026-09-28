// SetScripts.qml -- Settings > Scripts: the maintenance scripts in ~/.local/share/rice/scripts/ (same as the
// launcher's Scripts menu) with their descriptions. Run = in kitty (waits for Enter) or in the background.
// Add one: drop a .sh file there with "# title:", "# desc:", "# terminal: yes|no" header lines.
import QtQuick
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    property var scripts: []
    Process {
        id: lister
        running: true
        command: ["sh", "-c", "for f in \"$HOME\"/.local/share/rice/scripts/*.sh; do [ -f \"$f\" ] || continue; " +
                  "printf '%s\\t%s\\t%s\\t%s\\n' \"$f\" \"$(sed -n 's/^# title: //p' \"$f\")\" \"$(sed -n 's/^# desc: //p' \"$f\")\" \"$(sed -n 's/^# terminal: //p' \"$f\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: page.scripts = text.split("\n").filter(l => l).map(l => {
                const p = l.split("\t")
                return { path: p[0], title: p[1] || p[0].split("/").pop(), desc: p[2] || "", terminal: p[3] !== "no" }
            })
        }
    }
    Timer { id: relist; interval: 300; onTriggered: lister.running = true }
    function run(sc) {
        if (sc.terminal) Quickshell.execDetached(["kitty", "--class", "rice-script", "--title", sc.title, "-e", "bash", "-c",
            "bash \"$1\"; echo; read -rp 'Done. Press Enter to close.'", "_", sc.path])
        else Quickshell.execDetached(["bash", sc.path])
    }

    SetGroup { title: "Scripts"; action: "open folder"; onActionClicked: Quickshell.execDetached(["xdg-open", page.host.home + "/.local/share/rice/scripts"]) }
    Repeater {
        model: page.scripts
        delegate: SetRow {
            required property var modelData
            title: modelData.title
            desc: modelData.desc + (modelData.terminal ? "" : "  ·  runs in the background")
            Row {
                spacing: 8
                SetButton { text: "Delete"; warn: true; onClicked: { Quickshell.execDetached(["rm", "-f", modelData.path]); relist.restart() } }
                SetButton { text: "Edit"; onClicked: page.host.edit(modelData.path) }
                SetButton { text: "Run"; icon: modelData.terminal ? "󰆍" : "󰑓"; accent: true; onClicked: page.run(modelData) }
            }
        }
    }
    Process { id: maker; onExited: lister.running = true }
    function create() {
        const t = st.text.trim(); if (!t) return
        const f = t.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") + ".sh"
        maker.command = ["sh", "-c", "d=\"$HOME/.local/share/rice/scripts\"; mkdir -p \"$d\"; f=\"$d/$1\"; [ -e \"$f\" ] && exit 1; " +
            "printf '#!/bin/bash\\n# title: %s\\n# desc: %s\\n# terminal: %s\\n%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" > \"$f\"; chmod +x \"$f\"",
            "_", f, t, sd.text.trim(), term.current === 0 ? "yes" : "no", sc.text.trim() || "echo 'edit me'"]
        maker.running = true
        st.text = ""; sd.text = ""; sc.text = ""
    }
    SetGroup { title: "New script" }
    SetRow {
        title: "Name and description"
        Row { spacing: 6; SetInput { id: st; width: 220; placeholder: "title" } SetInput { id: sd; width: 320; placeholder: "what it does" } }
    }
    SetRow {
        title: "Command"
        desc: "One line to start with; Edit opens the whole file afterwards."
        Row {
            spacing: 6
            SetInput { id: sc; width: 360; placeholder: "e.g. yay -Syu"; onAccepted: page.create() }
            Seg { id: term; options: ["In terminal", "Background"]; current: 0; onPicked: (i) => current = i }
            SetButton { text: "Create"; accent: true; enabled: st.text.trim() !== ""; onClicked: page.create() }
        }
    }
}

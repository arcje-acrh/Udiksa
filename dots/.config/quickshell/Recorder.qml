// Recorder.qml -- singleton: is a screen recording running? ~/.local/bin/udiksa record tells it
// (`qs ipc call record started <mode>` / `stopped`); after a shell restart it reads $XDG_RUNTIME_DIR/udiksa-record.
// The notch (Status.qml) shows a blinking dot + the time while it runs; clicking it stops the recording.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string rt: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string bin: Quickshell.env("HOME") + "/.local/lib/udiksa/record"
    property bool on: false
    property string mode: ""
    property real since: 0                     // ms epoch

    Process {
        running: true
        command: ["sh", "-c", "f=\"$1/udiksa-record\"; [ -f \"$f\" ] && read -r pid t m _ < \"$f\" && kill -0 \"$pid\" 2>/dev/null && echo \"$t $m\"; true", "sh", root.rt]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                if (p.length >= 2) { root.since = Number(p[0]) * 1000; root.mode = p[1]; root.on = true }
            }
        }
    }
    readonly property var labels: ({ screen: "screen", region: "area", sound: "screen + sound" })
    function start(m) { Quickshell.execDetached([bin, m]) }
    function stop() { Quickshell.execDetached([bin, "stop"]) }

    IpcHandler {
        target: "record"
        function started(m: string): void {
            root.mode = m; root.since = Date.now(); root.on = true
            Osd.toast("󰑋", "Recording " + (root.labels[m] || m) + " · same keys stop")
        }
        function stopped(): void { root.on = false; Osd.toast("󰑋", "Recording saved") }
    }
}

// Modes.qml -- singleton: two switches in the notch's power panel (and `qs ipc call modes awake|game`).
//   Keep awake  a systemd "idle" inhibitor while on: hypridle skips locking, screen off and sleep (closing the lid
//               still does what Settings says)
//   Game mode   no animations, blur, shadows, transparency, gaps or rounding (~/.config/hypr/conf/gamemode.lua);
//               off = Hyprland reloads its normal config
// Both stay on through a shell restart and end at logout (marker files in $XDG_RUNTIME_DIR). While on, the notch
// shows their icon on the right (click = off).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string rt: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    property bool awake: false
    property bool game: false

    Process {   // after a shell restart: what was on
        running: true
        command: ["sh", "-c", "[ -e \"$1/udiksa-awake\" ] && echo awake; [ -e \"$1/udiksa-gamemode\" ] && echo game; true", "sh", root.rt]
        stdout: StdioCollector { onStreamFinished: { root.awake = text.indexOf("awake") >= 0; root.game = text.indexOf("game") >= 0 } }
    }
    Process {   // the inhibitor lives exactly as long as keep awake is on
        running: root.awake
        command: ["systemd-inhibit", "--what=idle", "--who=Udiksa", "--why=Keep awake (notch)", "--mode=block", "sleep", "infinity"]
    }

    function setAwake(on) {
        awake = on
        Quickshell.execDetached(["sh", "-c", on ? "touch \"$1/udiksa-awake\"" : "rm -f \"$1/udiksa-awake\"", "sh", rt])
        Osd.toast(on ? "󰅶" : "󰛊", on ? "Keep awake on · no lock, screen off or sleep" : "Keep awake off")
    }
    function setGame(on) {
        game = on
        Quickshell.execDetached(["sh", "-c", on
            ? "touch \"$1/udiksa-gamemode\"; hyprctl eval \"dofile(os.getenv('HOME') .. '/.config/hypr/conf/gamemode.lua')\""
            : "rm -f \"$1/udiksa-gamemode\"; hyprctl reload", "sh", rt])
        Osd.toast("󰊴", on ? "Game mode on · effects off" : "Game mode off")
    }

    IpcHandler {
        target: "modes"
        function awake(): void { root.setAwake(!root.awake) }
        function game(): void { root.setGame(!root.game) }
    }
}

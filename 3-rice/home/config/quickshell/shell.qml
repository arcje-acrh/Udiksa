// shell.qml -- Quickshell entry point (default config path ~/.config/quickshell).
// The notch bar on every screen (it also shows notifications: Notifs.qml), the password prompt, and our own
// messages for config reloads.
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    PolkitDialog {}    // password prompt for apps that need administrator rights
    ThemeSwitcher {}   // Super+T: full-screen theme + wallpaper switcher
    FloatWatcher {}    // floats pop-ups that get their title after opening (e.g. the Bitwarden unlock window)
    Lock {}            // lock screen (qs ipc call lock lock), same design as the boot login
    Settings {}        // Super+I: the Settings app
    AudioAuto {}       // new headphones / Bluetooth / USB audio become the output automatically
    Component.onCompleted: Agenda.init()   // start the reminder / alarm timer at login (Agenda.qml)

    // config reloads (after saving a file here): success = a short "Shell reloaded" in the notch,
    // failure = a red notification with the error -- instead of Quickshell's own pop-up box
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            Osd.show("󰑓", 1, "Shell reloaded", false, false)
        }
        function onReloadFailed(error) {
            Quickshell.inhibitReloadPopup()
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Quickshell", "Shell config error", error])
        }
    }
}

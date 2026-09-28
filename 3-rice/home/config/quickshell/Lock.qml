// Lock.qml -- the lock screen (Wayland session lock: nothing else is shown or clickable until unlocked).
// Design = login/LoginScreen.qml (same file as the boot login). Colours + wallpaper come from
// /var/lib/rice-greeter/ (written by rice-theme), so lock and boot login always look the same.
// Password check: PAM with pam/password.conf (pam_unix only).
// Lock with:  qs ipc call lock lock   (key bind, power panel "Lock", hypridle: idle + before sleep)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "login"

Scope {
    id: root
    readonly property string shared: "/var/lib/rice-greeter"
    property var colours: ({})
    property string password: ""
    property string me: ""

    FileView {
        path: root.shared + "/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.colours = JSON.parse(text()) } catch (e) {} }
    }
    property string host: ""
    property int userIndex: 0
    FileView { path: "/etc/hostname"; onLoaded: root.host = text().trim() }
    Process {                                   // who am I (the default user on the lock screen)
        running: true
        command: ["id", "-un"]
        stdout: StdioCollector { onStreamFinished: root.me = text.trim() }
    }
    FileView {                                  // everyone who can log in (uid 1000-59999 with a shell); click name = next
        path: "/etc/passwd"
        onLoaded: {
            const out = []
            for (const line of text().split("\n")) {
                const f = line.split(":")
                const uid = parseInt(f[2])
                if (f.length < 7 || uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6])) continue
                out.push({ login: f[0], name: (f[4] || "").split(",")[0] || f[0] })
            }
            root.users = out
        }
    }
    property var users: []

    PamContext {
        id: pam
        configDirectory: Qt.resolvedUrl("pam").toString().replace(/^file:\/\//, "")
        config: "password.conf"
        onPamMessage: { if (responseRequired) { respond(root.password); root.password = "" } }
        onCompleted: result => {
            if (result === PamResult.Success) sessionLock.locked = false
            else sessionLock.failed()
        }
        onError: sessionLock.failed()
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        signal failed()

        WlSessionLockSurface {
            color: "black"
            LoginScreen {
                id: screen
                mode: "lock"
                colours: root.colours
                wallpaper: root.shared + "/wallpaper.jpg"
                users: root.users
                host: root.host
                userIndex: Math.max(0, root.users.findIndex(u => u.login === root.me))
                onSubmit: (user, password, session) => {
                    root.password = password
                    pam.user = user
                    if (!pam.start()) screen.fail()
                }
                onPower: action => Quickshell.execDetached(["systemctl", action])
                Connections { target: sessionLock; function onFailed() { screen.fail() } }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { sessionLock.locked = true }
        function isLocked(): bool { return sessionLock.locked }
    }
}

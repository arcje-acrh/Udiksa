// Lock.qml -- the lock screen (Wayland session lock: nothing else is shown or clickable until unlocked).
// Design = login/LoginScreen.qml (same file as the boot login). Colours + wallpaper come from
// /var/lib/rice-greeter/ (written by udiksa theme), so lock and boot login always look the same.
// Password check: PAM with pam/password.conf (pam_unix only).
// Face unlock (hardware/faceid, Howdy), like Windows Hello: pam/face.conf runs next to the password field ONCE per
// arrival -- on lock (lid open only), after sleep and on lid open (qs ipc call lock face, from hypridle / the lid
// bind). A miss stops and says so under the password line; Space in the empty field or a click on it tries again.
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

    // ---- face unlock ----
    property bool howdy: false
    property string face: ""                    // "" | "scan" | "ok" | "miss" (LoginScreen draws it)
    Process {
        running: true
        command: ["test", "-e", "/usr/lib/security/pam_howdy.so"]
        onExited: code => root.howdy = code === 0
    }
    function lookForFace() {
        if (!howdy || !sessionLock.locked || facePam.active || face === "ok" || unlocking) return
        lidCheck.running = true                                 // a closed lid: no scan (opening it starts one)
    }
    Process {
        id: lidCheck
        command: ["sh", "-c", "grep -qs closed /proc/acpi/button/lid/*/state"]
        onExited: code => {
            if (code === 0 || facePam.active || root.unlocking) { if (root.face === "scan") root.face = ""; return }
            root.face = "scan"
            facePam.user = root.me
            if (!facePam.start()) root.face = "miss"
        }
    }
    PamContext {
        id: facePam
        configDirectory: pam.configDirectory
        config: "face.conf"
        onPamMessage: { if (responseRequired) respond("") }
        onCompleted: result => {
            if (result === PamResult.Success) { root.face = "ok"; root.unlock() }
            else root.face = "miss"
        }
        onError: root.face = "miss"
    }

    // ---- unlocking: the screen plays its way out, then the lock goes ----
    property bool unlocking: false
    function unlock() {
        if (unlocking) return
        unlocking = true
        if (facePam.active) facePam.abort()
        leaveTimer.start()
    }
    Timer {
        id: leaveTimer
        interval: 420
        onTriggered: { sessionLock.locked = false; root.unlocking = false; root.face = "" }
    }

    PamContext {
        id: pam
        configDirectory: Qt.resolvedUrl("pam").toString().replace(/^file:\/\//, "")
        config: "password.conf"
        onPamMessage: { if (responseRequired) { respond(root.password); root.password = "" } }
        onCompleted: result => {
            if (result === PamResult.Success) root.unlock()
            else sessionLock.failed()
        }
        onError: sessionLock.failed()
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        signal failed()
        onLockedChanged: if (locked) { root.face = ""; root.lookForFace() }

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
                face: root.face
                leaving: root.unlocking
                onFaceRetry: root.lookForFace()
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
        function face(): void { root.lookForFace() }   // after sleep (hypridle) and on lid open (binds.lua)
    }
}

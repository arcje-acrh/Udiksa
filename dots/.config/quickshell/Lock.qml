// Lock.qml -- the lock screen (Wayland session lock: nothing else is shown or clickable until unlocked).
// Two designs, by what locked:
//   key / idle / lid (qs ipc call lock lock)       LockScreen.qml: the desktop you left, blurred, clock, status, music
//   sleep / hibernation (qs ipc call lock sleep)   login/LoginScreen.qml: the boot login look, so waking = "logging in"
//                                                  (switches over if the screen was already locked)
// Locking: a screenshot of every screen goes to $XDG_RUNTIME_DIR/udiksa-lock/<screen>.png (grim, ~0.2 s), THEN the
// lock starts (a lock-time capture would only see the lock itself). Deleted on unlock. If grim hangs, it locks anyway.
// Password check: PAM with pam/password.conf (pam_unix only).
// Face unlock (hardware/faceid, Howdy): the login look (sleep / hibernation) scans by itself on waking (qs ipc call
// lock wake: hypridle after sleep + lid open); the overlay never does -- it says "Press space for face unlock".
// Space in the empty password field (or a click on that note) runs pam/face.conf once. A miss says so; Space retries.
// Lock with:  qs ipc call lock lock   (key bind, power panel "Lock", hypridle: idle + before sleep)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "login"

Scope {
    id: root
    property string password: ""
    property string me: ""
    property string myName: ""
    readonly property string shots: Quickshell.env("XDG_RUNTIME_DIR") + "/udiksa-lock"
    property bool asLogin: false                // locked for sleep / hibernation: the login look
    property string host: ""
    FileView { path: "/etc/hostname"; onLoaded: root.host = text().trim() }
    property var colours: ({})                  // the login look's colours (udiksa theme writes them for the greeter)
    FileView {
        path: "/var/lib/rice-greeter/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.colours = JSON.parse(text()) } catch (e) {} }
    }

    Process {                                   // who am I + my full name (GECOS), shown above the password
        running: true
        command: ["sh", "-c", "id -un; getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: { const l = text.split("\n"); root.me = l[0]; root.myName = l[1] || l[0] }
        }
    }

    // ---- locking: screenshot first, then lock ----
    function sleepLock() {                      // before sleep: no screenshot needed, lock at once
        asLogin = true
        if (!sessionLock.locked) { capture.running = false; captureGuard.stop(); sessionLock.locked = true }
    }
    function lock() {
        if (sessionLock.locked || capture.running) return
        capture.running = true
        captureGuard.start()
    }
    Process {
        id: capture
        command: ["sh", "-c", "d=\"$1\"; rm -rf \"$d\"; mkdir -m 700 \"$d\" && for o in $(hyprctl monitors -j | jq -r '.[].name'); do grim -l 0 -o \"$o\" \"$d/$o.png\" & done; wait", "sh", root.shots]
        onExited: { captureGuard.stop(); sessionLock.locked = true }   // (no-op when sleepLock() got there first)
    }
    Timer { id: captureGuard; interval: 1500; onTriggered: sessionLock.locked = true }   // never wait on a stuck grim

    // ---- face unlock ----
    property bool howdy: false
    property string face: ""                    // "" no Howdy | "ready" | "scan" | "ok" | "miss" (the screens draw it)
    Process {
        running: true
        command: ["test", "-e", "/usr/lib/security/pam_howdy.so"]
        onExited: code => root.howdy = code === 0
    }
    function lookForFace() {
        if (!howdy || !sessionLock.locked || facePam.active || face === "ok" || unlocking) return
        lidCheck.running = true                                 // a closed lid: no scan
    }
    Process {
        id: lidCheck
        command: ["sh", "-c", "grep -qs closed /proc/acpi/button/lid/*/state"]
        onExited: code => {
            if (code === 0 || facePam.active || root.unlocking) return
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

    // ---- unlocking: the blur eases back into the desktop, then the lock goes ----
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
        onTriggered: {
            sessionLock.locked = false; root.unlocking = false; root.face = ""; root.asLogin = false
            Quickshell.execDetached(["rm", "-rf", root.shots])
        }
    }

    function check(password, screen) {
        root.password = password
        pam.user = root.me
        if (!pam.start()) screen.fail()
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
        onLockedChanged: if (locked) root.face = root.howdy ? "ready" : ""

        WlSessionLockSurface {
            id: surface
            color: "black"
            Loader {
                anchors.fill: parent
                sourceComponent: root.asLogin ? loginLook : overlay
            }
            Component {
                id: overlay
                LockScreen {
                    id: screen
                    shot: surface.screen ? root.shots + "/" + surface.screen.name + ".png" : ""
                    name: root.myName
                    face: root.face
                    leaving: root.unlocking
                    onFaceRetry: root.lookForFace()
                    onSubmit: password => root.check(password, screen)
                    onPower: action => Quickshell.execDetached(["systemctl", action])
                    Connections { target: sessionLock; function onFailed() { screen.fail() } }
                }
            }
            Component {
                id: loginLook
                LoginScreen {
                    id: screen
                    mode: "lock"
                    colours: root.colours
                    wallpaper: "/var/lib/rice-greeter/wallpaper.jpg"
                    users: [{ login: root.me, name: root.myName }]
                    host: root.host
                    face: root.face
                    leaving: root.unlocking
                    onFaceRetry: root.lookForFace()
                    onSubmit: (user, password, session) => root.check(password, screen)
                    onPower: action => Quickshell.execDetached(["systemctl", action])
                    Connections { target: sessionLock; function onFailed() { screen.fail() } }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function sleep(): void { root.sleepLock() }    // hypridle before_sleep_cmd: the login look
        function wake(): void { if (root.asLogin) root.lookForFace() }   // after sleep / lid open: the login look scans
        function isLocked(): bool { return sessionLock.locked }
    }
}

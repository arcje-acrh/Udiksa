// greeter-shell.qml -- the boot login screen. udiksa theme copies it to /var/lib/rice-greeter/shell.qml;
// greetd starts it as user "greeter":  cage -s -- qs -p /var/lib/rice-greeter   (/etc/greetd/config.toml)
// Design: LoginScreen.qml (same file as the lock screen). Users = /etc/passwd (uid 1000-59999 with a real
// shell), sessions = /usr/share/wayland-sessions/*.desktop, Hyprland first (the default).
// Face unlock (hardware/faceid adds pam_howdy to /etc/pam.d/greetd, first): on open the greeter starts a greetd
// session at once, so Howdy looks while the hairline glides. A match logs in; a miss falls through to pam_unix's
// password prompt, which waits for Enter. A password typed during the scan is kept and sent at that prompt.
// An instant miss (<0.8 s: no Howdy / no face added) shows nothing. Space in the empty field retries.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

ShellRoot {
    id: shell
    property var colours: ({})
    property var users: []
    property var sessions: []
    property string password: ""
    property bool pending: false                  // a greetd session is open (scanning or at the password prompt)
    property bool prompt: false                   // pam_unix is waiting for the password
    property string face: ""                      // LoginScreen.face: "" | "scan" | "ok" | "miss"
    property bool howdy: false
    property real scanStart: 0
    property bool rescan: false                   // user changed mid-scan (greetd answers one request at a time)
    Process {
        running: true
        command: ["test", "-e", "/usr/lib/security/pam_howdy.so"]
        onExited: code => { shell.howdy = code === 0; shell.scan() }
    }
    function scan() {                             // open a session: Howdy goes first in the PAM stack
        if (!howdy || !Greetd.available || !users.length || screen.leaving) return
        if (pending) Greetd.cancelSession()
        pending = true; prompt = false
        face = "scan"; scanStart = Date.now()
        Greetd.createSession(users[screen.userIndex].login)
    }
    function reset() { Greetd.cancelSession(); pending = false; prompt = false; screen.fail() }
    readonly property string dir: Quickshell.shellDir
    property string host: ""
    FileView { path: "/etc/hostname"; onLoaded: shell.host = text().trim() }

    FileView {
        path: shell.dir + "/theme.json"
        onLoaded: { try { shell.colours = JSON.parse(text()) } catch (e) {} }
    }
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const out = []
            for (const line of text().split("\n")) {
                const f = line.split(":")
                const uid = parseInt(f[2])
                if (f.length < 7 || uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6])) continue
                const real = (f[4] || "").split(",")[0]
                out.push({ login: f[0], name: real || f[0] })
            }
            shell.users = out
            shell.scan()
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do " +
                  "printf '%s\\t%s\\t%s\\n' \"$(basename \"$f\" .desktop)\" " +
                  "\"$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)\" \"$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.trim().split("\n").filter(l => l).map(l => {
                    const [id, name, exec] = l.split("\t")
                    return { id: id, name: name || id, exec: exec }
                })
                list.sort((a, b) => (a.id === "hyprland" ? -1 : b.id === "hyprland" ? 1 : a.name.localeCompare(b.name)))
                shell.sessions = list
            }
        }
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) { Greetd.respond(""); return }   // info messages: acknowledge, show nothing
            if (shell.rescan) { shell.rescan = false; shell.scan(); return }
            if (shell.face === "scan") shell.face = Date.now() - shell.scanStart < 800 ? "" : "miss"
            if (shell.password !== "") { Greetd.respond(shell.password); shell.password = "" }
            else shell.prompt = true                  // wait for Enter
        }
        function onAuthFailure(message) { shell.face = ""; shell.reset() }
        function onError(error) { shell.face = ""; shell.reset() }
        function onReadyToLaunch() {
            if (shell.face === "scan") shell.face = "ok"
            screen.leaving = true                     // play out, then start the session
            launchTimer.start()
        }
    }

    Timer {
        id: launchTimer
        interval: 420
        onTriggered: {
            const s = shell.sessions[screen.sessionIndex]
            Greetd.launch(s ? s.exec.split(/\s+/).filter(x => x && !/^%/.test(x)) : ["Hyprland"], [], true)
        }
    }

    FloatingWindow {
        visible: true
        color: "black"
        LoginScreen {
            id: screen
            mode: "login"
            colours: shell.colours
            wallpaper: shell.dir + "/wallpaper.jpg"
            users: shell.users
            sessions: shell.sessions
            host: shell.host
            face: shell.face
            onUserIndexChanged: if (shell.prompt) shell.scan(); else if (shell.pending) shell.rescan = true   // look for them
            onFaceRetry: shell.scan()
            onSubmit: (user, password, session) => {
                if (!Greetd.available) { fail(); return }     // opened outside greetd (a preview)
                if (shell.prompt) { shell.prompt = false; Greetd.respond(password); return }
                shell.password = password                     // still scanning: sent at the prompt
                if (shell.pending) return
                if (shell.howdy) shell.scan()                 // a retry after a wrong password: face first again
                else { shell.pending = true; Greetd.createSession(user) }
            }
            onPower: action => Quickshell.execDetached(["systemctl", action])
        }
    }
}

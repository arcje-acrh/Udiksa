// greeter-shell.qml -- the boot login screen. rice-theme copies it to /var/lib/rice-greeter/shell.qml;
// greetd starts it as user "greeter":  cage -s -- qs -p /var/lib/rice-greeter   (/etc/greetd/config.toml)
// Design: LoginScreen.qml (same file as the lock screen). Users = /etc/passwd (uid 1000-59999 with a real
// shell), sessions = /usr/share/wayland-sessions/*.desktop, Hyprland first (the default).
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
            if (responseRequired) { Greetd.respond(shell.password); shell.password = "" }
            else Greetd.respond("")                   // info messages: acknowledge, show nothing
        }
        function onAuthFailure(message) { Greetd.cancelSession(); screen.fail() }
        function onError(error) { Greetd.cancelSession(); screen.fail() }
        function onReadyToLaunch() {
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
            onSubmit: (user, password, session) => {
                if (!Greetd.available) { fail(); return }     // opened outside greetd (a preview)
                shell.password = password
                Greetd.createSession(user)
            }
            onPower: action => Quickshell.execDetached(["systemctl", action])
        }
    }
}

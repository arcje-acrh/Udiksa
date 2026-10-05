// WifiPanel.qml -- the network panel in the grown notch: Wi-Fi (NetworkManager via Quickshell.Networking + nmcli)
// and the cable. A connected cable is shown in the details (it carries the traffic); a machine without Wi-Fi
// gets only the cable status (no Wi-Fi list or switches).
// Three views:
//   list     all networks (scrollable, scans while open). Click = connect / disconnect.
//            󰒓 = settings: a saved network opens its settings, a new one opens the sign-in form with
//            Advanced open. "+ hidden" = join a network that does not broadcast its name.
//            Right column: Wi-Fi on/off, Airplane mode (rfkill), connection details.
//   form     sign in to ANY network. Security is detected but can be changed: none, WPA personal
//            (WPA/WPA2/WPA3), WEP, or Enterprise / institute 802.1X (PEAP, TTLS, TLS, PWD; inner method;
//            username, anonymous identity; CA certificate from the system store or a file (Browse…), or
//            none; domain check; user certificate + private key for TLS). "Advanced" = WifiAdvanced.qml.
//   details  a saved network: WifiAdvanced settings + apply, show password, forget.
// While the form or details view is open the notch stays open (busy) and grows to fit (wantHeight);
// taller content scrolls. Connecting uses nmcli (an old profile with the same name is replaced);
// secrets are passed on nmcli's command line for the moment it runs.
import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root
    property string view: "list"
    property var target: null              // WifiNetwork being joined / edited (null = hidden network)
    property string status: ""             // last action's result line
    property bool statusBad: false
    readonly property int wantHeight: view === "list" ? 0 : Math.min(Theme.panelMaxHeight, formCol.implicitHeight + 40)
    readonly property bool busy: view !== "list"

    readonly property var dev: {
        if (!Power.wifi) return null
        const ds = Networking.devices.values
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) return ds[i]
        return null
    }
    readonly property var wired: {          // the connected cable, if any
        const ds = Networking.devices.values
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wired && ds[i].connected) return ds[i]
        return null
    }
    readonly property string ifname: wired ? wired.name : dev ? dev.name : ""
    Component.onCompleted: if (dev) dev.scannerEnabled = true
    Component.onDestruction: if (dev) dev.scannerEnabled = false

    readonly property var nets: {
        if (!dev) return []
        const ns = dev.networks.values.slice()
        ns.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
        return ns
    }
    readonly property var current: nets.length && nets[0].connected ? nets[0] : null

    // ---------- security kinds: 0 none, 1 WPA personal, 2 WEP, 3 enterprise ----------
    readonly property var kinds: ["open", "psk", "wep", "eap"]
    function kindIndex(n) {
        if (!n) return 1
        switch (n.security) {
        case WifiSecurityType.Open: case WifiSecurityType.Owe: return 0
        case WifiSecurityType.WpaPsk: case WifiSecurityType.Wpa2Psk: case WifiSecurityType.Sae: return 1
        case WifiSecurityType.StaticWep: return 2
        default: return 3      // WpaEap, Wpa2Eap, Wpa3SuiteB192, DynamicWep, Leap, Unknown
        }
    }
    function bars(v) { return ["󰤟", "󰤢", "󰤥", "󰤨"][Math.max(0, Math.min(3, Math.floor(v * 4 - 0.001)))] }
    function secName(n) { return ["open", "secured", "WEP", "enterprise"][kindIndex(n)] }

    // ---------- running nmcli steps one after another ----------
    property var steps: []
    property var onDone: null
    function run(list, done) { steps = list; onDone = done || null; status = "Working…"; statusBad = false; nextStep() }
    function nextStep() {
        if (steps.length === 0) { const d = onDone; onDone = null; if (d) d(); return }
        const s = steps[0]; steps = steps.slice(1)
        nm.command = s.cmd; nm.mayFail = !!s.mayFail; nm.running = true
    }
    Process {
        id: nm
        property bool mayFail: false
        stderr: StdioCollector { id: nmErr }
        onExited: (code) => {
            if (code !== 0 && !mayFail) {
                root.steps = []
                root.status = (nmErr.text.trim().split("\n").pop() || "Failed").replace(/^Error: /, "")
                root.statusBad = true
                return
            }
            root.nextStep()
        }
    }

    // ---------- airplane mode + IP (list view) ----------
    property bool airplane: false
    Process {
        id: rfRead
        running: true
        command: ["sh", "-c", "rfkill -n -o SOFT | grep -qv '^blocked' && echo 0 || echo 1"]
        stdout: StdioCollector { onStreamFinished: root.airplane = text.trim() === "1" }
    }
    Process { id: rfSet; onExited: rfRead.running = true }
    function setAirplane(on) { rfSet.command = ["rfkill", on ? "block" : "unblock", "all"]; rfSet.running = true }
    property string ip: ""
    Process {
        running: root.ifname !== ""
        command: ["sh", "-c", "ip -4 -o addr show dev \"$1\" | awk '{print $4}' | cut -d/ -f1", "sh", root.ifname]
        stdout: StdioCollector { onStreamFinished: root.ip = text.trim() }
    }

    // ---------- actions ----------
    function clicked(n) {
        status = ""
        if (n.connected) { n.disconnect(); return }
        if (n.known || kindIndex(n) === 0) { n.connect(); return }
        openForm(n, false)
    }
    function openForm(n, advanced) {
        target = n
        for (const f of [ssidF, pwF, idF, anonF, caF, domainF, certF, keyF, keyPwF]) f.text = ""
        form.sec = kindIndex(n); form.eap = 0; form.phase2 = 0; form.ca = 0
        form.showAdv = advanced; adv.reset()
        status = ""; statusBad = false; view = "form"
        Qt.callLater(() => (n === null ? ssidF : (form.sec === 3 ? idF : pwF)).focusIt())
    }
    function settings(n) { if (n.known) openDetails(n); else openForm(n, true) }
    function openDetails(n) {
        target = n; details.con = ""; details.shownPw = ""; advD.reset()
        info.command = ["sh", "-c",
            "for c in $(nmcli -t -f UUID,TYPE connection show | awk -F: '$2==\"802-11-wireless\"{print $1}'); do " +
            "  [ \"$(nmcli -g 802-11-wireless.ssid connection show \"$c\")\" = \"$1\" ] && " +
            "  nmcli -g connection.id,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns," +
            "802-11-wireless.cloned-mac-address,connection.metered connection show \"$c\" && exit 0; " +
            "done; exit 1", "sh", n.name]
        info.running = true
        status = ""; statusBad = false; view = "details"
    }
    function back() { view = "list"; target = null }

    function join() {
        const ssid = target ? target.name : ssidF.text.trim()
        if (!ssid) { status = "Enter the network name"; statusBad = true; return }
        const kind = kinds[form.sec]
        const eap = form.eaps[form.eap].toLowerCase()
        if ((kind === "psk" || kind === "wep" || (kind === "eap" && eap !== "tls")) && !pwF.text) {
            status = kind === "wep" ? "Enter the WEP key" : "Enter the password"; statusBad = true; return
        }
        if (!adv.valid()) { status = "Manual IP needs an address like 192.168.1.50/24"; statusBad = true; return }
        let o = ["nmcli", "connection", "add", "type", "wifi", "ifname", ifname, "con-name", ssid, "ssid", ssid]
        if (target === null) o.push("802-11-wireless.hidden", "yes")
        if (kind === "psk") o.push("wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", pwF.text)
        else if (kind === "wep") o.push("wifi-sec.key-mgmt", "none", "wifi-sec.wep-key-type", "1", "wifi-sec.wep-key0", pwF.text)
        else if (kind === "eap") {
            o.push("wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", eap)
            if (idF.text) o.push("802-1x.identity", idF.text)
            if (anonF.text && eap !== "tls") o.push("802-1x.anonymous-identity", anonF.text)
            if (eap === "peap" || eap === "ttls") o.push("802-1x.phase2-auth", form.phase2s[form.phase2].toLowerCase())
            if (eap !== "tls") o.push("802-1x.password", pwF.text)
            if (form.ca === 0) o.push("802-1x.system-ca-certs", "yes")
            else if (form.ca === 1) {
                if (!caF.text) { status = "Choose the CA certificate file (Browse…)"; statusBad = true; return }
                o.push("802-1x.ca-cert", caF.text)
            }
            if (domainF.text && form.ca !== 2) o.push("802-1x.domain-suffix-match", domainF.text)
            if (eap === "tls") {
                if (!certF.text || !keyF.text) { status = "TLS needs your certificate and private key"; statusBad = true; return }
                o.push("802-1x.client-cert", certF.text, "802-1x.private-key", keyF.text)
                if (keyPwF.text) o.push("802-1x.private-key-password", keyPwF.text)
            }
        }
        o = o.concat(adv.args())
        run([
            { cmd: ["nmcli", "connection", "delete", "id", ssid], mayFail: true },   // replace an old profile
            { cmd: o },
            { cmd: ["nmcli", "connection", "up", "id", ssid, "ifname", ifname] }
        ], () => { back(); status = "Connected to " + ssid; statusBad = false })
    }

    // ---------- file picker for certificates ----------
    property var pickInto: null
    FileDialog {
        id: picker
        title: "Choose a certificate or key file"
        nameFilters: ["Certificates and keys (*.pem *.crt *.cer *.der *.key *.p12 *.pfx)", "All files (*)"]
        onAccepted: {
            if (!root.pickInto) return
            root.pickInto.text = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            if (root.pickInto === caF) form.ca = 1
        }
    }
    function browse(field) { pickInto = field; picker.open() }

    // ======================= LIST VIEW =======================
    Row {
        visible: root.view === "list"
        anchors.fill: parent
        anchors.margins: 16; anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14

        Card {
            id: listCard
            visible: root.dev !== null          // no Wi-Fi: only the connection card, full width
            width: (parent.width - parent.spacing) * 0.62; height: parent.height
            spacing: 4
            Item {
                width: parent.width; height: 22
                PanelTitle { anchors.fill: parent; title: root.dev ? "Wi-Fi networks" : "Network"; action: root.dev ? "+ hidden network" : ""; onActionClicked: if (root.dev) root.openForm(null, false) }
            }
            ScrollList {
                id: netList
                width: parent.width
                height: listCard.height - 2 * listCard.pad - 22 - 4 - (statusLine.visible ? 22 : 0)
                model: root.nets
                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width - ListView.view.rightMargin
                    title: modelData.name
                    active: modelData.connected
                    actionIcon: "󰒓"
                    note: modelData.stateChanging ? "…"
                        : (modelData.connected ? "connected · " : "")
                          + (modelData.known && !modelData.connected ? "saved · " : "")
                          + Math.round(modelData.signalStrength * 100) + "%"
                    glyphs: (root.kindIndex(modelData) === 0 ? "" : "󰌾 ") + root.bars(modelData.signalStrength)
                    onClicked: root.clicked(modelData)
                    onActionClicked: root.settings(modelData)
                }
                Text {
                    parent: netList
                    visible: netList.count === 0
                    anchors.centerIn: parent
                    text: !root.dev ? "No Wi-Fi on this machine. " + (root.wired ? "Connected by cable." : "Plug in a network cable.")
                        : Networking.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
            }
            Text {
                id: statusLine
                visible: root.status !== ""
                width: parent.width; height: 18; elide: Text.ElideRight
                text: root.status; color: root.statusBad ? Theme.warn : Theme.amber
                font.family: Theme.font; font.pixelSize: 12
            }
        }

        Column {
            width: root.dev ? (parent.width - parent.spacing) * 0.38 : parent.width; height: parent.height
            spacing: 8
            Toggle {
                visible: root.dev !== null
                width: parent.width; label: "Wi-Fi"
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Toggle {
                visible: root.dev !== null
                width: parent.width; label: "Airplane mode"
                checked: root.airplane; busy: rfSet.running
                onToggled: root.setAirplane(!root.airplane)
            }
            Card {
                width: parent.width; height: parent.height - (root.dev ? 2 * 40 + 2 * parent.spacing : 0)
                spacing: 6
                PanelTitle { visible: !root.dev; title: "Network"; action: root.wired ? "cable" : "not connected" }
                Text {
                    visible: !root.dev && !root.wired
                    width: parent.width; wrapMode: Text.Wrap; bottomPadding: 4
                    text: "No Wi-Fi on this machine. Plug in a network cable; it connects by itself."
                    color: Theme.amber; font.family: Theme.font; font.pixelSize: 12
                }
                Repeater {
                    model: !root.dev && !root.wired ? [] : root.wired ? [
                        ["Network", "Cable"],
                        ["IP address", root.ip || "—"],
                        ["Interface", root.ifname || "—"]
                    ] : [
                        ["Network", root.current ? root.current.name : "—"],
                        ["IP address", root.ip || "—"],
                        ["Signal", root.current ? Math.round(root.current.signalStrength * 100) + "%" : "—"],
                        ["Security", root.current ? root.secName(root.current) : "—"],
                        ["Interface", root.ifname || "—"]
                    ]
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        Text { width: parent.width / 2; text: modelData[0]; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                        Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: modelData[1]; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                    }
                }
            }
        }
    }

    // ======================= FORM + DETAILS (scrolls when taller than the notch) =======================
    component Label: Text {
        width: 150; anchors.verticalCenter: parent.verticalCenter
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    component Button: Rectangle {
        id: btn
        property string text: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        width: bt.implicitWidth + 28; height: 30; radius: 2
        color: primary ? (bm.containsMouse ? Theme.amber : Theme.coral)
             : (danger ? (bm.containsMouse ? Qt.alpha(Theme.warn, 0.25) : Qt.alpha(Theme.warn, 0.12))
             : (bm.containsMouse ? Theme.hover : Theme.raised))
        Text { id: bt; anchors.centerIn: parent; text: btn.text; color: btn.primary ? Theme.bg : (btn.danger ? Theme.warn : Theme.text); font.family: Theme.font; font.pixelSize: 12; font.bold: true }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    Flickable {
        visible: root.view !== "list"
        anchors.fill: parent
        anchors.topMargin: 16; anchors.bottomMargin: 16
        contentHeight: formCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: formCol
            x: 22; width: parent.width - 44
            spacing: 10

            // header: back + title + status
            Item {
                width: parent.width; height: 26
                Text {
                    id: backBtn
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "‹ Back"; color: bk.containsMouse ? Theme.coral : Theme.muted
                    font.family: Theme.font; font.pixelSize: 12
                    MouseArea { id: bk; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                }
                Text {
                    anchors.left: backBtn.right; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
                    text: root.view === "details" ? (root.target ? root.target.name : "") + " · settings"
                        : (root.target ? "Connect to " + root.target.name : "Join a hidden network")
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.bold: true
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width / 2; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    text: root.status; color: root.statusBad ? Theme.warn : Theme.amber
                    font.family: Theme.font; font.pixelSize: 12
                }
            }

            // ---------- sign-in form ----------
            Column {
                id: form
                visible: root.view === "form"
                width: parent.width
                spacing: 8
                readonly property var eaps: ["PEAP", "TTLS", "TLS", "PWD"]
                readonly property var phase2s: ["MSCHAPv2", "PAP", "GTC", "MD5"]
                property int sec: 1
                property int eap: 0
                property int phase2: 0
                property int ca: 0            // 0 system store, 1 file, 2 don't check
                property bool showAdv: false
                readonly property bool isEap: sec === 3
                readonly property bool isTls: isEap && eaps[eap] === "TLS"

                Field { id: ssidF; visible: root.target === null; label: "Network name"; placeholder: "SSID (exactly as written)"; onAccepted: root.join() }
                Row { Label { text: "Security" } Seg { options: ["None", "WPA personal", "WEP", "Enterprise / institute"]; current: form.sec; onPicked: (i) => form.sec = i } }

                // enterprise
                Row { visible: form.isEap; Label { text: "Method" } Seg { options: form.eaps; current: form.eap; onPicked: (i) => form.eap = i } }
                Row {
                    visible: form.isEap && (form.eaps[form.eap] === "PEAP" || form.eaps[form.eap] === "TTLS")
                    Label { text: "Inner method" } Seg { options: form.phase2s; current: form.phase2; onPicked: (i) => form.phase2 = i }
                }
                Field { id: idF; visible: form.isEap; label: "Username"; placeholder: "e.g. student id or name@institute.edu"; onAccepted: root.join() }
                Field { id: anonF; visible: form.isEap && !form.isTls; label: "Anonymous identity"; placeholder: "optional, e.g. anonymous@institute.edu"; onAccepted: root.join() }

                // password / key
                Field { id: pwF; visible: form.sec !== 0 && !form.isTls; label: form.sec === 2 ? "WEP key" : "Password"; password: true; onAccepted: root.join() }

                // certificates (enterprise)
                Row { visible: form.isEap; Label { text: "CA certificate" } Seg { options: ["System store", "File", "Don't check"]; current: form.ca; onPicked: (i) => form.ca = i } }
                Field {
                    id: caF; visible: form.isEap && form.ca !== 2
                    label: "CA file"; browse: true
                    placeholder: form.ca === 0 ? "not needed with the system store -- or Browse… for your institute's file" : "/path/to/ca.pem"
                    onBrowseClicked: root.browse(caF)
                    onTextChanged: if (text && form.ca === 0) form.ca = 1
                }
                Text {
                    visible: form.isEap && form.ca === 2
                    text: "Not secure: any server using this network name could collect your password."
                    color: Theme.warn; font.family: Theme.font; font.pixelSize: 11
                }
                Field { id: domainF; visible: form.isEap && form.ca !== 2; label: "Domain"; placeholder: "optional, e.g. institute.edu (checks the server)"; onAccepted: root.join() }
                Field { id: certF; visible: form.isTls; label: "User certificate"; placeholder: "/path/to/user.pem"; browse: true; onBrowseClicked: root.browse(certF) }
                Field { id: keyF; visible: form.isTls; label: "Private key"; placeholder: "/path/to/user.key"; browse: true; onBrowseClicked: root.browse(keyF) }
                Field { id: keyPwF; visible: form.isTls; label: "Key password"; password: true; onAccepted: root.join() }

                Text {
                    text: (form.showAdv ? "▾" : "▸") + " Advanced (IP, DNS, MAC address, metered, auto-connect)"
                    color: advm.containsMouse ? Theme.coral : Theme.muted
                    font.family: Theme.font; font.pixelSize: 12
                    MouseArea { id: advm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: form.showAdv = !form.showAdv }
                }
                WifiAdvanced { id: adv; visible: form.showAdv; width: parent.width }

                Button { primary: true; text: nm.running ? "Connecting…" : "Connect"; onClicked: if (!nm.running) root.join() }
            }

            // ---------- saved network settings ----------
            Column {
                id: details
                visible: root.view === "details"
                width: parent.width
                spacing: 8
                property string con: ""          // NetworkManager profile name
                property string shownPw: ""
                property bool forgetArmed: false
                Process {
                    id: info
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const l = text.split("\n")
                            if (l.length < 8) { root.status = "No saved profile found"; root.statusBad = true; return }
                            details.con = l[0]
                            advD.load(l.slice(1, 8))
                        }
                    }
                }
                Process {
                    id: pwProc
                    stdout: StdioCollector { onStreamFinished: details.shownPw = text.split("\n").filter(x => x).join(" / ") || "(none stored)" }
                }
                Timer { id: fgDisarm; interval: 3000; onTriggered: details.forgetArmed = false }

                WifiAdvanced { id: advD; width: parent.width }
                Row {
                    spacing: 10
                    Button {
                        primary: true; text: "Apply + reconnect"
                        onClicked: {
                            if (!advD.valid()) { root.status = "Manual IP needs an address like 192.168.1.50/24"; root.statusBad = true; return }
                            root.run([
                                { cmd: ["nmcli", "connection", "modify", "id", details.con].concat(advD.args()) },
                                { cmd: ["nmcli", "connection", "up", "id", details.con] }
                            ], () => root.status = "Applied")
                        }
                    }
                    Button {
                        text: "Show password"
                        onClicked: { pwProc.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk,802-1x.password", "connection", "show", "id", details.con]; pwProc.running = true }
                    }
                    Button {
                        danger: true; text: details.forgetArmed ? "Confirm forget?" : "Forget network"
                        onClicked: {
                            if (!details.forgetArmed) { details.forgetArmed = true; fgDisarm.restart(); return }
                            details.forgetArmed = false
                            if (root.target) root.target.forget()
                            root.back()
                        }
                    }
                }
                Text {
                    visible: details.shownPw !== ""
                    text: "Password: " + details.shownPw
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 12
                }
            }
        }
    }
}

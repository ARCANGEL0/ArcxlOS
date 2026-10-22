// VPN — NetworkManager's VPN and WireGuard connections: import a config, connect, remove.
import QtQuick
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Connectivity"
    title: "VPN"
    desc: "Private tunnels for your connection. Import a WireGuard or OpenVPN file to add one."

    property var conns: []            // { name, uuid, type, device, state, kind }
    property var plugins: []
    property bool loaded: false
    property string busy: ""
    property string error: ""
    property string askFor: ""        // uuid waiting for a password

    Cmd { id: cmd }
    Cmd { id: poll }

    // nmcli -t escapes ':' inside fields as '\:'.
    function fields(line) {
        const out = []; let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (ch === ":") { out.push(cur); cur = ""; continue; }
            cur += ch;
        }
        out.push(cur);
        return out;
    }
    function kindOf(type, svc) {
        if (type === "wireguard") return "WireGuard";
        const m = /NetworkManager\.([a-z0-9_-]+)/i.exec(svc || "");
        const n = m ? m[1] : "vpn";
        return ({ openvpn: "OpenVPN", openconnect: "OpenConnect", strongswan: "IPsec", l2tp: "L2TP", pptp: "PPTP", vpnc: "Cisco VPNC", fortisslvpn: "Fortinet" })[n] || n;
    }
    function refresh() {
        if (poll.busy) return;
        poll.sh('nmcli -t -f NAME,UUID,TYPE,DEVICE,STATE connection show 2>/dev/null | while IFS= read -r l; do '
              + 'case "$l" in *:vpn:*|*:wireguard:*) u=$(printf %s "$l" | sed "s/^.*:\\([0-9a-f-]\\{36\\}\\):.*$/\\1/"); '
              + 's=$(nmcli -g vpn.service-type connection show "$u" 2>/dev/null); printf "%s|%s\\n" "$l" "$s";; esac; done; '
              + 'echo "--plugins"; for f in /usr/lib/NetworkManager/VPN/*.name; do [ -f "$f" ] && sed -n "s/^name=//p" "$f"; done',
            [], (code, out) => {
                const parts = out.split("--plugins");
                const list = [];
                for (const l of (parts[0] || "").split("\n")) {
                    if (!l.trim()) continue;
                    const bar = l.lastIndexOf("|");
                    const f = page.fields(l.slice(0, bar));
                    list.push({ name: f[0], uuid: f[1], type: f[2], device: f[3], state: f[4] || "",
                                kind: page.kindOf(f[2], l.slice(bar + 1)) });
                }
                page.conns = list.sort((a, b) => a.name.localeCompare(b.name));
                page.plugins = (parts[1] || "").split("\n").map(s => s.trim()).filter(s => s);
                page.loaded = true;
            });
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: page.refresh() }

    function up(c, password) {
        page.busy = c.uuid; page.error = "";
        const args = ["nmcli", "--wait", "40", "connection", "up", "uuid", c.uuid];
        if (password !== undefined) args.push("passwd-file", "/dev/stdin");
        cmd.run(args, (code, out, err) => {
            page.busy = "";
            if (code === 0) { page.askFor = ""; }
            else if (/secret|password/i.test(err + out) && password === undefined) page.askFor = c.uuid;
            else page.error = (err || out).trim().replace(/^Error: /, "") || "Couldn't connect.";
            page.refresh();
        }, password !== undefined ? "vpn.secrets.password:" + password + "\n" : undefined);
    }
    function down(c) {
        page.busy = c.uuid; page.error = "";
        cmd.run(["nmcli", "connection", "down", "uuid", c.uuid], (code, out, err) => {
            page.busy = ""; if (code !== 0) page.error = (err || out).trim(); page.refresh();
        });
    }
    function remove(c) {
        page.busy = c.uuid;
        cmd.run(["nmcli", "connection", "delete", "uuid", c.uuid], (code, out, err) => {
            page.busy = ""; if (code !== 0) page.error = (err || out).trim(); page.refresh();
        });
    }
    function importFile(path) {
        const type = /\.conf$/i.test(path) ? "wireguard" : "openvpn";
        if (type === "openvpn" && page.plugins.indexOf("openvpn") < 0) {
            page.error = "OpenVPN support isn't installed. Add it with  sudo pacman -S networkmanager-openvpn";
            return;
        }
        page.busy = "import"; page.error = "";
        cmd.run(["nmcli", "connection", "import", "type", type, "file", path], (code, out, err) => {
            page.busy = "";
            if (code !== 0) page.error = (err || out).trim().replace(/^Error: /, "") || "That file couldn't be imported.";
            page.refresh();
        });
    }

    FilePick {
        id: picker
        title: "Import a VPN configuration"
        filters: ["VPN configurations (*.ovpn *.conf)", "All files (*)"]
        onPicked: (p) => page.importFile(p)
    }

    header: AxButton { icon: "add"; text: "Import"; kind: "primary"; enabled_: page.busy === ""; onClicked: picker.open() }

    Label {
        visible: page.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
    }

    Section {
        title: "Connections"
        note: page.conns.filter(c => c.state === "activated").length ? "1 active" : ""
        EmptyState {
            visible: page.loaded && page.conns.length === 0
            icon: "vpn_key"
            title: "No VPNs yet"
            desc: "Import the .conf (WireGuard) or .ovpn (OpenVPN) file your provider gave you."
        }
        Repeater {
            model: page.conns
            delegate: Column {
                id: vc
                required property var modelData
                property bool topDivider: false
                readonly property bool on: modelData.state === "activated"
                readonly property bool going: modelData.state === "activating" || page.busy === modelData.uuid
                width: parent.width
                SRow {
                    topDivider: vc.topDivider
                    icon: vc.modelData.type === "wireguard" ? "key" : "vpn_lock"
                    title: vc.modelData.name
                    desc: vc.modelData.kind + (vc.on ? "  ·  connected on " + vc.modelData.device : vc.going ? "  ·  connecting…" : "")
                    Badge { visible: vc.on; text: "on"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                    ConfirmButton { label: ""; icon: "delete"; confirmText: "Remove"; visible: !vc.on
                                    anchors.verticalCenter: parent.verticalCenter; onConfirmed: page.remove(vc.modelData) }
                    AxButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: vc.on ? "Disconnect" : "Connect"; kind: vc.on ? "ghost" : "primary"
                        enabled_: !vc.going
                        onClicked: vc.on ? page.down(vc.modelData) : page.up(vc.modelData)
                    }
                }
                Item {
                    visible: page.askFor === vc.modelData.uuid
                    width: parent.width; height: 62
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Ax.pad + 46
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        AxField { id: vpw; width: 260; password: true; icon: "key"; placeholder: "VPN password"
                                  onAccepted: go.clicked(); Component.onCompleted: focusIn() }
                        AxButton { id: go; text: "Connect"; kind: "primary"; enabled_: vpw.text !== ""
                                   onClicked: { page.up(vc.modelData, vpw.text); vpw.text = ""; } }
                        AxButton { text: "Cancel"; onClicked: page.askFor = "" }
                    }
                }
            }
        }
    }

    Section {
        title: "Supported"
        SRow {
            icon: "key"; title: "WireGuard"; desc: "Built into NetworkManager"
            Badge { text: "ready"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "vpn_lock"; title: "OpenVPN"
            desc: page.plugins.indexOf("openvpn") >= 0 ? "NetworkManager plugin installed" : "Install  networkmanager-openvpn  to import .ovpn files"
            Badge { text: page.plugins.indexOf("openvpn") >= 0 ? "ready" : "missing"; tone: page.plugins.indexOf("openvpn") >= 0 ? "accent" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.plugins.filter(p => p !== "openvpn").length > 0
            icon: "extension"; title: "Other plugins"
            desc: page.plugins.filter(p => p !== "openvpn").join(", ")
        }
    }

    Section {
        title: "More privacy"
        SRow {
            icon: "shield_lock"; title: "GhostWired"
            desc: "Send everything through Tor instead of a single provider"
            clickable: true; chevron: true
            onClicked: NSS.Shell.openSettings("ghostwired")
        }
    }
}

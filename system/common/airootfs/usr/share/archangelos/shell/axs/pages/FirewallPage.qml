// Firewall — firewalld: on/off, how strict (its zone), which services and ports may come in, and
// which networks you trust. firewall-cmd and systemctl ask polkit, so you're prompted for your
// password when something changes.
import QtQuick
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Firewall"
    desc: "Decide what may connect to this computer from the network."

    property var f: ({})
    property var conns: []             // { name, uuid, device, zone }
    property bool loaded: false
    property string busy: ""
    property string error: ""
    readonly property bool installed: f.installed === "1"
    readonly property bool on: f.state === "running"
    readonly property var services: (f.services || "").split(" ").filter(s => s)
    readonly property var ports: (f.ports || "").split(" ").filter(s => s)
    readonly property var known: (f.known || "").split(" ")

    readonly property var profiles: [
        { z: "home", t: "Home", d: "Other devices on this network can find you (printers, casting, file sharing)" },
        { z: "public", t: "Public", d: "Cafés, hotels, airports: nothing comes in unless you allow it below" },
        { z: "drop", t: "Block all", d: "Nothing comes in at all, and connection attempts get no answer" }
    ]
    readonly property var catalog: [
        { s: "ssh", t: "Remote login (SSH)", i: "terminal" },
        { s: "mdns", t: "Network discovery (mDNS)", i: "travel_explore" },
        { s: "kdeconnect", t: "KDE Connect", i: "phonelink" },
        { s: "syncthing", t: "Syncthing", i: "sync" },
        { s: "steam-streaming", t: "Steam Remote Play", i: "sports_esports" },
        { s: "samba", t: "Windows file sharing", i: "folder_shared" },
        { s: "http", t: "Web server (HTTP)", i: "language" },
        { s: "https", t: "Web server (HTTPS)", i: "lock" }
    ]

    Cmd { id: cmd }
    function load() {
        cmd.sh('command -v firewall-cmd >/dev/null || { echo installed=0; exit 0; }; echo installed=1; '
             + 'echo "state=$(firewall-cmd --state 2>/dev/null)"; echo "enabled=$(systemctl is-enabled firewalld 2>/dev/null)"; '
             + 'z=$(firewall-cmd --get-default-zone 2>/dev/null); echo "zone=$z"; '
             + 'echo "services=$(firewall-cmd --zone="$z" --list-services 2>/dev/null)"; echo "ports=$(firewall-cmd --zone="$z" --list-ports 2>/dev/null)"; '
             + 'echo "known=$(firewall-cmd --get-services 2>/dev/null)"; echo "--conns"; '
             + 'nmcli -t -f NAME,UUID,DEVICE connection show --active 2>/dev/null | while IFS=: read -r n u d; do [ "$d" = lo ] && continue; echo "$n|$u|$d|$(nmcli -g connection.zone connection show "$u" 2>/dev/null)"; done', [], (c, o) => {
            const [a, b] = o.split("--conns");
            const m = {}; for (const l of a.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).trim(); }
            page.f = m;
            page.conns = (b || "").split("\n").filter(l => l.includes("|")).map(l => { const x = l.split("|"); return { name: x[0], uuid: x[1], device: x[2], zone: x[3] }; });
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function run(what, script, args) {
        page.busy = what; page.error = "";
        cmd.sh(script, args || [], (c, o, e) => {
            page.busy = "";
            if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "That didn't work.";
            page.load();
        });
    }
    // runtime and permanent together, so the change is live and survives a restart
    function fw(args) { page.run("fw", 'firewall-cmd "$@" && firewall-cmd --permanent "$@"', args); }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Section {
        visible: page.loaded && !page.installed
        EmptyState { icon: "local_fire_department"; title: "firewalld isn't installed"; desc: "Install it with  sudo pacman -S firewalld  and come back." }
    }

    Section {
        visible: page.installed
        title: "Firewall"
        SRow {
            icon: page.on ? "local_fire_department" : "fire_extinguisher"
            title: page.on ? "On" : "Off"
            desc: page.on ? "Incoming connections are checked against the rules below" : "Nothing is filtered — anything on the network can try to connect in"
            AxSwitch { checked: page.on; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("svc", on ? "systemctl enable --now firewalld" : "systemctl disable --now firewalld") }
        }
        Item {
            visible: page.on
            property bool topDivider: false
            width: parent.width; height: pcol.implicitHeight + 32
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: pcol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 10
                Label { text: "How strict"; font.weight: Font.Medium }
                Row {
                    width: parent.width; spacing: 10
                    Repeater {
                        model: page.profiles
                        Rectangle {
                            required property var modelData
                            readonly property bool sel: page.f.zone === modelData.z
                            width: (parent.width - 20) / 3; height: 96
                            radius: Ax.radiusSm
                            color: sel ? Ax.accentSoft : Ax.raised
                            border.width: sel ? 2 : 1; border.color: sel ? Ax.accent : Ax.border
                            Column {
                                anchors.fill: parent; anchors.margins: 12; spacing: 5
                                Label { text: modelData.t; font.weight: Font.Medium; color: parent.parent.sel ? Ax.text : Ax.subtext }
                                Label { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 3; text: modelData.d; color: Ax.muted; font.pixelSize: Ax.fsSmall }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: page.busy === "" && !parent.sel
                                        onClicked: page.run("zone", 'firewall-cmd --set-default-zone="$1"', [modelData.z]) }
                        }
                    }
                }
                Label { visible: page.profiles.every(p => p.z !== page.f.zone); text: "Currently: " + (page.f.zone || "—"); color: Ax.faint; font.pixelSize: Ax.fsSmall }
            }
        }
    }

    Section {
        visible: page.on && page.f.zone !== "drop"
        title: "Allowed in"
        note: page.f.zone ? page.f.zone + " zone" : ""
        Repeater {
            model: page.catalog.filter(c => page.known.indexOf(c.s) >= 0)
            SRow {
                required property var modelData
                icon: modelData.i; title: modelData.t
                AxSwitch { checked: page.services.indexOf(modelData.s) >= 0; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onToggled: (on) => page.fw([(on ? "--add-service=" : "--remove-service=") + modelData.s]) }
            }
        }
        Repeater {
            model: page.services.filter(s => !page.catalog.some(c => c.s === s))
            SRow {
                required property string modelData
                icon: "check_circle"; title: modelData; desc: "Service rule"
                AxButton { icon: "close"; kind: "danger"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.fw(["--remove-service=" + modelData]) }
            }
        }
        Repeater {
            model: page.ports
            SRow {
                required property string modelData
                icon: "settings_ethernet"; title: "Port " + modelData.replace("/", " · ").toUpperCase()
                AxButton { icon: "close"; kind: "danger"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.fw(["--remove-port=" + modelData]) }
            }
        }
        SRow {
            icon: "add"; title: "Open a port"
            AxField { id: portField; width: 110; placeholder: "8080 or 6000-6010"; anchors.verticalCenter: parent.verticalCenter }
            AxSegment { id: proto; options: ["TCP", "UDP"]; current: 0; onPicked: (i) => current = i; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Open"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                       enabled_: /^\d{1,5}(-\d{1,5})?$/.test(portField.text) && page.busy === ""
                       onClicked: { page.fw(["--add-port=" + portField.text + "/" + (proto.current ? "udp" : "tcp")]); portField.text = ""; } }
        }
    }

    Section {
        visible: page.on && page.conns.length > 0
        title: "Networks"
        Repeater {
            model: page.conns
            SRow {
                required property var modelData
                icon: /^wl/.test(modelData.device) ? "wifi" : "lan"
                title: modelData.name
                desc: "On this network, use"
                AxSelect {
                    width: 200; anchors.verticalCenter: parent.verticalCenter
                    readonly property var zs: ["", "home", "public", "trusted", "drop"]
                    model: ["The default above", "Home (trusted network)", "Public", "Trusted (allow everything)", "Block all"]
                    current: Math.max(0, zs.indexOf(modelData.zone))
                    onPicked: (i) => page.run("conn", 'nmcli connection modify "$1" connection.zone "$2" && nmcli device reapply "$3"', [modelData.uuid, zs[i], modelData.device])
                }
            }
        }
    }
}

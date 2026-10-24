// Services & Ports — what's listening for connections right now and who owns it, and the
// background services worth knowing about (start, stop, run at boot).
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Services & Ports"
    desc: "Everything waiting for a connection, and the services behind it."

    property var socks: []             // { proto, addr, port, proc, pid, scope }
    property bool full: false          // owners of every socket (needs your password)
    property var svcs: []              // { unit, label, active, enabled }
    property string busy: ""
    property string error: ""
    readonly property var catalog: [
        ["sshd", "Remote login (SSH)", "terminal"], ["bluetooth", "Bluetooth", "bluetooth"],
        ["cups", "Printing", "print"], ["avahi-daemon", "Network discovery (Avahi)", "travel_explore"],
        ["docker", "Docker", "deployed_code"], ["libvirtd", "Virtual machines (libvirt)", "computer"],
        ["smb", "Windows file sharing (Samba)", "folder_shared"], ["httpd", "Apache web server", "language"],
        ["nginx", "nginx web server", "language"], ["postgresql", "PostgreSQL", "database"],
        ["mariadb", "MariaDB", "database"], ["tor", "Tor (system)", "shield"], ["syncthing@", "Syncthing", "sync"],
        ["archangelos-ghostwired", "GhostWired tunnel", "shield_lock"], ["usbguard", "USBGuard", "usb"],
        ["firewalld", "Firewall", "local_fire_department"], ["fail2ban", "fail2ban", "gpp_bad"]
    ]

    Cmd { id: cmd }
    function parse(out) {
        const list = [];
        for (const l of out.split("\n")) {
            const f = l.trim().split(/\s+/);
            if (f.length < 5) continue;
            const local = f[4], i = local.lastIndexOf(":");
            const addr = local.slice(0, i).replace(/^\[|\]$/g, "").replace(/%.*$/, ""), port = local.slice(i + 1);
            const m = /users:\(\("([^"]+)",pid=(\d+)/.exec(l);
            const scope = /^(127\.|::1$)/.test(addr) ? "local" : /^(0\.0\.0\.0|\*|::)$/.test(addr) ? "all" : "one";
            if (!list.some(x => x.proto === f[0] && x.port === port && x.scope === scope))
                list.push({ proto: f[0], addr: addr, port: port, proc: m ? m[1] : "", pid: m ? m[2] : "", scope: scope });
        }
        return list.sort((a, b) => (a.scope === "local") - (b.scope === "local") || (+a.port) - (+b.port));
    }
    function load() {
        cmd.run(["ss", "-tulpnH"], (c, o) => { if (!page.full) page.socks = page.parse(o); });
        const units = page.catalog.map(x => x[0].endsWith("@") ? x[0] + Quickshell.env("USER") : x[0]);
        cmd.sh('for u in "$@"; do s=$(systemctl list-unit-files --no-legend "$u.service" 2>/dev/null | head -n1); [ -n "$s" ] || continue; '
             + 'echo "$u|$(systemctl is-active "$u" 2>/dev/null)|$(systemctl is-enabled "$u" 2>/dev/null)"; done', units, (c, o) => {
            page.svcs = o.split("\n").filter(l => l).map(l => {
                const f = l.split("|"), cat = page.catalog.find(x => f[0].startsWith(x[0].replace("@", "")));
                return { unit: f[0], label: cat ? cat[1] : f[0], icon: cat ? cat[2] : "settings", active: f[1] === "active", enabled: f[2] === "enabled" };
            });
        });
    }
    Component.onCompleted: load()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.load() }
    function showAll() {
        page.busy = "all";
        cmd.run(["/usr/lib/archangelos/axs-sec", "ports"], (c, o, e) => {
            page.busy = "";
            if (c === 0) { page.full = true; page.socks = page.parse(o); } else if (c !== 126) page.error = (e || o).trim();
        });
    }
    function sys(what, args) {
        page.busy = what; page.error = "";
        cmd.run(["systemctl"].concat(args), (c, o, e) => { page.busy = ""; if (c !== 0) page.error = (e || o).trim().split("\n").pop(); page.load(); });
    }

    header: AxButton { visible: !page.full; icon: "visibility"; text: "Show all owners"; enabled_: page.busy === ""; onClicked: page.showAll() }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Section {
        title: "Listening"
        note: page.socks.filter(s => s.scope !== "local").length + " reachable from the network"
        EmptyState { visible: page.socks.length === 0; icon: "lan"; title: "Nothing is listening"; desc: "No program on this computer is waiting for connections." }
        Repeater {
            model: page.socks
            SRow {
                required property var modelData
                icon: modelData.scope === "local" ? "home" : "public"
                title: (modelData.proc || "System process") + "  ·  " + modelData.port + "/" + modelData.proto
                desc: modelData.scope === "local" ? "This computer only" : modelData.scope === "all" ? "Open to every network this computer is on" : "Open on " + modelData.addr
                Badge { text: modelData.scope === "local" ? "local" : "network"; tone: modelData.scope === "local" ? "neutral" : "danger"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { visible: modelData.scope !== "local"; icon: "local_fire_department"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: NSS.Shell.openSettings("firewall") }
            }
        }
        SRow {
            visible: !page.full && page.socks.some(s => !s.proc)
            icon: "info"; dim: true; title: "Some owners are hidden"
            desc: "Programs run by the system only show up with your password — use Show all owners"
        }
    }

    Section {
        title: "Services"
        Repeater {
            model: page.svcs
            SRow {
                required property var modelData
                icon: modelData.icon; title: modelData.label
                desc: (modelData.active ? "Running" : "Stopped") + "  ·  " + (modelData.enabled ? "starts at boot" : "doesn't start at boot") + "  ·  " + modelData.unit
                Badge { visible: modelData.active; text: "running"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { text: modelData.enabled ? "Don't start at boot" : "Start at boot"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.sys("en", [modelData.enabled ? "disable" : "enable", modelData.unit]) }
                AxButton { text: modelData.active ? "Stop" : "Start"; kind: modelData.active ? "danger" : "primary"; enabled_: page.busy === ""
                           anchors.verticalCenter: parent.verticalCenter; onClicked: page.sys("run", [modelData.active ? "stop" : "start", modelData.unit]) }
            }
        }
    }
}

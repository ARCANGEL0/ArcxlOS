// Remote access — the SSH server: on/off, port, passwords vs keys, root login, your authorized
// keys, and recent logins. Config changes go to /etc/ssh/sshd_config.d/50-archangelos.conf and
// are checked with sshd -t before the server restarts.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Remote access"
    desc: "Let yourself log in to this computer over the network with SSH — or make sure nobody can."

    readonly property string sec: "/usr/lib/archangelos/axs-sec"
    readonly property string keysFile: Quickshell.env("HOME") + "/.ssh/authorized_keys"
    property var s: ({})
    property var keys: []              // { line, type, comment, fp }
    property var log: []
    property string busy: ""
    property string error: ""
    property string ip: ""
    readonly property bool installed: s.installed === "1"
    readonly property bool on: s.active === "active"
    readonly property bool pw: (s.pw || "yes") !== "no"
    readonly property bool root: (s.root || "prohibit-password") !== "no"

    Cmd { id: cmd }
    function load() {
        cmd.sh('command -v sshd >/dev/null && echo installed=1 || echo installed=0; echo "active=$(systemctl is-active sshd 2>/dev/null)"; echo "enabled=$(systemctl is-enabled sshd 2>/dev/null)"; '
             + 'c="$(cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config 2>/dev/null)"; '
             + 'echo "port=$(printf %s "$c" | grep -iE "^\\s*Port\\s" | head -n1 | awk "{print \\$2}")"; '
             + 'echo "pw=$(printf %s "$c" | grep -iE "^\\s*PasswordAuthentication\\s" | head -n1 | awk "{print tolower(\\$2)}")"; '
             + 'echo "root=$(printf %s "$c" | grep -iE "^\\s*PermitRootLogin\\s" | head -n1 | awk "{print tolower(\\$2)}")"; '
             + 'echo "ip=$(ip -4 -o addr show scope global 2>/dev/null | awk "{print \\$4}" | cut -d/ -f1 | head -n1)"; echo "--keys"; '
             + 'f="$1"; [ -f "$f" ] && while IFS= read -r l; do case "$l" in ""|\\#*) continue;; esac; '
             + 'fp=$(printf "%s\\n" "$l" | ssh-keygen -lf - 2>/dev/null | awk "{print \\$2}"); printf "%s\\t%s\\n" "$fp" "$l"; done < "$f"', [page.keysFile], (c, o) => {
            const [a, b] = o.split("--keys");
            const m = {}; for (const l of a.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).trim(); }
            page.s = m;
            page.keys = (b || "").split("\n").filter(l => l.includes("\t")).map(l => {
                const [fp, line] = l.split("\t"); const f = line.trim().split(/\s+/);
                return { line: line, type: f[0], comment: f.slice(2).join(" ") || "no comment", fp: fp };
            });
        });
    }
    Component.onCompleted: load()
    function act(what, argv, input) {
        page.busy = what; page.error = "";
        cmd.run(argv, (c, o, e) => { page.busy = ""; if (c === 126 || c === 127) page.error = "Cancelled."; else if (c !== 0) page.error = (e || o).trim().split("\n").pop(); page.load(); }, input);
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Section {
        visible: page.s.installed === "0"
        EmptyState { icon: "terminal"; title: "OpenSSH isn't installed"; desc: "Install it with  sudo pacman -S openssh." }
    }

    Section {
        visible: page.installed
        title: "SSH server"
        SRow {
            icon: "terminal"; title: page.on ? "On" : "Off"
            desc: page.on ? "Connect with  ssh " + Quickshell.env("USER") + "@" + (page.s.ip || "this-computer") + ((page.s.port || "22") !== "22" ? " -p " + page.s.port : "")
                          : "Nobody can log in over the network"
            AxSwitch { checked: page.on; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.act("svc", ["systemctl", on ? "enable" : "disable", "--now", "sshd"]) }
        }
        SRow {
            icon: "password"; title: "Allow password logins"
            desc: page.pw ? "Anyone who guesses a password gets in. Keys only is much safer" : "Keys only — passwords are refused"
            Badge { visible: page.pw && page.on; text: "risky"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter }
            AxSwitch { checked: page.pw; enabled_: page.busy === "" && (page.pw || true); anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => { if (!on && page.keys.length === 0) { page.error = "Add a key below first, or you'll lock yourself out."; return; }
                                            page.act("pw", [page.sec, "ssh-set", "passwords", on ? "1" : "0"]); } }
        }
        SRow {
            icon: "admin_panel_settings"; title: "Allow root to log in"; desc: "With a key only, even when on. Off is safer"
            AxSwitch { checked: page.root; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.act("root", [page.sec, "ssh-set", "rootlogin", on ? "1" : "0"]) }
        }
        SRow {
            icon: "settings_ethernet"; title: "Port"; desc: "Moving off 22 cuts down on automated guessing"
            AxField { id: portF; width: 80; text: page.s.port || "22"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { visible: portF.text !== (page.s.port || "22"); text: "Set"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                       enabled_: /^\d{1,5}$/.test(portF.text) && +portF.text <= 65535 && page.busy === ""
                       onClicked: page.act("port", [page.sec, "ssh-set", "port", portF.text]) }
        }
    }

    Section {
        visible: page.installed
        title: "Your keys"
        note: page.keys.length ? page.keys.length + "" : ""
        EmptyState { visible: page.keys.length === 0; icon: "key"; title: "No keys yet"; desc: "Paste the public key (id_ed25519.pub) of each computer you'll log in from." }
        Repeater {
            model: page.keys
            SRow {
                required property var modelData
                icon: "key"; title: modelData.comment; desc: modelData.type + "  ·  " + modelData.fp
                AxButton { icon: "delete"; kind: "danger"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.act("rm", ["sh", "-c", 'f="$1"; grep -vxF -- "$2" "$f" > "$f.new"; mv -f "$f.new" "$f"; chmod 600 "$f"', "sh", page.keysFile, modelData.line]) }
            }
        }
        SRow {
            icon: "add"; title: "Add a key"
            AxField { id: keyF; width: 360; placeholder: "ssh-ed25519 AAAA… you@laptop"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Add"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                       enabled_: /^(ssh-(ed25519|rsa|dss)|ecdsa-sha2-\S+|sk-\S+)\s+[A-Za-z0-9+\/=]{40,}(\s.*)?$/.test(keyF.text.trim())
                       onClicked: { page.act("add", ["sh", "-c", 'mkdir -p "$(dirname "$1")" && chmod 700 "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1" && chmod 600 "$1"', "sh", page.keysFile, keyF.text.trim()]); keyF.text = ""; } }
        }
    }

    Section {
        visible: page.installed
        title: "Recent logins"
        SRow {
            visible: page.log.length === 0
            icon: "history"; title: "Show logins and failed attempts"; desc: "From the system journal"
            AxButton { text: "Show"; anchors.verticalCenter: parent.verticalCenter
                       onClicked: cmd.run([page.sec, "ssh-log"], (c, o) => { page.log = o.split("\n").filter(l => l).reverse(); if (!page.log.length) page.log = ["—  nothing recorded"]; }) }
        }
        Repeater {
            model: page.log
            SRow {
                required property string modelData
                readonly property bool bad: /Failed|Invalid|failure/.test(modelData)
                icon: bad ? "gpp_bad" : "login"
                title: (modelData.match(/(Accepted \S+|Failed password|Invalid user|authentication failure)/) || ["Entry"])[0]
                desc: modelData.replace(/^(\S+).*?sshd\[\d+\]:\s*/, "$1  ").slice(0, 140)
                dim: !bad
            }
        }
    }
}

// Boot & startup — the bootloader (how long it waits, which entry it defaults to), the kernels
// installed, the splash screen, and what the login screen does. Everything here changes system
// files, so /usr/lib/archangelos/axs-admin asks for your password.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Boot & startup"
    desc: "The boot menu, kernels, splash screen and automatic sign-in."

    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    property var b: ({})                 // boot-get key/values
    property var entries: []
    property var kernels: []             // { pkg, version, installed }
    property var splash: ({})
    property var login: ({})
    property var users: []
    property bool loaded: false
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: act }

    // Everything here is read without root — these files and tools are world-readable. Only the
    // changes below go through axs-admin (pkexec), so just viewing the page never asks for a password.
    function load() {
        cmd.sh('if [ -d /sys/firmware/efi ] && [ -f /boot/loader/loader.conf ]; then echo "kind=systemd-boot"; '
             + '  echo "timeout=$(sed -n \'s/^timeout[[:space:]]*\\([0-9]*\\).*/\\1/p\' /boot/loader/loader.conf | head -n1)"; '
             + '  echo "default=$(sed -n \'s/^default[[:space:]]*\\(.*\\)/\\1/p\' /boot/loader/loader.conf | head -n1)"; '
             + '  for e in /boot/loader/entries/*.conf; do [ -e "$e" ] || continue; echo "entry=$(basename "$e" .conf)|$(sed -n \'s/^title[[:space:]]*\\(.*\\)/\\1/p\' "$e" | head -n1)"; done; '
             + 'elif [ -f /etc/default/grub ]; then echo "kind=grub"; '
             + '  echo "timeout=$(sed -n \'s/^GRUB_TIMEOUT=\\([0-9]*\\).*/\\1/p\' /etc/default/grub | head -n1)"; '
             + '  echo "default=$(sed -n \'s/^GRUB_DEFAULT=\\(.*\\)/\\1/p\' /etc/default/grub | tr -d \'\\"\' | head -n1)"; '
             + '  [ -r /boot/grub/grub.cfg ] && grep -E "^[[:space:]]*menuentry " /boot/grub/grub.cfg | sed -E "s/^[[:space:]]*menuentry .(.[^\\x27\\"]*).*/entry=\\1/" | head -n 20; '
             + 'else echo "kind=unknown"; fi; '
             + 'echo "cmdline=$(cat /proc/cmdline)"; echo "running=$(uname -r)"; '
             + 'for k in linux linux-lts linux-zen linux-hardened; do if pacman -Q "$k" >/dev/null 2>&1; then echo "kernel=$k|$(pacman -Q "$k" | awk \'{print $2}\')|installed"; else echo "kernel=$k||available"; fi; done', [], (c, o) => {
            const m = {}; page.entries = []; page.kernels = [];
            for (const l of o.split("\n")) {
                const i = l.indexOf("="); if (i < 0) continue;
                const k = l.slice(0, i), v = l.slice(i + 1);
                if (k === "entry") { const p = v.split("|"); page.entries.push({ id: p[0], title: p[1] || p[0] }); }
                else if (k === "kernel") { const p = v.split("|"); page.kernels.push({ pkg: p[0], version: p[1], installed: p[2] === "installed" }); }
                else m[k] = v;
            }
            page.b = m; page.loaded = true;
        });
        cmd.sh('if command -v plymouth-set-default-theme >/dev/null; then echo "installed=1"; echo "current=$(plymouth-set-default-theme 2>/dev/null)"; plymouth-set-default-theme -l 2>/dev/null | sed "s/^/theme=/"; else echo "installed=0"; fi', [], (c, o) => {
            const m = { themes: [] };
            for (const l of o.split("\n")) { const i = l.indexOf("="); if (i < 0) continue; const k = l.slice(0, i), v = l.slice(i + 1); if (k === "theme") m.themes.push(v); else m[k] = v; }
            page.splash = m;
        });
        cmd.sh('d=/etc/sddm.conf.d; echo "autologin=$(sed -n \'s/^User=\\(.*\\)/\\1/p\' "$d"/*.conf 2>/dev/null | head -n1)"; '
             + 'echo "numlock=$(sed -n \'s/^Numlock=\\(.*\\)/\\1/p\' "$d"/*.conf 2>/dev/null | head -n1)"', [], (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1); } page.login = m;
        });
        cmd.sh('getent passwd | awk -F: \'$3>=1000 && $3<60000 {print $1}\'', [], (c, o) => page.users = o.split("\n").filter(x => x));
    }
    Component.onCompleted: load()

    function run(what, args, ok) {
        page.busy = what; page.error = ""; page.notice = "";
        act.run([page.admin].concat(args), (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "That didn't work.";
            else { page.notice = typeof ok === "function" ? ok(o) : ok; noticeT.restart(); }
            page.load();
        });
    }
    Timer { id: noticeT; interval: 5000; onTriggered: page.notice = "" }

    readonly property var timeouts: [0, 1, 3, 5, 10, 30]
    readonly property string kind: page.b.kind || ""

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }
    Label { visible: page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    // ── bootloader ────────────────────────────────────────────────────────────────
    Section {
        title: "Boot menu"
        note: page.kind === "grub" ? "GRUB" : page.kind === "systemd-boot" ? "systemd-boot" : ""
        SRow {
            visible: page.loaded && page.kind === "unknown"
            icon: "help"; title: "Bootloader not recognised"; desc: "This looks like a live session — boot settings appear once ArchangelOS is installed."
        }
        SRow {
            visible: page.kind !== "unknown" && page.kind !== ""
            icon: "timer"; title: "Wait before booting"; desc: page.b.timeout === "0" ? "Boots straight into the default entry" : "Shows the menu for this long"
            AxSelect { width: 150; anchors.verticalCenter: parent.verticalCenter
                       model: page.timeouts.map(t => t === 0 ? "No menu" : t + " seconds")
                       current: Math.max(0, page.timeouts.indexOf(parseInt(page.b.timeout)))
                       onPicked: (i) => page.run("timeout", ["boot-timeout", String(page.timeouts[i])], "Boot menu updated.") }
        }
        SRow {
            visible: page.entries.length > 1
            icon: "list"; title: "Default entry"; desc: "What boots when the menu times out"
            AxSelect { width: 260; anchors.verticalCenter: parent.verticalCenter
                       model: page.entries.map(e => e.title)
                       current: { const d = page.b.default; const n = parseInt(d);
                                  if (!isNaN(n) && String(n) === d) return Math.min(n, page.entries.length - 1);
                                  return Math.max(0, page.entries.findIndex(e => e.id === d || e.title === d)); }
                       onPicked: (i) => page.run("default", ["boot-default", page.kind === "grub" ? String(i) : page.entries[i].id], "Default entry set.") }
        }
        SRow {
            visible: page.kind !== "unknown" && page.kind !== ""
            icon: "visibility"; title: "Quiet boot"
            desc: /(^|\s)quiet(\s|$)/.test(page.b.cmdline || "") ? "Hides kernel messages behind the splash" : "Shows kernel messages while booting"
            AxSwitch { checked: /(^|\s)quiet(\s|$)/.test(page.b.cmdline || ""); enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("quiet", ["boot-quiet", on ? "1" : "0"], "Boot output updated — takes effect next boot.") }
        }
    }

    // ── kernels ──────────────────────────────────────────────────────────────────
    Section {
        title: "Kernels"
        note: "running " + (page.b.running || "")
        Repeater {
            model: page.kernels
            SRow {
                required property var modelData
                readonly property bool running: (page.b.running || "").includes(modelData.pkg === "linux" ? "arch" : modelData.pkg.replace("linux-", ""))
                                                 || (modelData.pkg === "linux" && !/lts|zen|hardened/.test(page.b.running || ""))
                icon: "memory"
                title: ({ "linux": "Linux (standard)", "linux-lts": "Linux LTS (long-term)", "linux-zen": "Linux Zen (desktop-tuned)", "linux-hardened": "Linux Hardened (security)" })[modelData.pkg] || modelData.pkg
                desc: modelData.installed ? "Installed" + (modelData.version ? "  ·  " + modelData.version : "") : "Not installed"
                Badge { visible: parent.running && modelData.installed; text: "running now"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { visible: !modelData.installed; text: page.busy === "k-" + modelData.pkg ? "Installing…" : "Install"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.run("k-" + modelData.pkg, ["kernel-install", modelData.pkg], "Kernel installed — pick it in the boot menu.") }
                ConfirmButton { visible: modelData.installed && !parent.running; label: "Remove"; confirmText: "Remove?"; anchors.verticalCenter: parent.verticalCenter
                                onConfirmed: page.run("k-" + modelData.pkg, ["kernel-remove", modelData.pkg], "Kernel removed.") }
            }
        }
    }

    // ── splash ───────────────────────────────────────────────────────────────────
    Section {
        visible: page.splash.installed === "1"
        title: "Splash screen"
        SRow {
            icon: "image"; title: "Boot splash theme"; desc: "The screen shown while the system starts (Plymouth)"
            AxSelect { width: 220; anchors.verticalCenter: parent.verticalCenter
                       model: page.splash.themes || []
                       current: Math.max(0, (page.splash.themes || []).indexOf(page.splash.current))
                       onPicked: (i) => page.run("splash", ["splash-set", page.splash.themes[i]], "Splash theme set — takes effect next boot.") }
        }
    }

    // ── login ────────────────────────────────────────────────────────────────────
    Section {
        title: "Login screen"
        SRow {
            icon: "login"; title: "Sign in automatically"
            desc: page.login.autologin ? "Boots straight to " + page.login.autologin + "'s desktop — no password at startup" : "Ask for a password at startup (recommended)"
            AxSwitch { checked: !!page.login.autologin; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("auto", ["login-autologin", on ? (page.login.autologin || page.users[0] || "") : ""], on ? "Automatic sign-in on." : "Automatic sign-in off.") }
        }
        SRow {
            visible: !!page.login.autologin && page.users.length > 1
            icon: "person"; title: "Sign in as"
            AxSelect { width: 180; anchors.verticalCenter: parent.verticalCenter; model: page.users
                       current: Math.max(0, page.users.indexOf(page.login.autologin))
                       onPicked: (i) => page.run("auto", ["login-autologin", page.users[i]], "Automatic sign-in user set.") }
        }
        SRow {
            icon: "dialpad"; title: "Num Lock on at the login screen"
            AxSwitch { checked: (page.login.numlock || "").toLowerCase() === "on"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("num", ["login-numlock", on ? "1" : "0"], "Saved.") }
        }
        SRow {
            icon: "lock"; title: "Lock screen & idle"; desc: "Timers, password and what shows when locked"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("lock")
        }
    }
}

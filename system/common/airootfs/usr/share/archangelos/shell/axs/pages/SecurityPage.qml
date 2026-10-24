// Security overview — one look at how protected this computer is. Each check links to the page
// that fixes it.
import QtQuick
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Security overview"
    desc: "How well this computer is protected, and what to do about it."

    property var r: ({})
    property bool loaded: false
    Cmd { id: cmd }
    function load() {
        cmd.sh('echo "fw=$(systemctl is-active firewalld 2>/dev/null)"; '
             + 'echo "ssh=$(systemctl is-active sshd 2>/dev/null)"; '
             + 'echo "sshpw=$(cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config 2>/dev/null | grep -iE "^\\s*PasswordAuthentication" | head -n1 | awk "{print tolower(\\$2)}")"; '
             + 's=$(findmnt -no SOURCE / 2>/dev/null); echo "crypt=$(lsblk -nso TYPE "$s" 2>/dev/null | grep -c crypt)"; '
             + 'echo "sb=$(od -An -t u1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | tr -d " ")"; '
             + 'echo "efi=$([ -d /sys/firmware/efi ] && echo 1 || echo 0)"; '
             + 'echo "aa=$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)"; '
             + 'echo "usb=$(systemctl is-active usbguard 2>/dev/null)"; '
             + 'echo "kptr=$(sysctl -n kernel.kptr_restrict 2>/dev/null)"; echo "ptrace=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null)"; '
             + 'echo "bpf=$(sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null)"; '
             + 'echo "ghost=$([ -f /run/archangelos-ghostwired/state ] && echo 1 || echo 0)"; '
             + 'echo "upd=$(command -v checkupdates >/dev/null && timeout 25 checkupdates 2>/dev/null | wc -l || echo -1)"', [], (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).trim(); }
            page.r = m; page.loaded = true;
        });
    }
    Component.onCompleted: load()

    readonly property var checks: !loaded ? [] : [
        { ok: r.fw === "active", icon: "local_fire_department", t: "Firewall", page: "firewall",
          d: r.fw === "active" ? "On — unwanted incoming connections are blocked" : "Off — anything can try to connect in" },
        { ok: r.upd === "0", icon: "system_update", t: "Updates", page: "updates",
          d: r.upd === "-1" ? "Can't check (pacman-contrib missing)" : r.upd === "0" ? "Everything is current" : r.upd + " updates waiting, some may be security fixes" },
        { ok: r.ssh !== "active" || r.sshpw === "no", icon: "terminal", t: "Remote access", page: "ssh",
          d: r.ssh !== "active" ? "SSH is off" : r.sshpw === "no" ? "SSH is on, keys only" : "SSH accepts passwords — guessable from the network" },
        { ok: r.crypt !== "0" && r.crypt !== "", icon: "enhanced_encryption", t: "Disk encryption", page: "encryption",
          d: r.crypt !== "0" && r.crypt !== "" ? "The system drive is encrypted" : "The system drive isn't encrypted — a stolen disk can be read" },
        { ok: r.sb === "1" || r.efi === "0", icon: "verified_user", t: "Secure Boot", page: "hardening", info: true,
          d: r.efi === "0" ? "Not a UEFI machine" : r.sb === "1" ? "On" : "Off — the firmware doesn't check what it boots" },
        { ok: r.aa === "Y", icon: "policy", t: "AppArmor", page: "hardening",
          d: r.aa === "Y" ? "Confining apps with profiles" : "Off — apps aren't confined" },
        { ok: +r.kptr >= 1 && +r.ptrace >= 1 && +r.bpf >= 1, icon: "memory", t: "Kernel hardening", page: "hardening",
          d: +r.kptr >= 1 && +r.ptrace >= 1 && +r.bpf >= 1 ? "Recommended restrictions are on" : "Some recommended restrictions are off" },
        { ok: r.usb === "active", icon: "usb", t: "USB protection", page: "usb",
          d: r.usb === "active" ? "New USB devices wait for your OK" : "Any USB device works the moment it's plugged in" }
    ]
    readonly property int score: checks.length ? Math.round(100 * checks.filter(c => c.ok).length / checks.length) : 0

    Rectangle {
        width: parent.width; height: 170
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Canvas {
            id: ring
            x: 28; anchors.verticalCenter: parent.verticalCenter
            width: 118; height: 118
            property real v: page.score / 100
            Behavior on v { NumberAnimation { duration: Ax.durSlow * 2; easing.type: Easing.OutCubic } }
            onVChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"); g.reset();
                const c = width / 2, R = c - 7;
                g.lineWidth = 7; g.lineCap = "round";
                g.strokeStyle = Ax.alpha(Ax.text, 0.07); g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.stroke();
                g.strokeStyle = page.score >= 75 ? Ax.accent : Ax.danger;
                g.beginPath(); g.arc(c, c, R, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * v); g.stroke();
            }
            Column {
                anchors.centerIn: parent
                Label { anchors.horizontalCenter: parent.horizontalCenter; mono: true; font.pixelSize: 30; text: page.loaded ? page.score : "…" }
                Label { anchors.horizontalCenter: parent.horizontalCenter; caption: true; text: "of 100" }
            }
        }
        Column {
            anchors.left: ring.right; anchors.leftMargin: 28; anchors.right: parent.right; anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { caption: true; text: "Protection"; color: Ax.accent }
            Label { font.pixelSize: 24; font.weight: Font.DemiBold
                    text: !page.loaded ? "Checking…" : page.score >= 85 ? "Well protected" : page.score >= 60 ? "Mostly protected" : "Needs attention" }
            Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.subtext; font.pixelSize: Ax.fsSmall
                    text: !page.loaded ? "" : page.checks.filter(c => !c.ok).length === 0 ? "Every check passes."
                        : page.checks.filter(c => !c.ok).length + " things could be tighter. Each one below opens the page that fixes it." }
            Row { spacing: 8; topPadding: 4
                  Badge { visible: page.r.ghost === "1"; text: "ghostwired on"; tone: "accent" }
                  AxButton { icon: "refresh"; text: "Check again"; onClicked: { page.loaded = false; page.load(); } } }
        }
    }

    Section {
        title: "Checks"
        Repeater {
            model: page.checks
            SRow {
                required property var modelData
                icon: modelData.icon; title: modelData.t; desc: modelData.d
                clickable: true; chevron: true
                onClicked: NSS.Shell.openSettings(modelData.page)
                Badge { text: modelData.ok ? "ok" : "fix"; tone: modelData.ok ? "accent" : "danger"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Section {
        title: "Tools"
        SRow { icon: "fact_check"; title: "Run a full audit"; desc: "Lynis and rkhunter look through the whole system"; clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("audit") }
        SRow { icon: "shield_lock"; title: "GhostWired"; desc: "Send every packet through Tor"; clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("ghostwired") }
    }
}

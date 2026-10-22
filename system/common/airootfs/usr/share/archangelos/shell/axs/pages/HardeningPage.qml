// Hardening — AppArmor (on at boot, profiles in enforce or complain), kernel restrictions as
// plain switches (written to /etc/sysctl.d/90-archangelos-hardening.conf), Secure Boot status and
// the root account.
import QtQuick
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Hardening"
    desc: "Make the system itself harder to break into, even for something already running on it."

    readonly property string sec: "/usr/lib/archangelos/axs-sec"
    property var cur: ({})
    property var aa: ({})
    property bool aaLoaded: false
    property string busy: ""
    property string error: ""
    property string notice: ""
    // key, title, description, hardened value, icon
    readonly property var knobs: [
        ["kernel.kptr_restrict", "Hide kernel addresses", "Exploits can't read where the kernel lives in memory", "2", "visibility_off"],
        ["kernel.dmesg_restrict", "Restrict the kernel log", "Only admins can read dmesg, which leaks hardware and memory details", "1", "receipt_long"],
        ["kernel.yama.ptrace_scope", "Block process snooping", "Programs can't attach to and read other programs, except their own children", "1", "bug_report"],
        ["kernel.unprivileged_bpf_disabled", "No unprivileged BPF", "Removes a common kernel attack path for normal users", "1", "memory"],
        ["net.core.bpf_jit_harden", "Harden the BPF compiler", "Blinds constants so BPF can't be used to plant code", "2", "build"],
        ["kernel.kexec_load_disabled", "Forbid swapping the kernel", "Nothing can load a new kernel while running (until reboot)", "1", "swap_horiz"],
        ["kernel.sysrq", "Disable magic SysRq keys", "Keyboard combos that bypass the lock screen are off", "0", "keyboard"],
        ["dev.tty.ldisc_autoload", "No automatic line disciplines", "Old terminal drivers can't be loaded on demand", "0", "terminal"],
        ["vm.unprivileged_userfaultfd", "Restrict userfaultfd", "Takes away a tool often used to win kernel race exploits", "0", "timer"],
        ["kernel.perf_event_paranoid", "Restrict performance counters", "Normal users can't profile the kernel", "3", "speed"],
        ["fs.protected_fifos", "Protect shared temp files", "Stops tricks with pipes and files in /tmp", "2", "folder_special"],
        ["net.ipv4.tcp_syncookies", "SYN flood protection", "Keeps the network up under connection floods", "1", "waves"],
        ["net.ipv4.conf.all.rp_filter", "Drop spoofed packets", "Packets with impossible source addresses are dropped", "1", "filter_alt"],
        ["net.ipv4.conf.all.accept_redirects", "Ignore ICMP redirects", "Nobody on the network can reroute your traffic", "0", "alt_route"],
        ["net.ipv6.conf.all.accept_redirects", "Ignore IPv6 redirects", "The same, for IPv6", "0", "alt_route"],
        ["net.ipv4.conf.all.send_redirects", "Don't send redirects", "This computer isn't a router", "0", "router"],
        ["net.ipv4.conf.all.log_martians", "Log impossible packets", "Spoofed traffic shows up in the system log", "1", "description"],
        ["net.ipv4.icmp_echo_ignore_all", "Stealth mode", "Don't answer pings — harder to find on a network (can confuse diagnostics)", "1", "visibility_off"]
    ]
    Cmd { id: cmd }
    function load() {
        cmd.sh('for k in "$@"; do echo "$k=$(sysctl -n "$k" 2>/dev/null)"; done; echo "aa=$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)"; '
             + 'echo "aaboot=$(grep -qs "apparmor" /proc/cmdline && echo 1 || echo 0)"; echo "aasvc=$(systemctl is-enabled apparmor 2>/dev/null)"; '
             + 'echo "sb=$(od -An -t u1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | tr -d " ")"; '
             + 'echo "efi=$([ -d /sys/firmware/efi ] && echo 1 || echo 0)"', page.knobs.map(k => k[0]), (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).trim(); }
            page.cur = m;
        });
    }
    Component.onCompleted: load()
    function run(what, argv, ok) {
        page.busy = what; page.error = ""; page.notice = "";
        cmd.run(argv, (c, o, e) => { page.busy = ""; if (c === 126 || c === 127) page.error = "Cancelled."; else if (c !== 0) page.error = (e || o).trim().split("\n").pop(); else if (ok) page.notice = ok; page.load(); });
    }
    function hardened(k) { return page.cur[k[0]] === k[3] || (k[3] !== "0" && +page.cur[k[0]] >= +k[3] && k[0] !== "kernel.sysrq"); }
    readonly property int count: knobs.filter(k => hardened(k)).length
    function loadProfiles() {
        page.busy = "aa";
        cmd.run([page.sec, "aa-status"], (c, o) => { page.busy = ""; try { page.aa = JSON.parse(o).profiles || {}; page.aaLoaded = true; } catch (e) { if (c !== 126) page.error = "AppArmor isn't running."; } });
    }

    Label { visible: page.error !== "" || page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
            color: page.error !== "" ? Ax.danger : Ax.ok; text: page.error || page.notice }

    Section {
        title: "AppArmor"
        SRow {
            icon: "policy"; title: "Confine apps with AppArmor"
            desc: page.cur.aa === "Y" ? "Running — profiled apps can only touch what their profile allows"
                : page.cur.aaboot === "1" || page.cur.aasvc === "enabled" ? "Set to start — restart to turn it on" : "Off. Turning it on adds it to the boot options; it starts after a restart"
            Badge { visible: page.cur.aa === "Y"; text: "running"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
            AxSwitch { checked: page.cur.aa === "Y" || page.cur.aasvc === "enabled"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("aaboot", [page.sec, "apparmor-boot", on ? "1" : "0"], "Saved. Restart to " + (on ? "start" : "stop") + " AppArmor.") }
        }
        SRow {
            visible: page.cur.aa === "Y" && !page.aaLoaded
            icon: "list"; title: "Profiles"; desc: "See which apps are confined, and how strictly"
            AxButton { text: "Show"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.loadProfiles() }
        }
        Repeater {
            model: Object.keys(page.aa).sort().slice(0, 60)
            SRow {
                required property string modelData
                icon: page.aa[modelData] === "enforce" ? "lock" : "edit_note"
                title: modelData.split("/").pop() || modelData; desc: modelData
                AxSegment { anchors.verticalCenter: parent.verticalCenter; options: ["Enforce", "Complain"]
                            current: page.aa[modelData] === "enforce" ? 0 : 1
                            onPicked: (i) => { page.run("mode", [page.sec, "aa-mode", modelData, i ? "complain" : "enforce"]); const a = Object.assign({}, page.aa); a[modelData] = i ? "complain" : "enforce"; page.aa = a; } }
            }
        }
    }

    Section {
        title: "Kernel"
        note: page.count + " of " + page.knobs.length + " on"
        SRow {
            icon: "auto_fix_high"; title: "Turn on everything recommended"; desc: "Everything below except stealth mode"
            AxButton { text: "Harden"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.run("all", [page.sec, "sysctl-set"].concat(page.knobs.filter(k => k[0] !== "net.ipv4.icmp_echo_ignore_all").map(k => k[0] + "=" + k[3])), "Hardened.") }
        }
        Repeater {
            model: page.knobs
            SRow {
                required property var modelData
                icon: modelData[4]; title: modelData[1]; desc: modelData[2]
                AxSwitch { checked: page.hardened(modelData); enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onToggled: (on) => page.run("k", [page.sec, "sysctl-set", modelData[0] + "=" + (on ? modelData[3] : "default")]) }
            }
        }
    }

    Section {
        title: "Boot & accounts"
        SRow {
            icon: "verified_user"; title: "Secure Boot"
            desc: page.cur.efi === "0" ? "This computer doesn't boot with UEFI" : page.cur.sb === "1" ? "On — the firmware only starts signed boot loaders"
                : "Off. Turning it on is done in the firmware setup and needs signed boot files (sbctl)"
            Badge { text: page.cur.sb === "1" ? "on" : "off"; tone: page.cur.sb === "1" ? "accent" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "admin_panel_settings"; title: "Root password"; desc: "Lock it so root can only be reached through sudo by an administrator"
            AxButton { text: "Lock"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.run("root", [page.sec, "root-lock", "1"], "Root's password is locked.") }
            AxButton { text: "Unlock"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.run("root", [page.sec, "root-lock", "0"], "Root's password is unlocked.") }
        }
    }
}

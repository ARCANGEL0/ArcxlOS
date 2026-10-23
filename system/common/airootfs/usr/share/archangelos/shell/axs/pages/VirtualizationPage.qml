// Virtualization — virtual machines (libvirt / QEMU) and containers (Docker, Podman): whether
// the services run, your access to them, the machines and containers themselves, and the tools to
// manage them. Service and VM actions go through /usr/lib/archangelos/axs-admin.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Developer"
    title: "Virtualization"
    desc: "Virtual machines and containers."

    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    readonly property string me: Quickshell.env("USER") || ""
    property var have: ({})
    property var svc: ({})              // service → active
    property var inGroup: ({})          // group → bool
    property var vms: []               // { name, state }
    property var containers: []        // { engine, name, image, state }
    property bool loaded: false
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: act }

    function load() {
        cmd.sh('for p in virsh qemu-system-x86_64 virt-manager docker podman; do command -v "$p" >/dev/null 2>&1 && echo "have:$p" || true; done; '
             + 'for s in libvirtd docker containerd podman.socket; do echo "svc:$s=$(systemctl is-active "$s" 2>/dev/null)"; done; '
             + 'for g in libvirt docker kvm; do id -nG 2>/dev/null | tr " " "\\n" | grep -qx "$g" && echo "grp:$g=1" || echo "grp:$g=0"; done; '
             + 'echo "--vms"; virsh -c qemu:///system list --all 2>/dev/null | tail -n +3; '
             + 'echo "--docker"; docker ps -a --format "{{.Names}}|{{.Image}}|{{.State}}" 2>/dev/null; '
             + 'echo "--podman"; podman ps -a --format "{{.Names}}|{{.Image}}|{{.State}}" 2>/dev/null', [], (c, o) => {
            const sec = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            const head = o.slice(0, o.indexOf("--vms"));
            const have = {}, svc = {}, grp = {};
            for (const l of head.split("\n")) {
                if (l.startsWith("have:")) have[l.slice(5)] = true;
                else if (l.startsWith("svc:")) { const kv = l.slice(4).split("="); svc[kv[0]] = kv[1] === "active"; }
                else if (l.startsWith("grp:")) { const kv = l.slice(4).split("="); grp[kv[0]] = kv[1] === "1"; }
            }
            page.have = have; page.svc = svc; page.inGroup = grp;
            page.vms = sec("--vms", "--docker").split("\n").filter(l => l.trim()).map(l => {
                const m = l.trim().match(/^(\S+)\s+(\S+)\s+(.+)$/) || l.trim().match(/^-\s+(\S+)\s+(.+)$/);
                if (!m) return null; return m.length === 4 ? { name: m[2], state: m[3].trim() } : { name: m[1], state: m[2].trim() };
            }).filter(x => x);
            const dock = sec("--docker", "--podman").split("\n").filter(l => l.includes("|")).map(l => { const f = l.split("|"); return { engine: "docker", name: f[0], image: f[1], state: f[2] }; });
            const pod = sec("--podman").split("\n").filter(l => l.includes("|")).map(l => { const f = l.split("|"); return { engine: "podman", name: f[0], image: f[1], state: f[2] }; });
            page.containers = dock.concat(pod);
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function run(what, args, ok) {
        page.busy = what; page.error = ""; page.notice = "";
        act.run([page.admin].concat(args), (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "That didn't work.";
            else { page.notice = typeof ok === "function" ? ok(o) : ok; page.load(); }
            noticeT.restart();
        });
    }
    Timer { id: noticeT; interval: 5000; onTriggered: page.notice = "" }

    readonly property bool haveVirt: !!(page.have.virsh || page.have["qemu-system-x86_64"])

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }
    Label { visible: page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    Section {
        visible: page.loaded && !page.haveVirt && !page.have.docker && !page.have.podman
        EmptyState { icon: "dns"; title: "No virtualization tools installed"; desc: "Install  libvirt qemu-full virt-manager  for VMs, or  docker  /  podman  for containers." }
    }

    // ── virtual machines ─────────────────────────────────────────────────────────
    Section {
        visible: page.haveVirt
        title: "Virtual machines"
        note: "libvirt / QEMU"
        SRow {
            icon: page.svc.libvirtd ? "dns" : "cloud_off"; title: "libvirt service"
            desc: page.svc.libvirtd ? "Running — VMs can start" : "Stopped"
            AxSwitch { checked: page.svc.libvirtd === true; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("libvirtd", ["svc", "libvirtd", on ? "1" : "0"], on ? "libvirt started." : "libvirt stopped.") }
        }
        SRow {
            visible: !page.inGroup.libvirt
            icon: "group_add"; title: "Let me manage VMs without a password"; desc: "Adds you to the libvirt group — then VMs work without asking each time"
            AxButton { text: "Add me"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.run("grp", ["group-add", page.me, "libvirt"], "Added — log out and back in to take effect.") }
        }
        Repeater {
            model: page.vms
            SRow {
                required property var modelData
                readonly property bool on: /running/.test(modelData.state)
                icon: parent.on ? "play_circle" : "stop_circle"
                title: modelData.name; desc: modelData.state
                Badge { text: parent.on ? "running" : "off"; tone: parent.on ? "ok" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { text: parent.on ? "Shut down" : "Start"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.run("vm", ["vm", modelData.name, parent.on ? "shutdown" : "start"], "Done.") }
            }
        }
        SRow {
            visible: !!page.have["virt-manager"]
            icon: "open_in_new"; title: "Virtual Machine Manager"; desc: "Create and configure VMs in the full tool"
            AxButton { text: "Open"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["sh", "-c", "virt-manager >/dev/null 2>&1 &"]) }
        }
    }

    // ── containers ───────────────────────────────────────────────────────────────
    Section {
        visible: !!page.have.docker
        title: "Docker"
        SRow {
            icon: page.svc.docker ? "deployed_code" : "cloud_off"; title: "Docker service"
            desc: page.svc.docker ? "Running" : "Stopped"
            AxSwitch { checked: page.svc.docker === true; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("docker", ["svc", "docker", on ? "1" : "0"], on ? "Docker started." : "Docker stopped.") }
        }
        SRow {
            visible: !page.inGroup.docker
            icon: "group_add"; title: "Use Docker without sudo"; desc: "Adds you to the docker group (note: that grants root-equivalent access to the daemon)"
            AxButton { text: "Add me"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.run("grp", ["group-add", page.me, "docker"], "Added — log out and back in.") }
        }
    }

    Section {
        visible: page.containers.length > 0
        title: "Containers"
        Repeater {
            model: page.containers
            SRow {
                required property var modelData
                readonly property bool on: /running|up/i.test(modelData.state)
                icon: parent.on ? "deployed_code" : "deployed_code_history"
                title: modelData.name; desc: modelData.image + "  ·  " + modelData.engine
                Badge { text: parent.on ? "running" : modelData.state; tone: parent.on ? "ok" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { text: parent.on ? "Stop" : "Start"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: { Quickshell.execDetached([modelData.engine, parent.on ? "stop" : "start", modelData.name]); busyT.restart(); } }
            }
        }
        Timer { id: busyT; interval: 1200; onTriggered: page.load() }
    }

    Section {
        visible: !!page.have.podman && !page.have.docker
        title: "Podman"
        SRow { icon: "deployed_code"; title: "Podman"; desc: "Rootless containers — no daemon needed. Run  podman run …  from a terminal." }
    }
}

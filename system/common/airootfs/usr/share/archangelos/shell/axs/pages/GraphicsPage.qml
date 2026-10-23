// Graphics — the GPUs in this machine, the drivers and APIs they present (Vulkan, OpenGL), and,
// on laptops with switchable graphics, which GPU the system uses. Switching goes through
// /usr/lib/archangelos/axs-admin (envycontrol) and takes effect after a restart.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Devices"
    title: "Graphics"
    desc: "Your GPUs, their drivers and APIs, and switchable graphics."

    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    property var cards: []              // { name, driver, slot }
    property var vk: []                // { name, type, driver, api }
    property string gl: ""
    property string glRenderer: ""
    property string envy: ""           // integrated | hybrid | nvidia | ""
    property bool haveEnvy: false
    property bool loaded: false
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: act }

    function load() {
        cmd.sh('echo "--cards"; lspci -mm 2>/dev/null | grep -iE "VGA|3D|Display"; '
             + 'echo "--drv"; for c in /sys/class/drm/card[0-9]; do [ -e "$c/device/driver" ] && echo "$(basename "$(readlink -f "$c/device/driver")")"; done; '
             + 'echo "--vk"; (vulkaninfo --summary 2>/dev/null || true) | grep -E "deviceName|driverName|driverInfo|apiVersion|deviceType" ; '
             + 'echo "--gl"; (glxinfo -B 2>/dev/null || eglinfo 2>/dev/null || true) | grep -iE "OpenGL renderer|OpenGL version|OpenGL core|Device:" | head -n 4; '
             + 'echo "--envy"; command -v envycontrol >/dev/null && envycontrol --query 2>/dev/null', [], (c, o) => {
            const sec = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            // cards: lspci -mm lines → quoted fields; vendor is field 3, device field 4
            page.cards = sec("--cards", "--drv").trim().split("\n").filter(l => l).map(l => {
                const q = l.match(/"([^"]*)"/g) || []; const f = q.map(x => x.replace(/"/g, ""));
                return { slot: (l.split(" ")[0] || ""), name: ((f[2] || "") + " " + (f[3] || "")).trim() };
            });
            const drivers = sec("--drv", "--vk").trim().split("\n").filter(l => l);
            page.cards.forEach((c2, i) => c2.driver = drivers[i] || "");
            // vulkan: group every deviceName with the lines after it
            const vkLines = sec("--vk", "--gl").trim().split("\n").map(l => l.trim()).filter(l => l);
            const devs = []; let cur = null;
            for (const l of vkLines) {
                const m = /^(\w+)\s*=\s*(.+)$/.exec(l) || /^(deviceName|driverName|driverInfo|apiVersion|deviceType)\s*(.+)$/.exec(l);
                if (!m) continue;
                const k = m[1], v = m[2].replace(/^=\s*/, "").trim();
                if (k === "deviceName") { cur = { name: v, driver: "", api: "", type: "" }; devs.push(cur); }
                else if (cur && k === "driverName") cur.driver = v;
                else if (cur && k === "driverInfo" && !cur.driver) cur.driver = v;
                else if (cur && k === "apiVersion") cur.api = v;
                else if (cur && k === "deviceType") cur.type = v.replace(/PHYSICAL_DEVICE_TYPE_/, "").toLowerCase();
            }
            page.vk = devs;
            const glLines = sec("--gl", "--envy").trim().split("\n").map(l => l.trim()).filter(l => l);
            for (const l of glLines) {
                if (/renderer/i.test(l)) page.glRenderer = l.replace(/.*renderer[:\s]*/i, "");
                else if (/version/i.test(l) && !page.gl) page.gl = l.replace(/.*version[:\s]*/i, "");
            }
            const e = sec("--envy").trim();
            page.haveEnvy = e !== "" || /envycontrol/.test(o);
            page.envy = (e.match(/integrated|hybrid|nvidia/) || [""])[0];
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function switchGpu(mode) {
        page.busy = mode; page.error = ""; page.notice = "";
        act.run([page.admin, "gpu-mode", mode], (c, o, e) => {
            page.busy = "";
            if (c === 126) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "Couldn't switch graphics.";
            else { page.notice = "Switched to " + mode + " — restart to apply."; noticeT.restart(); page.load(); }
        });
    }
    Timer { id: noticeT; interval: 6000; onTriggered: page.notice = "" }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }
    Label { visible: page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    Section {
        title: "Graphics hardware"
        EmptyState { visible: page.loaded && page.cards.length === 0; icon: "developer_board"; title: "No GPU found"; desc: "lspci didn't report a display controller." }
        Repeater {
            model: page.cards
            SRow {
                required property var modelData
                icon: "developer_board"; title: modelData.name || "Display controller"
                desc: "PCI " + modelData.slot
                Badge { visible: modelData.driver !== ""; text: modelData.driver; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Section {
        visible: page.haveEnvy
        title: "Switchable graphics"
        note: page.envy ? "now: " + page.envy : ""
        SRow {
            icon: "swap_horiz"; title: "Which GPU to use"
            desc: "Integrated saves battery · Hybrid lets apps pick · NVIDIA runs everything on the dedicated card. Changing this restarts graphics on next boot."
        }
        Item {
            property bool topDivider: false
            width: parent.width; height: modes.implicitHeight + 28
            Row {
                id: modes
                x: Ax.pad; y: 14; width: parent.width - 2 * Ax.pad; spacing: 10
                Repeater {
                    model: [{ m: "integrated", t: "Integrated", d: "iGPU only — longest battery" },
                            { m: "hybrid", t: "Hybrid", d: "Both — apps opt in to the dGPU" },
                            { m: "nvidia", t: "NVIDIA", d: "dGPU for everything — most power" }]
                    Rectangle {
                        required property var modelData
                        readonly property bool sel: page.envy === modelData.m
                        width: (modes.width - 20) / 3; height: 92
                        radius: Ax.radiusSm; color: sel ? Ax.accentSoft : Ax.raised
                        border.width: sel ? 2 : 1; border.color: sel ? Ax.accent : Ax.border
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 5
                            Row { spacing: 6; Label { text: modelData.t; font.weight: Font.Medium }
                                  Label { visible: parent.parent.parent.sel; text: "· now"; color: Ax.accent; font.pixelSize: Ax.fsSmall; anchors.baseline: parent.children[0].baseline } }
                            Label { width: parent.width; wrapMode: Text.WordWrap; text: modelData.d; color: Ax.muted; font.pixelSize: Ax.fsSmall }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: page.busy === "" && !parent.sel; onClicked: page.switchGpu(modelData.m) }
                    }
                }
            }
        }
    }

    Section {
        visible: page.vk.length > 0
        title: "Vulkan"
        Repeater {
            model: page.vk
            SRow {
                required property var modelData
                icon: /discrete/.test(modelData.type) ? "developer_board" : /integrated/.test(modelData.type) ? "memory" : "view_in_ar"
                title: modelData.name
                desc: [modelData.type ? modelData.type + " GPU" : "", modelData.driver, modelData.api ? "Vulkan " + modelData.api : ""].filter(x => x).join("  ·  ")
            }
        }
    }

    Section {
        visible: page.glRenderer !== "" || page.gl !== ""
        title: "OpenGL"
        SRow { visible: page.glRenderer !== ""; icon: "view_in_ar"; title: "Renderer"
               Label { text: page.glRenderer; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; width: Math.min(implicitWidth, 420); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter } }
        SRow { visible: page.gl !== ""; icon: "info"; title: "Version"
               Label { text: page.gl; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter } }
    }

    Section {
        visible: page.loaded && page.vk.length === 0 && page.glRenderer === ""
        SRow { icon: "help"; title: "No API details"; desc: "Install  vulkan-tools  and  mesa-utils  to see Vulkan and OpenGL information here." }
    }

    Section {
        title: "Related"
        SRow { icon: "desktop_windows"; title: "Resolution, refresh & adaptive sync"; desc: "Per-display settings live in Displays"; clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("displays") }
        SRow { icon: "sports_esports"; title: "Game performance"; desc: "Game mode, overlay and launchers"; clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("gaming") }
    }
}

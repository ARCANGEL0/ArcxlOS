// Printers & scanners — the printers CUPS knows about, with their queues; finding and adding a
// new one (driverless IPP, "print from anywhere"); the default; and a test page. Adding and
// removing printers go through /usr/lib/archangelos/axs-admin, which asks for your password.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Devices"
    title: "Printers & scanners"
    desc: "Add a printer, set the default, and see what's printing."

    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    property bool installed: true
    property bool running: false
    property var printers: []          // { name, state, info, def }
    property var jobs: []              // { id, name, user, size }
    property var found: []             // { uri, name } from a scan
    property var scanners: []
    property bool loaded: false
    property bool scanning: false
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: act }

    function load() {
        cmd.sh('command -v lpstat >/dev/null || { echo "NOCUPS"; exit 0; }; '
             + 'systemctl is-active cups >/dev/null 2>&1 && echo "running=1" || echo "running=0"; '
             + 'def="$(lpstat -d 2>/dev/null | sed -n "s/.*: //p")"; echo "default=$def"; '
             + 'echo "--printers"; lpstat -p 2>/dev/null; echo "--info"; lpstat -l -p 2>/dev/null | grep -E "Description|Location" ; '
             + 'echo "--jobs"; lpstat -o 2>/dev/null; echo "--scan"; command -v scanimage >/dev/null && scanimage -L 2>/dev/null', [], (c, o) => {
            if (o.trim() === "NOCUPS") { page.installed = false; page.loaded = true; return; }
            const sec = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            let def = "";
            for (const l of o.slice(0, o.indexOf("--printers")).split("\n")) { if (l.startsWith("running=")) page.running = l.endsWith("1"); if (l.startsWith("default=")) def = l.slice(8); }
            // "printer NAME is idle." / "printer NAME disabled since..."
            page.printers = sec("--printers", "--info").split("\n").filter(l => l.startsWith("printer ")).map(l => {
                const m = /^printer (\S+) (is (\w+)|disabled)/.exec(l) || [];
                return { name: m[1] || l.split(" ")[1], state: /disabled/.test(l) ? "disabled" : (m[3] || "idle"), def: (m[1] || "") === def };
            });
            page.jobs = sec("--jobs", "--scan").split("\n").filter(l => l.trim()).map(l => { const f = l.split(/\s+/); return { id: f[0], user: f[1], size: f[2] }; });
            page.scanners = sec("--scan").split("\n").filter(l => /^device/.test(l)).map(l => (l.match(/is a (.+)$/) || [, l])[1]);
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
        }, undefined);
    }
    Timer { id: noticeT; interval: 5000; onTriggered: page.notice = "" }

    function scan() {
        page.scanning = true; page.error = ""; page.found = [];
        act.run([page.admin, "printer-scan"], (c, o, e) => {
            page.scanning = false;
            if (c === 126) { page.error = "Cancelled."; return; }
            if (c !== 0) { page.error = (e || "Couldn't scan for printers.").trim(); return; }
            // "network ipp://... " / "direct usb://Brand/Model?serial=..."
            page.found = o.split("\n").filter(l => l.trim()).map(l => {
                const sp = l.trim().indexOf(" "); const uri = l.trim().slice(sp + 1).trim();
                const name = (uri.match(/\/\/([^\/?]+)/) || [, uri])[1].replace(/%20/g, " ");
                return { uri: uri, name: name, kind: l.trim().slice(0, sp) };
            }).filter(d => d.uri && !/^file/.test(d.uri));
        });
    }
    function suggestName(d) {
        const raw = (d.uri.match(/usb:\/\/([^\/]+)\/([^?]+)/) || []);
        let n = raw.length ? (raw[1] + "_" + raw[2]) : d.name;
        return decodeURIComponent(n).replace(/[^A-Za-z0-9_-]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 40) || "Printer";
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }
    Label { visible: page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    Section {
        visible: page.loaded && !page.installed
        EmptyState { icon: "print_disabled"; title: "Printing isn't set up"; desc: "Install CUPS with  sudo pacman -S cups  (and  system-config-printer  for drivers), then enable it." }
    }

    Section {
        visible: page.installed && !page.running
        SRow {
            icon: "print_disabled"; title: "Printing service is off"; desc: "CUPS isn't running — start it to add and use printers"
            AxButton { text: page.busy === "svc" ? "Starting…" : "Turn on"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.run("svc", ["cups-on"], "Started.") }
        }
    }

    Section {
        visible: page.installed
        title: "Printers"
        note: page.printers.length ? page.printers.length + " installed" : ""
        EmptyState { visible: page.loaded && page.printers.length === 0; icon: "print"; title: "No printers yet"; desc: "Scan below to find one on your network or USB." }
        Repeater {
            model: page.printers
            SRow {
                required property var modelData
                icon: modelData.state === "disabled" ? "print_disabled" : modelData.state === "printing" ? "print" : "local_printshop"
                title: modelData.name + (modelData.def ? "  ·  default" : "")
                desc: modelData.state === "printing" ? "Printing now" : modelData.state === "disabled" ? "Paused" : "Ready"
                Badge { visible: modelData.def; text: "default"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { visible: !modelData.def; text: "Make default"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.run("def", ["printer-default", modelData.name], modelData.name + " is now the default.") }
                AxButton { text: "Test page"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: Quickshell.execDetached(["sh", "-c", "lp -d '" + modelData.name + "' /usr/share/cups/data/testprint 2>/dev/null || echo test | lp -d '" + modelData.name + "'"]) }
                AxButton { text: modelData.state === "disabled" ? "Resume" : "Pause"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.run("en", ["printer-enable", modelData.name, modelData.state === "disabled" ? "1" : "0"], "Updated.") }
                ConfirmButton { icon: "delete"; confirmText: "Remove"; anchors.verticalCenter: parent.verticalCenter; onConfirmed: page.run("rm", ["printer-remove", modelData.name], modelData.name + " removed.") }
            }
        }
    }

    Section {
        visible: page.installed && page.running
        title: "Add a printer"
        note: page.scanning ? "searching…" : ""
        SRow {
            icon: "search"; title: "Find printers"; desc: "Looks for printers on your network and plugged in over USB"
            AxButton { text: page.scanning ? "Searching…" : "Scan"; kind: "primary"; enabled_: !page.scanning; anchors.verticalCenter: parent.verticalCenter; onClicked: page.scan() }
        }
        Repeater {
            model: page.found
            SRow {
                required property var modelData
                icon: /usb/.test(modelData.uri) ? "usb" : "lan"
                title: modelData.name; desc: modelData.kind + "  ·  " + modelData.uri
                AxButton { text: page.busy === "add" ? "Adding…" : "Add"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.run("add", ["printer-add", page.suggestName(modelData), modelData.uri, "-"], "Printer added — try a test page.") }
            }
        }
        SRow {
            icon: "settings"; title: "Full driver chooser"; desc: "For printers that need a specific PPD driver, open the classic tool"
            AxButton { text: "Open"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["sh", "-c", "system-config-printer >/dev/null 2>&1 &"]) }
        }
    }

    Section {
        visible: page.jobs.length > 0
        title: "Print queue"
        Repeater {
            model: page.jobs
            SRow {
                required property var modelData
                icon: "description"; title: modelData.id; desc: "from " + modelData.user + (modelData.size ? "  ·  " + modelData.size : "")
                AxButton { icon: "close"; kind: "danger"; anchors.verticalCenter: parent.verticalCenter; onClicked: { Quickshell.execDetached(["cancel", modelData.id]); page.load(); } }
            }
        }
    }

    Section {
        visible: page.scanners.length > 0
        title: "Scanners"
        Repeater {
            model: page.scanners
            SRow { required property string modelData; icon: "scanner"; title: modelData
                   AxButton { text: "Open scanner"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["sh", "-c", "simple-scan >/dev/null 2>&1 &"]) } }
        }
    }
}

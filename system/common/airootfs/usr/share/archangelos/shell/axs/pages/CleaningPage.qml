// Cleaning — a deep clean for ArchangelOS: scan for throwaway junk across the whole system
// (caches, trash, thumbnails, crash dumps, the package cache, the journal, core dumps), pick what
// to sweep, and see the heaviest files, folders and apps so you know where the space went.
// User junk is removed by /usr/lib/archangelos/axs-clean (as you); system junk by axs-admin.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Cleaning"
    desc: "Find and sweep junk, and see what's eating your disk."

    readonly property string clean: "/usr/lib/archangelos/axs-clean"
    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    property var cats: []              // scan result
    property var selected: ({})        // key → bool
    property var biggestFiles: []
    property var biggestDirs: []
    property var biggestApps: []
    property var disk: null            // { size, used, avail }
    property bool scanned: false
    property bool scanning: false
    property string busy: ""
    property string error: ""
    property string notice: ""
    property real lastFreed: -1
    property int heaviest: 0           // 0 files, 1 folders, 2 apps

    Cmd { id: cmd }
    Cmd { id: act }

    function human(b) {
        b = Number(b) || 0;
        const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
        return (i === 0 ? Math.round(b) : b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    Component.onCompleted: {
        cmd.sh('df -B1 --output=size,used,avail / 2>/dev/null | tail -n1', [], (c, o) => {
            const f = o.trim().split(/\s+/); if (f.length >= 3) page.disk = { size: +f[0], used: +f[1], avail: +f[2] };
        });
    }

    function scan() {
        page.scanning = true; page.error = ""; page.lastFreed = -1;
        cmd.run([page.clean, "scan"], (c, o) => {
            page.scanning = false;
            let r = null; try { r = JSON.parse(o); } catch (e) {}
            if (!r) { page.error = "Couldn't scan."; return; }
            page.cats = r.categories || [];
            const sel = {};
            for (const cat of page.cats) sel[cat.key] = cat.bytes > 0 && cat.key !== "trash" && cat.key !== "orphans";
            page.selected = sel; page.scanned = true;
        });
        cmd.run([page.clean, "biggest", "files"], (c, o) => { try { page.biggestFiles = (JSON.parse(o).items) || []; } catch (e) {} });
        cmd.run([page.clean, "biggest", "dirs"], (c, o) => { try { page.biggestDirs = (JSON.parse(o).items) || []; } catch (e) {} });
        cmd.sh('LC_ALL=C pacman -Qi 2>/dev/null | awk \'/^Name/{n=$3} /^Installed Size/{m=($5=="KiB")?1024:($5=="MiB")?1048576:($5=="GiB")?1073741824:1; print int($4*m)"|"n}\' | sort -rn | head -n 12',
               [], (c, o) => { page.biggestApps = o.split("\n").filter(l => l.includes("|")).map(l => ({ bytes: +l.split("|")[0], name: l.split("|")[1] })); });
    }

    readonly property real selectedBytes: {
        let t = 0;
        for (const c of page.cats) if (page.selected[c.key]) t += (c.bytes || 0);
        return t;
    }
    readonly property bool anySelectedSystem: page.cats.some(c => page.selected[c.key] && c.scope === "system")
    function toggle(key, on) { const s = Object.assign({}, page.selected); s[key] = on; page.selected = s; }

    // Run the sweep: user categories in one call, then each chosen system verb through axs-admin.
    function sweep() {
        page.busy = "clean"; page.error = ""; page.notice = ""; page.lastFreed = -1;
        const userKeys = page.cats.filter(c => page.selected[c.key] && c.scope === "user").map(c => c.key);
        const sysVerbs = page.cats.filter(c => page.selected[c.key] && c.scope === "system" && c.verb).map(c => c.verb);
        let freed = 0;
        const estimate = page.selectedBytes;
        const finish = () => { page.busy = ""; page.lastFreed = estimate; page.notice = "Freed about " + page.human(estimate) + "."; noticeT.restart(); page.scan(); };
        const runSys = (i) => {
            if (i >= sysVerbs.length) { finish(); return; }
            act.run([page.admin, sysVerbs[i]], (c, o, e) => {
                if (c === 126 || c === 127) { page.busy = ""; page.error = "Cancelled."; return; }
                if (c !== 0) page.error = (e || o).trim().split("\n").pop() || page.error;
                runSys(i + 1);
            });
        };
        if (userKeys.length) cmd.run([page.clean, "clean"].concat(userKeys), (c, o) => { runSys(0); });
        else runSys(0);
    }
    Timer { id: noticeT; interval: 6000; onTriggered: page.notice = "" }

    function reveal(path, isDir) {
        Quickshell.execDetached(["sh", "-c", 'p="$1"; [ -d "$p" ] || p="$(dirname "$p")"; xdg-open "$p" >/dev/null 2>&1 &', "sh", path]);
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    // ── headline ────────────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width; height: 122
        radius: Ax.radius + 2; color: Ax.panel; border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Rectangle {
            x: 26; anchors.verticalCenter: parent.verticalCenter; width: 70; height: 70; radius: 35
            color: page.scanned && page.selectedBytes > 0 ? Ax.accentSoft : Ax.raised
            border.width: 1; border.color: page.scanned && page.selectedBytes > 0 ? Ax.accentLine : Ax.border
            Icon { anchors.centerIn: parent; name: page.scanning ? "hourglass_top" : page.scanned ? "cleaning_services" : "mop"; size: 32
                   color: page.scanned && page.selectedBytes > 0 ? Ax.accent : Ax.subtext }
        }
        Column {
            x: 116; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 320; spacing: 5
            Label { font.pixelSize: Ax.fsTitle - 4; font.weight: Font.DemiBold
                    text: page.scanning ? "Scanning…" : !page.scanned ? "Ready to scan" : page.lastFreed >= 0 ? "All clean" : page.human(page.cats.reduce((a, c) => a + (c.bytes || 0), 0)) + " of junk found" }
            Label { font.pixelSize: Ax.fsSmall; color: Ax.muted
                    text: page.disk ? page.human(page.disk.avail) + " free of " + page.human(page.disk.size) + " on this disk" : "" }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            AxButton { text: page.scanning ? "Scanning…" : page.scanned ? "Rescan" : "Scan"; icon: "search"; enabled_: !page.scanning && page.busy === ""; onClicked: page.scan() }
            AxButton { visible: page.scanned; text: page.busy === "clean" ? "Cleaning…" : "Clean " + page.human(page.selectedBytes); icon: "auto_delete"; kind: "primary"
                       enabled_: page.busy === "" && page.selectedBytes > 0; onClicked: page.sweep() }
        }
    }
    Label { visible: page.notice !== ""; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    // ── what to clean ─────────────────────────────────────────────────────────────
    Section {
        visible: page.scanned
        title: "What to clean"
        note: page.anySelectedSystem ? "system items need your password" : ""
        Repeater {
            model: page.cats
            SRow {
                required property var modelData
                readonly property bool empty: (modelData.bytes || 0) <= 0 && (modelData.count || 0) <= 0
                icon: modelData.icon; dim: empty
                title: modelData.label + (modelData.scope === "system" ? "  ·  system" : "")
                desc: modelData.note + (modelData.count ? "  ·  " + modelData.count + " item" + (modelData.count === 1 ? "" : "s") : "")
                Label { text: modelData.key === "orphans" ? (modelData.count || 0) + " pkgs" : page.human(modelData.bytes)
                        mono: true; color: Ax.subtext; font.pixelSize: Ax.fsSmall; anchors.verticalCenter: parent.verticalCenter }
                AxSwitch { checked: !!page.selected[modelData.key]; enabled_: !parent.empty && page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onToggled: (on) => page.toggle(modelData.key, on) }
            }
        }
    }

    // ── heaviest ──────────────────────────────────────────────────────────────────
    Section {
        visible: page.scanned
        title: "Heaviest"
        Item {
            property bool topDivider: false
            width: parent.width; height: seg.height + 24
            AxSegment { id: seg; x: Ax.pad; y: 14; options: ["Files", "Folders", "Apps"]; current: page.heaviest; onPicked: (i) => page.heaviest = i }
        }
        Repeater {
            model: page.heaviest === 0 ? page.biggestFiles : page.heaviest === 1 ? page.biggestDirs : []
            SRow {
                required property var modelData
                icon: page.heaviest === 1 ? "folder" : "draft"
                title: modelData.name; desc: modelData.path.replace(Quickshell.env("HOME"), "~")
                Label { text: page.human(modelData.bytes); mono: true; color: Ax.subtext; font.pixelSize: Ax.fsSmall; anchors.verticalCenter: parent.verticalCenter }
                AxButton { icon: "folder_open"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.reveal(modelData.path, page.heaviest === 1) }
            }
        }
        Repeater {
            model: page.heaviest === 2 ? page.biggestApps : []
            SRow {
                required property var modelData
                icon: "package_2"; title: modelData.name
                Label { text: page.human(modelData.bytes); mono: true; color: Ax.subtext; font.pixelSize: Ax.fsSmall; anchors.verticalCenter: parent.verticalCenter }
                AxButton { text: "Manage"; anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.Shell.openSettings("apps") }
            }
        }
        SRow {
            visible: (page.heaviest === 0 && page.biggestFiles.length === 0) || (page.heaviest === 1 && page.biggestDirs.length === 0)
            dim: true; icon: "check_circle"; title: "Nothing unusually large"; desc: "No big files or folders stood out in your home folder."
        }
    }

    // ── disk health ───────────────────────────────────────────────────────────────
    Section {
        visible: page.scanned
        title: "Disk health"
        SRow { icon: "health_metrics"; title: "Check the drive (SMART)"; desc: "Wear, bad sectors and temperature are in Diagnostics"
               clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("diagnostics") }
        SRow { icon: "hard_drive"; title: "Disks & partitions"; desc: "Mount, unmount and eject in Storage"
               clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("storage") }
    }

    EmptyState {
        visible: !page.scanned && !page.scanning
        icon: "cleaning_services"; title: "Give it a scan"
        desc: "ArchangelOS will look through caches, trash, logs and crash dumps — and show the heaviest files, folders and apps — without removing anything until you say so."
    }
}

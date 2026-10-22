// Storage — how full the system drive is and what's taking the space, every disk and partition
// (mount, unmount, eject), and one-click cleanups.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Storage"
    desc: "Disks, what's using the space, and what can safely go."

    readonly property string home: Quickshell.env("HOME") || ""
    property var root_: null          // { size, used, avail }
    property var homeFs: null
    property var disks: []
    property var cats: []             // { key, label, icon, bytes }
    property bool measuring: true
    property var clean: ({})          // key → bytes / count
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: du }

    function human(b) {
        b = Number(b) || 0;
        const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
        return (i === 0 ? b : b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    function loadDisks() {
        cmd.sh('df -B1 --output=target,size,used,avail / "$HOME" 2>/dev/null | tail -n +2; echo "--"; '
             + 'lsblk -J -b -o NAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,HOTPLUG,FSTYPE,LABEL,MOUNTPOINT,FSUSED,FSAVAIL 2>/dev/null', [], (c, out) => {
            const parts = out.split("\n--\n");
            const rows = (parts[0] || "").trim().split("\n").map(l => l.trim().split(/\s+/));
            const fs = r => r && r.length >= 4 ? { target: r[0], size: +r[1], used: +r[2], avail: +r[3] } : null;
            page.root_ = fs(rows[0]);
            page.homeFs = rows[1] && rows[1][0] !== "/" ? fs(rows[1]) : null;
            try { page.disks = (JSON.parse(parts[1] || "{}").blockdevices || []).filter(d => d.type === "disk" && !/^(loop|zram|sr)/.test(d.name)); }
            catch (e) { page.disks = []; }
        });
    }
    function measure() {
        page.measuring = true;
        const H = page.home;
        const items = [
            ["docs", "Documents", "description", H + "/Documents"], ["down", "Downloads", "download", H + "/Downloads"],
            ["pics", "Pictures", "image", H + "/Pictures"], ["vids", "Videos", "movie", H + "/Videos"],
            ["music", "Music", "music_note", H + "/Music"], ["games", "Games", "sports_esports", H + "/.local/share/Steam"],
            ["cache", "Caches", "cached", H + "/.cache"], ["trash", "Trash", "delete", H + "/.local/share/Trash"],
            ["pkgs", "Package cache", "inventory_2", "/var/cache/pacman/pkg"]
        ];
        du.sh('for p in "$@"; do if [ -e "$p" ]; then du -sb "$p" 2>/dev/null | cut -f1; else echo 0; fi; done; '
            + 'echo "orph=$(pacman -Qdtq 2>/dev/null | wc -l)"; echo "journal=$(journalctl --disk-usage 2>/dev/null | grep -oE "[0-9.]+[KMGT]" | head -n1)"; '
            + 'echo "thumbs=$(du -sb "$HOME/.cache/thumbnails" 2>/dev/null | cut -f1)"',
            items.map(i => i[3]), (c, out) => {
                const lines = out.trim().split("\n");
                page.cats = items.map((it, i) => ({ key: it[0], label: it[1], icon: it[2], path: it[3], bytes: +(lines[i] || 0) }));
                const kv = {};
                for (const l of lines.slice(items.length)) { const j = l.indexOf("="); if (j > 0) kv[l.slice(0, j)] = l.slice(j + 1); }
                page.clean = { trash: page.cats.find(x => x.key === "trash").bytes, pkgs: page.cats.find(x => x.key === "pkgs").bytes,
                               thumbs: +(kv.thumbs || 0), orph: +(kv.orph || 0), journal: kv.journal || "" };
                page.measuring = false;
            });
    }
    function refresh() { loadDisks(); measure(); }
    Component.onCompleted: refresh()
    Timer { interval: 6000; running: true; repeat: true; onTriggered: page.loadDisks() }

    function doClean(what, argv, done) {
        page.busy = what; page.error = ""; page.notice = "";
        cmd.run(argv, (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "That didn't work.";
            else page.notice = done;
            page.refresh();
        });
    }
    function udisks(verb, dev) {
        page.busy = dev; page.error = "";
        cmd.run(["udisksctl", verb, "-b", dev], (c, o, e) => {
            page.busy = ""; if (c !== 0) page.error = (e || o).trim(); page.loadDisks();
        });
    }

    header: AxButton { icon: "refresh"; onClicked: page.refresh() }

    // ── system drive ───────────────────────────────────────────────────────────
    Rectangle {
        visible: page.root_ !== null
        width: parent.width; height: 196
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        readonly property real total: page.root_ ? page.root_.size : 1
        Column {
            x: 28; y: 26; width: parent.width - 56
            spacing: 8
            Label { caption: true; text: "System drive  ·  /" }
            Row {
                spacing: 10
                Label { id: freeBig; mono: true; font.pixelSize: 40; text: page.root_ ? page.human(page.root_.avail) : "" }
                Label { anchors.baseline: freeBig.baseline; color: Ax.subtext; text: "free of " + (page.root_ ? page.human(page.root_.size) : "") }
            }
            Item { width: 1; height: 6 }
            // the bar: categories in accent tints, the rest of used space, then free
            Rectangle {
                id: bar
                width: parent.width; height: 14; radius: 7
                color: Ax.alpha(Ax.text, 0.05)
                clip: true
                Row {
                    height: parent.height
                    Repeater {
                        model: page.cats.filter(c => c.bytes > 0 && c.key !== "pkgs")
                        Rectangle {
                            required property var modelData
                            required property int index
                            height: bar.height
                            width: page.root_ ? Math.max(2, bar.width * modelData.bytes / page.root_.size) : 0
                            color: Ax.alpha(Ax.accent, 1 - index * 0.11)
                        }
                    }
                    Rectangle {
                        height: bar.height
                        readonly property real known: page.cats.filter(c => c.key !== "pkgs").reduce((a, c) => a + c.bytes, 0)
                        width: page.root_ ? Math.max(0, bar.width * (page.root_.used - known) / page.root_.size) : 0
                        color: Ax.alpha(Ax.text, 0.22)
                    }
                }
            }
            Flow {
                width: parent.width; spacing: 16
                Repeater {
                    model: page.cats.filter(c => c.bytes > 0 && c.key !== "pkgs")
                    Row {
                        required property var modelData
                        required property int index
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 2; color: Ax.alpha(Ax.accent, 1 - index * 0.11); anchors.verticalCenter: parent.verticalCenter }
                        Label { font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: modelData.label + "  " + page.human(modelData.bytes) }
                    }
                }
                Row {
                    spacing: 6; visible: !page.measuring
                    Rectangle { width: 8; height: 8; radius: 2; color: Ax.alpha(Ax.text, 0.22); anchors.verticalCenter: parent.verticalCenter }
                    Label { font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: "System & other" }
                }
                Label { visible: page.measuring; font.pixelSize: Ax.fsSmall; color: Ax.faint; text: "Measuring…" }
            }
        }
    }

    Label {
        visible: page.error !== "" || page.notice !== ""
        width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
        color: page.error !== "" ? Ax.danger : Ax.ok
        text: page.error !== "" ? page.error : page.notice
    }

    // ── cleanup ────────────────────────────────────────────────────────────────
    Section {
        title: "Free up space"
        SRow {
            icon: "delete"; title: "Empty the trash"
            desc: page.measuring ? "Measuring…" : page.human(page.clean.trash) + " in the trash"
            AxButton { text: "Empty"; enabled_: page.busy === "" && page.clean.trash > 0; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.doClean("trash", ["sh", "-c", 'command -v gio >/dev/null && gio trash --empty || rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"*'], "Trash emptied.") }
        }
        SRow {
            icon: "photo_library"; title: "Thumbnail cache"
            desc: page.measuring ? "Measuring…" : page.human(page.clean.thumbs) + " of previews, rebuilt when needed"
            AxButton { text: "Clear"; enabled_: page.busy === "" && page.clean.thumbs > 0; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.doClean("thumbs", ["sh", "-c", 'rm -rf "$HOME/.cache/thumbnails"'], "Thumbnails cleared.") }
        }
        SRow {
            icon: "inventory_2"; title: "Old package downloads"
            desc: page.measuring ? "Measuring…" : page.human(page.clean.pkgs) + " cached. Keeps the newest copy of each, for rollbacks"
            AxButton { text: page.busy === "pkgs" ? "Cleaning…" : "Clean"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.doClean("pkgs", ["/usr/lib/archangelos/axs-admin", "pkg-clean-cache"], "Package cache cleaned.") }
        }
        SRow {
            icon: "link_off"; title: "Unused dependencies"
            desc: page.measuring ? "Measuring…" : page.clean.orph > 0 ? page.clean.orph + " packages nothing needs any more" : "None — everything installed is in use"
            AxButton { text: "Remove"; enabled_: page.busy === "" && page.clean.orph > 0; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.doClean("orph", ["/usr/lib/archangelos/axs-admin", "pkg-orphans"], "Unused packages removed.") }
        }
        SRow {
            icon: "receipt_long"; title: "System logs"
            desc: page.clean.journal ? page.clean.journal + "B of logs. Trims to the most recent 64 MB" : "Logs kept by the system journal"
            AxButton { text: "Trim"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.doClean("journal", ["/usr/lib/archangelos/axs-admin", "journal-vacuum"], "Logs trimmed.") }
        }
    }

    // ── disks ──────────────────────────────────────────────────────────────────
    Repeater {
        model: page.disks
        Section {
            id: disk
            required property var modelData
            title: (modelData.model || modelData.name).trim()
            note: page.human(modelData.size) + "  ·  " + (modelData.tran ? modelData.tran.toUpperCase() : modelData.name) + (modelData.rm || modelData.hotplug ? "  ·  removable" : "")
            Repeater {
                // partitions, and what is opened inside them (LUKS, LVM)
                // a filesystem written straight onto the disk counts as its one partition
                model: !disk.modelData.children && disk.modelData.fstype ? [disk.modelData]
                     : (disk.modelData.children || []).reduce((a, p) => a.concat([p], p.children || []), []).filter(p => p.type === "part" || p.type === "crypt" || p.type === "lvm")
                SRow {
                    id: part
                    required property var modelData
                    readonly property bool mounted: !!modelData.mountpoint
                    readonly property real usedFrac: modelData.fsused && modelData.fsavail ? modelData.fsused / (+modelData.fsused + +modelData.fsavail) : 0
                    icon: modelData.fstype === "swap" ? "swap_horiz" : mounted ? "folder" : "hard_drive"
                    title: modelData.label || modelData.mountpoint || modelData.name
                    desc: [modelData.name, modelData.fstype || "no filesystem", page.human(modelData.size),
                           mounted && modelData.fsused ? page.human(modelData.fsused) + " used" : ""].filter(s => s).join("  ·  ")
                    Item {
                        visible: part.mounted && part.usedFrac > 0
                        width: 120; height: 6; anchors.verticalCenter: parent.verticalCenter
                        Rectangle { anchors.fill: parent; radius: 3; color: Ax.alpha(Ax.text, 0.06) }
                        Rectangle { width: parent.width * part.usedFrac; height: parent.height; radius: 3; color: part.usedFrac > 0.9 ? Ax.danger : Ax.accent }
                    }
                    Label { visible: part.mounted; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: modelData.mountpoint; anchors.verticalCenter: parent.verticalCenter }
                    AxButton { visible: part.mounted && modelData.mountpoint !== "[SWAP]"; icon: "folder_open"; anchors.verticalCenter: parent.verticalCenter
                               onClicked: Quickshell.execDetached(["xdg-open", modelData.mountpoint]) }
                    AxButton {
                        readonly property bool system: ["/", "/boot", "/efi", "/home", "/boot/efi", "/var", "[SWAP]"].indexOf(modelData.mountpoint) >= 0
                        visible: !system && modelData.fstype && modelData.fstype !== "swap" && modelData.fstype !== "crypto_LUKS"
                        text: part.mounted ? "Unmount" : "Mount"; kind: part.mounted ? "ghost" : "primary"
                        enabled_: page.busy === ""
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: page.udisks(part.mounted ? "unmount" : "mount", modelData.path)
                    }
                }
            }
            SRow {
                visible: disk.modelData.rm || disk.modelData.hotplug
                icon: "eject"; title: "Eject"; desc: "Unmount everything on it and power it off so it can be unplugged"
                AxButton { text: "Eject"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.udisks("power-off", disk.modelData.path) }
            }
            EmptyState {
                visible: (!disk.modelData.children || disk.modelData.children.length === 0) && !disk.modelData.fstype
                icon: "hard_drive"; title: "No partitions"; desc: "This disk is empty or unformatted."
            }
        }
    }
}

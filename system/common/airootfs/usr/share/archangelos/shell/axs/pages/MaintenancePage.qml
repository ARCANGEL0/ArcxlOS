// Packages & System — keeping the installation healthy: what's installed, what can go (orphans,
// old packages, journal), config files waiting after updates (.pacnew), package and database
// checks, mirrors and keyring, and the boot image. Root steps go through axs-admin.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Maintenance"
    title: "Packages & System"
    desc: "Keep the installation clean, consistent and up to date."

    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    property var k: ({})
    property var orphans: []
    property var pacnew: []
    property var biggest: []                    // { name, bytes }
    property var broken: null                   // packages with missing files, after a check
    property string diffOf: ""
    property string diffText: ""
    property bool showOrphans: false
    property bool loaded: false
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: probe }
    function load() {
        probe.sh('echo "total=$(pacman -Qq 2>/dev/null | wc -l)"; echo "explicit=$(pacman -Qeq 2>/dev/null | wc -l)"; '
               + 'echo "foreign=$(pacman -Qmq 2>/dev/null | wc -l)"; echo "cache=$(du -sb /var/cache/pacman/pkg 2>/dev/null | cut -f1)"; '
               + 'echo "cachen=$(find /var/cache/pacman/pkg -maxdepth 1 -name "*.pkg.tar*" ! -name "*.sig" 2>/dev/null | wc -l)"; '
               + 'echo "journal=$(journalctl --disk-usage 2>/dev/null | grep -oE "[0-9.]+[KMGT]" | head -n1)"; '
               + 'echo "last=$(grep -a "starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -n1 | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{5}")"; '
               + 'echo "kernel=$(uname -r)"; if [ -d "/usr/lib/modules/$(uname -r)" ] || [ -z "$(ls /usr/lib/modules 2>/dev/null)" ]; then echo reboot=0; else echo reboot=1; fi; '
               + 'echo "lock=$([ -e /var/lib/pacman/db.lck ] && echo 1 || echo 0)"; echo "failed=$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)"; '
               + 'echo "mirrors=$(grep -c "^Server" /etc/pacman.d/mirrorlist 2>/dev/null)"; echo "mirrorsAge=$(( ($(date +%s) - $(stat -c %Y /etc/pacman.d/mirrorlist 2>/dev/null || date +%s)) / 86400 ))"; '
               + 'echo "reflector=$(command -v reflector >/dev/null && echo 1 || echo 0)"; echo "flatpak=$(command -v flatpak >/dev/null && echo 1 || echo 0)"; '
               + 'echo "mkinit=$(command -v mkinitcpio >/dev/null && echo 1 || echo 0)"; '
               + 'echo "--orph"; pacman -Qdtq 2>/dev/null; echo "--pacnew"; find /etc \\( -name "*.pacnew" -o -name "*.pacsave" \\) 2>/dev/null | head -n 50; '
               + 'echo "--big"; LC_ALL=C pacman -Qi 2>/dev/null | awk \'/^Name/ {n=$3} /^Installed Size/ { m = ($5=="KiB")?1024:($5=="MiB")?1048576:($5=="GiB")?1073741824:1; print int($4*m), n }\' | sort -rn | head -n 12', [], (c, o) => {
            const sec = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            const m = {};
            for (const l of o.slice(0, o.indexOf("--orph")).split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).trim(); }
            page.k = m;
            page.orphans = sec("--orph", "--pacnew").split("\n").filter(x => x);
            page.pacnew = sec("--pacnew", "--big").split("\n").filter(x => x);
            page.biggest = sec("--big").split("\n").filter(x => x).map(l => ({ bytes: +l.split(" ")[0], name: l.split(" ")[1] }));
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function bytes(b) {
        b = Number(b) || 0;
        const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
        return (i === 0 ? b : b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function act(what, argv, ok) {
        page.busy = what; page.error = ""; page.notice = "";
        cmd.run(argv, (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "That didn't work.";
            else { page.notice = typeof ok === "function" ? ok(o) : ok; noticeT.restart(); }
            page.load();
        });
    }
    Timer { id: noticeT; interval: 5000; onTriggered: page.notice = "" }
    function base(f) { return f.replace(/\.(pacnew|pacsave)$/, ""); }
    function showDiff(f) {
        if (page.diffOf === f) { page.diffOf = ""; return; }
        page.diffOf = f; page.diffText = "…";
        cmd.sh('diff -u --label "now in use" --label "from the update" "$1" "$2" 2>&1 | head -n 120', [page.base(f), f], (c, o) => page.diffText = o.trim() || "The files are identical.");
    }

    readonly property var issues: {
        const l = [];
        if (page.k.reboot === "1") l.push("The kernel was updated — restart to use it");
        if (page.orphans.length) l.push(page.orphans.length + " packages nothing needs any more");
        if (page.pacnew.length) l.push(page.pacnew.length + " config files waiting after an update");
        if (+page.k.failed) l.push(page.k.failed + " services failed");
        if (+page.k.cache > 3e9) l.push("Package cache is " + page.bytes(page.k.cache));
        if (page.k.lock === "1") l.push("pacman is running, or left a stale lock");
        if (page.broken && page.broken.length) l.push(page.broken.length + " packages are missing files");
        return l;
    }

    header: AxButton { icon: "refresh"; onClicked: page.load() }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Rectangle {
        width: parent.width; height: Math.max(92, hc.implicitHeight + 36)
        radius: Ax.radius + 2; color: Ax.panel; border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Rectangle {
            x: 24; anchors.verticalCenter: parent.verticalCenter; width: 46; height: 46; radius: 23
            color: page.issues.length ? Ax.alpha(Ax.danger, 0.14) : Ax.accentSoft
            border.width: 1; border.color: page.issues.length ? Ax.alpha(Ax.danger, 0.5) : Ax.accentLine
            Icon { anchors.centerIn: parent; name: page.issues.length ? "build" : "verified"; size: 22; color: page.issues.length ? Ax.danger : Ax.accent }
        }
        Column {
            id: hc
            x: 88; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; spacing: 5
            Label { text: !page.loaded ? "Checking…" : page.issues.length ? page.issues.length + (page.issues.length === 1 ? " thing" : " things") + " to look at" : "Everything is in order"; font.pixelSize: Ax.fsHead; font.weight: Font.Medium }
            Repeater { model: page.issues; Label { required property string modelData; text: "·  " + modelData; color: Ax.subtext; font.pixelSize: Ax.fsSmall } }
            Label { visible: page.loaded && !page.issues.length; color: Ax.muted; font.pixelSize: Ax.fsSmall
                    text: "Last full update " + (page.k.last ? Qt.formatDateTime(new Date(page.k.last), "MMM d, yyyy") : "unknown") + "  ·  Linux " + (page.k.kernel || "") }
        }
    }
    Label { visible: page.notice !== ""; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    Row {
        width: parent.width; spacing: 14
        readonly property real w: (width - 42) / 4
        StatTile { width: parent.w; caption: "Installed packages"; value: page.k.total || "—" }
        StatTile { width: parent.w; caption: "Installed by you"; value: page.k.explicit || "—" }
        StatTile { width: parent.w; caption: "From the AUR / elsewhere"; value: page.k.foreign || "0" }
        StatTile { width: parent.w; caption: "Package cache"; value: page.k.cache ? page.bytes(page.k.cache).split(" ")[0] : "—"; unit: page.k.cache ? page.bytes(page.k.cache).split(" ")[1] : "" }
    }

    Section {
        visible: page.k.reboot === "1"
        SRow {
            icon: "restart_alt"; title: "Restart to finish updating"; desc: "Linux " + page.k.kernel + " is running, but its modules were replaced — new devices and USB drives may not work until you restart."
            AxButton { text: "Restart"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
        }
    }

    Section {
        title: "Clean up"
        SRow {
            icon: "link_off"; title: "Orphaned packages"
            desc: page.orphans.length ? page.orphans.length + " installed as dependencies of something that's gone" : "None — every dependency is still needed"
            AxButton { visible: page.orphans.length > 0; text: page.showOrphans ? "Hide" : "Show"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.showOrphans = !page.showOrphans }
            ConfirmButton { visible: page.orphans.length > 0; label: page.busy === "orph" ? "Removing…" : "Remove all"; confirmText: "Remove " + page.orphans.length + "?"; anchors.verticalCenter: parent.verticalCenter
                            onConfirmed: page.act("orph", [page.admin, "pkg-orphans"], "Orphans removed.") }
        }
        Item {
            visible: page.showOrphans && page.orphans.length > 0
            property bool topDivider: false
            width: parent.width; height: of.implicitHeight + 24
            Flow { id: of; x: Ax.pad; y: 10; width: parent.width - 2 * Ax.pad; spacing: 6
                   Repeater { model: page.orphans; Badge { required property string modelData; text: modelData } } }
        }
        SRow {
            icon: "inventory_2"; title: "Old package versions"
            desc: page.k.cachen ? page.k.cachen + " downloads kept, " + page.bytes(page.k.cache) + " — keeps the newest of each so you can roll back" : "…"
            AxButton { text: page.busy === "cache" ? "Cleaning…" : "Clean"; enabled_: page.busy === "" && +page.k.cache > 0; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("cache", [page.admin, "pkg-clean-cache"], "Package cache cleaned.") }
        }
        SRow {
            icon: "receipt_long"; title: "System journal"; desc: page.k.journal ? page.k.journal + "B of logs — trimming keeps the newest 64 MB" : page.loaded ? "Size unknown — trimming keeps the newest 64 MB" : "…"
            AxButton { text: page.busy === "journal" ? "Trimming…" : "Trim"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("journal", [page.admin, "journal-vacuum"], "Journal trimmed.") }
        }
        SRow {
            visible: page.k.flatpak === "1"
            icon: "deployed_code"; title: "Unused Flatpak runtimes"; desc: "Runtimes no installed app needs"
            AxButton { text: page.busy === "flat" ? "Removing…" : "Remove"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("flat", ["flatpak", "uninstall", "--unused", "-y", "--noninteractive"], (o) => /Nothing unused/i.test(o) ? "Nothing unused." : "Unused runtimes removed.") }
        }
    }

    Section {
        visible: page.pacnew.length > 0
        title: "Configuration files"
        note: "left by updates"
        Repeater {
            model: page.pacnew
            Column {
                id: pn
                required property string modelData
                property bool topDivider: false
                width: parent.width
                Rectangle { visible: pn.topDivider; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
                SRow {
                    icon: "difference"; title: page.base(pn.modelData)
                    desc: /pacsave$/.test(pn.modelData) ? "Your old version was saved when its package was removed" : "The update brought a new version; yours is still in use"
                    AxButton { text: page.diffOf === pn.modelData ? "Hide" : "Differences"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.showDiff(pn.modelData) }
                    AxButton { text: "Keep mine"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                               onClicked: page.act("pacnew", [page.admin, "pacnew", page.base(pn.modelData), "keep"], "Kept your version.") }
                    ConfirmButton { label: "Use new"; confirmText: "Replace yours?"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                                    onConfirmed: page.act("pacnew", [page.admin, "pacnew", page.base(pn.modelData), "use"], "Switched to the new version — yours is saved as .axs-old.") }
                }
                Rectangle {
                    visible: page.diffOf === pn.modelData
                    x: Ax.pad; width: parent.width - 2 * Ax.pad; height: visible ? Math.min(320, dl.implicitHeight + 24) : 0
                    radius: Ax.radiusSm; color: Ax.raised; border.width: 1; border.color: Ax.border; clip: true
                    Flickable {
                        anchors.fill: parent; anchors.margins: 12; contentHeight: dl.implicitHeight; clip: true
                        Text {
                            id: dl; width: parent.width; wrapMode: Text.WrapAnywhere; textFormat: Text.StyledText
                            font.family: Ax.mono; font.pixelSize: Ax.fsSmall; color: Ax.subtext
                            text: page.diffText.split("\n").map(l => {
                                const e = l.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
                                return l.startsWith("+") && !l.startsWith("+++") ? "<font color='" + Ax.accent + "'>" + e + "</font>"
                                     : l.startsWith("-") && !l.startsWith("---") ? "<font color='" + Ax.danger + "'>" + e + "</font>" : e; }).join("<br>")
                        }
                    }
                }
                Item { width: 1; height: page.diffOf === pn.modelData ? 12 : 0 }
            }
        }
    }

    Section {
        title: "Packages & database"
        SRow {
            icon: "rule"; title: "Check installed files"
            desc: page.busy === "verify" ? "Checking every package — this takes a minute…"
                : page.broken === null ? "Make sure no package is missing files (damaged or deleted by hand)"
                : page.broken.length ? page.broken.length + " packages are missing files — reinstall them" : "Every package is complete"
            Badge { visible: page.broken !== null && page.busy !== "verify"; text: page.broken && page.broken.length ? "damaged" : "complete"; tone: page.broken && page.broken.length ? "danger" : "ok"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: page.busy === "verify" ? "Checking…" : "Check"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: { page.busy = "verify";
                                    cmd.sh('pacman -Qk 2>/dev/null | grep -v " 0 missing files" | grep -oE "^[^:]+" | sort -u', [], (c, o) => { page.busy = ""; page.broken = o.split("\n").filter(x => x); }); } }
        }
        Item {
            visible: !!page.broken && page.broken.length > 0
            property bool topDivider: false
            width: parent.width; height: bf.implicitHeight + 24
            Flow { id: bf; x: Ax.pad; y: 10; width: parent.width - 2 * Ax.pad; spacing: 6
                   Repeater { model: page.broken || []; Badge { required property string modelData; text: modelData; tone: "danger" } } }
        }
        SRow {
            icon: "database"; title: "Package database"; desc: page.k.lock === "1" ? "A lock file is present — pacman is busy, or crashed and left it" : "Check that every dependency is installed and nothing conflicts"
            AxButton { text: page.busy === "db" ? "Checking…" : "Check"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("db", [page.admin, "db-check"], (o) => o.trim() ? o.trim().split("\n").pop() : "The database is consistent.") }
        }
        SRow {
            icon: "key"; title: "Signing keys"; desc: "Reload the Arch Linux keyring if updates fail with signature or key errors"
            AxButton { text: page.busy === "keys" ? "Reloading…" : "Reload"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("keys", [page.admin, "keyring-refresh"], "Keyring reloaded.") }
        }
        SRow {
            icon: "public"; title: "Download mirrors"
            desc: (page.k.mirrors || "0") + (page.k.mirrors === "1" ? " server" : " servers") + "  ·  list is " + (page.k.mirrorsAge || 0) + " days old" + (page.k.reflector === "1" ? "" : "  ·  install reflector to rank them")
            AxButton { visible: page.k.reflector === "1"; text: page.busy === "mirrors" ? "Ranking…" : "Find the fastest"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("mirrors", [page.admin, "mirrors-refresh"], (o) => "Mirrors ranked — " + (o.trim().split(" ")[1] || "new") + " servers saved.") }
        }
        SRow {
            icon: "system_update"; title: "Updates"; desc: "System, AUR and Flatpak updates"; clickable: true; chevron: true
            onClicked: NSS.Shell.openSettings("updates")
        }
    }

    Section {
        title: "System"
        SRow {
            visible: page.k.mkinit === "1"
            icon: "rocket_launch"; title: "Rebuild the boot image"; desc: "Regenerate the initramfs for every kernel — after changing modules, hooks or encryption"
            ConfirmButton { label: page.busy === "init" ? "Rebuilding…" : "Rebuild"; kind: "ghost"; confirmText: "Rebuild now?"; anchors.verticalCenter: parent.verticalCenter
                            onConfirmed: page.act("init", [page.admin, "initramfs"], "Boot images rebuilt.") }
        }
        SRow {
            icon: "text_fields"; title: "Font cache"; desc: "Rebuild it if new fonts don't show up"
            AxButton { text: page.busy === "fonts" ? "Rebuilding…" : "Rebuild"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("fonts", ["fc-cache", "-f"], "Font cache rebuilt.") }
        }
        SRow {
            icon: "settings_backup_restore"; title: "Reload service definitions"; desc: "systemctl daemon-reload — after editing unit files"
            AxButton { text: "Reload"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.act("units", ["systemctl", "daemon-reload"], "Service definitions reloaded.") }
        }
        SRow {
            icon: "receipt_long"; title: "Failed services"; desc: +page.k.failed ? page.k.failed + " failed — see why in Logs" : "None"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("logs")
        }
    }

    Section {
        visible: page.biggest.length > 0
        title: "Largest packages"
        Repeater {
            model: page.biggest
            SRow {
                required property var modelData
                icon: "package_2"; title: modelData.name
                Label { text: page.bytes(modelData.bytes); mono: true; color: Ax.subtext; font.pixelSize: Ax.fsSmall; anchors.verticalCenter: parent.verticalCenter }
                ConfirmButton { icon: "delete"; confirmText: "Remove"; anchors.verticalCenter: parent.verticalCenter
                                onConfirmed: page.act("rm", [page.admin, "pkg-remove", modelData.name], modelData.name + " removed.") }
            }
        }
    }
}

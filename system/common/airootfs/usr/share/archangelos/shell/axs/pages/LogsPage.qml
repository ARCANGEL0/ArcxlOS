// Logs — the system journal made readable: problems this boot, failed services, crashes, and a
// filterable, searchable, live list of messages (by importance, source, boot and time).
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Maintenance"
    title: "Logs"
    desc: "What the system has been saying — and what went wrong."

    property var entries: []                     // { t, pri, ident, unit, pid, msg }
    property var boots: []                       // { idx, id, when }
    property var units: []
    property var failed: []                      // { unit, desc }
    property var crashes: []                     // { t, pid, exe, sig }
    property var counts: ({ err: 0, warn: 0 })
    property int level: 1                        // Errors, Warnings, Notices, Everything
    property int source: 0                       // 0 everything, 1 kernel, 2 my apps, 3+ a unit
    property int boot: 0                         // index into boots (0 = this boot)
    property int since: 0                        // any, last hour, last 10 minutes
    property string grep: ""
    property bool live: false
    property bool loading: false
    property int open_: -1
    property string notice: ""
    property string error: ""
    readonly property int limit: 300

    Cmd { id: cmd }
    Cmd { id: side }

    function args(full) {
        const a = ["--no-pager", "-q"];
        a.push("-p", ["3", "4", "5", "7"][page.level]);
        const b = page.boots[page.boot]; a.push("-b", b ? b.id : "0");
        if (page.source === 1) a.push("_TRANSPORT=kernel");
        else if (page.source === 2) a.push("--user");
        else if (page.source >= 3) a.push("-u", page.units[page.source - 3]);
        if (page.since === 1) a.push("--since", "-1h"); else if (page.since === 2) a.push("--since", "-10min");
        if (page.grep.trim()) a.push("--case-sensitive=false", "--grep", page.grep.trim());
        if (!full) a.push("-r", "-n", String(page.limit), "-o", "json", "--output-fields=MESSAGE,PRIORITY,SYSLOG_IDENTIFIER,_SYSTEMD_UNIT,_SYSTEMD_USER_UNIT,_COMM,_PID");
        return a;
    }
    function load() {
        if (cmd.busy) return;
        page.loading = true;
        cmd.run(["journalctl"].concat(page.args(false)), (c, o, e) => {
            page.loading = false;
            page.error = c !== 0 && c !== 1 && !o ? (e || "").trim().split("\n").pop() : "";
            const list = [];
            for (const l of o.split("\n")) {
                if (!l) continue;
                let j; try { j = JSON.parse(l); } catch (x) { continue; }
                let m = j.MESSAGE;
                if (Array.isArray(m)) m = String.fromCharCode(...m.slice(0, 4000));
                list.push({ t: Math.floor(+j.__REALTIME_TIMESTAMP / 1000), pri: +(j.PRIORITY ?? 6), ident: j.SYSLOG_IDENTIFIER || j._COMM || "kernel",
                            unit: j._SYSTEMD_UNIT || j._SYSTEMD_USER_UNIT || "", pid: j._PID || "", msg: m || "" });
            }
            page.entries = list;
        });
    }
    function loadSide() {
        side.sh('journalctl --list-boots --no-pager -q 2>/dev/null | tail -n 12; echo "--units"; '
              + 'systemctl list-units --type=service --all --no-legend --plain 2>/dev/null | awk \'{print $1}\' | grep "\\.service$" | head -n 400; echo "--failed"; '
              + 'systemctl --failed --no-legend --plain 2>/dev/null | while read -r u l a s d; do echo "$u|$d"; done; echo "--count"; '
              + 'journalctl -b -q --no-pager -p 3 -o cat 2>/dev/null | wc -l; journalctl -b -q --no-pager -p 4..4 -o cat 2>/dev/null | wc -l; echo "--crash"; '
              + 'command -v coredumpctl >/dev/null && coredumpctl list --no-pager -q -r -n 8 --json=short 2>/dev/null', [], (c, o) => {
            const part = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            const bootsTxt = o.slice(0, o.indexOf("--units"));
            page.boots = bootsTxt.split("\n").map(l => /^\s*(-?\d+)\s+([0-9a-f]{32})\s+\S+\s+(.+?)(?:\s+—|\s+\S+ \d{4}-\d\d-\d\d \d\d:\d\d:\d\d \S+)?$/.exec(l))
                                 .filter(m => m).map(m => ({ idx: +m[1], id: m[2], when: m[3] })).reverse();
            page.units = part("--units", "--failed").split("\n").filter(u => u).map(u => u.replace(/\.service$/, ""));
            page.failed = part("--failed", "--count").split("\n").filter(l => l.includes("|")).map(l => ({ unit: l.split("|")[0], desc: l.split("|")[1] }));
            const n = part("--count", "--crash").trim().split("\n");
            page.counts = { err: +(n[0] || 0), warn: +(n[1] || 0) };
            try { page.crashes = JSON.parse(part("--crash").trim() || "[]").map(x => ({ t: Math.floor(x.time / 1000), pid: x.pid, exe: x.exe || "", sig: x.sig, present: x.corefile === "present" })); }
            catch (e) { page.crashes = []; }
        });
    }
    Component.onCompleted: { page.loadSide(); page.load(); }
    Timer { interval: 2500; repeat: true; running: page.live; onTriggered: page.load() }
    Timer { id: debounce; interval: 350; onTriggered: page.load() }
    function refilter() { page.open_ = -1; debounce.restart(); }
    onLevelChanged: refilter()
    onSourceChanged: refilter()
    onBootChanged: refilter()
    onSinceChanged: refilter()
    onGrepChanged: refilter()

    function showUnit(u) {
        const i = page.units.indexOf(u.replace(/\.service$/, ""));
        page.level = 3; page.boot = 0;
        if (i >= 0) page.source = i + 3;
    }
    readonly property var priName: ["emergency", "alert", "critical", "error", "warning", "notice", "info", "debug"]
    function tone(p) { return p <= 3 ? Ax.danger : p === 4 ? "#d9a86a" : p === 5 ? Ax.accent : Ax.faint; }
    function clock(ms) { const d = new Date(ms); return Qt.formatDateTime(d, page.boot === 0 && page.since > 0 ? "HH:mm:ss" : "MMM d  HH:mm:ss"); }

    FilePick { id: savePick; save: true; title: "Save the log"; folder: Quickshell.env("HOME"); filters: ["Text (*.txt *.log)", "All files (*)"]
               suggested: "journal-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmm") + ".txt"
               onPicked: (p) => cmd.sh('f="$1"; shift; journalctl "$@" -o short-iso -n 20000 > "$f"', [p].concat(page.args(true)), (c, o, e) => {
                   page.notice = c === 0 ? "Saved to " + p.replace(Quickshell.env("HOME"), "~") : ""; page.error = c === 0 ? "" : (e || "Couldn't save.").trim(); noticeT.restart(); }) }
    Timer { id: noticeT; interval: 4000; onTriggered: page.notice = "" }

    header: Row {
        spacing: 8
        AxButton { icon: "download"; text: "Save…"; onClicked: savePick.open() }
        AxButton { icon: "refresh"; onClicked: { page.loadSide(); page.load(); } }
    }

    Row {
        width: parent.width; spacing: 14
        readonly property real w: (width - 42) / 4
        StatTile { width: parent.w; caption: "Errors this boot"; value: page.counts.err }
        StatTile { width: parent.w; caption: "Warnings this boot"; value: page.counts.warn }
        StatTile { width: parent.w; caption: "Failed services"; value: page.failed.length }
        StatTile { width: parent.w; caption: "Recent crashes"; value: page.crashes.length }
    }

    Section {
        visible: page.failed.length > 0
        title: "Failed services"
        Repeater {
            model: page.failed
            SRow {
                required property var modelData
                icon: "error"; title: modelData.unit; desc: modelData.desc
                AxButton { text: "Show log"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.showUnit(modelData.unit) }
                AxButton { text: "Restart"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: side.run(["systemctl", "restart", modelData.unit], (c, o, e) => { page.error = c === 0 ? "" : (e || o).trim(); page.loadSide(); }) }
            }
        }
    }

    Section {
        visible: page.crashes.length > 0
        title: "Crashes"
        note: "kept by systemd-coredump"
        Repeater {
            model: page.crashes
            SRow {
                required property var modelData
                icon: "heart_broken"; title: modelData.exe.split("/").pop() || "pid " + modelData.pid
                desc: Qt.formatDateTime(new Date(modelData.t), "MMM d, HH:mm") + "  ·  signal " + modelData.sig + "  ·  " + modelData.exe
                AxButton { text: "Show log"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: { page.source = 0; page.level = 3; page.grep = "pid " + modelData.pid; grepField.text = page.grep; } }
            }
        }
    }

    Section {
        title: "Journal"
        note: page.loading ? "reading…" : page.entries.length + (page.entries.length >= page.limit ? "+ (newest " + page.limit + ")" : "") + " messages"
        Item {
            property bool topDivider: false
            width: parent.width; height: fcol.implicitHeight + 30
            Column {
                id: fcol
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad; spacing: 10
                Row {
                    spacing: 10
                    AxSegment { options: ["Errors", "Warnings", "Notices", "Everything"]; current: page.level; onPicked: (i) => page.level = i }
                    AxSegment { options: ["Any time", "Last hour", "Last 10 min"]; current: page.since; onPicked: (i) => page.since = i }
                    Row {
                        spacing: 8; anchors.verticalCenter: parent.verticalCenter
                        AxSwitch { checked: page.live; onToggled: (on) => page.live = on; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Live"; color: page.live ? Ax.accent : Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Row {
                    spacing: 10
                    AxSelect { width: 230; model: ["Everything", "Kernel", "My apps (this session)"].concat(page.units); current: page.source; onPicked: (i) => page.source = i }
                    AxSelect { width: 250; model: page.boots.length ? page.boots.map((b, i) => (i === 0 ? "This boot" : i === 1 ? "Previous boot" : "Boot " + b.idx) + "  ·  " + b.when) : ["This boot"]
                               current: page.boot; onPicked: (i) => page.boot = i }
                    AxField { id: grepField; width: 200; icon: "search"; placeholder: "Search messages"; onTextChanged: page.grep = text }
                }
            }
        }
        Item {
            visible: page.entries.length === 0 && !page.loading
            property bool topDivider: false
            width: parent.width; height: 120
            EmptyState { anchors.fill: parent; icon: page.level === 0 ? "check_circle" : "manage_search"
                         title: page.error !== "" ? "Couldn't read the journal" : page.level === 0 ? "No errors" : "Nothing matches"
                         desc: page.error !== "" ? page.error : "Try a wider importance, another source or boot, or a different search." }
        }
        Repeater {
            model: page.entries
            Item {
                id: ent
                required property var modelData
                required property int index
                readonly property bool expanded: page.open_ === index
                property bool topDivider: false
                width: parent.width; height: ec.implicitHeight + 16
                Rectangle { visible: ent.topDivider; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
                Rectangle { anchors.fill: parent; anchors.margins: 3; radius: Ax.radiusSm; color: Ax.hover; visible: ma.containsMouse || ent.expanded }
                Rectangle { x: Ax.pad - 8; y: 15; width: 4; height: 4; radius: 2; color: page.tone(ent.modelData.pri) }
                Column {
                    id: ec
                    x: Ax.pad; y: 8; width: parent.width - 2 * Ax.pad; spacing: 4
                    Row {
                        spacing: 10; width: parent.width
                        Label { width: 128; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.faint; text: page.clock(ent.modelData.t) }
                        Label { width: 150; elide: Text.ElideRight; font.pixelSize: Ax.fsSmall; font.weight: Font.Medium; color: page.tone(ent.modelData.pri) === Ax.faint ? Ax.subtext : page.tone(ent.modelData.pri); text: ent.modelData.ident }
                        Label { width: parent.width - 298; font.pixelSize: Ax.fsSmall; color: Ax.text; text: ent.modelData.msg
                                wrapMode: ent.expanded ? Text.WrapAnywhere : Text.NoWrap; elide: ent.expanded ? Text.ElideNone : Text.ElideRight
                                maximumLineCount: ent.expanded ? 40 : 1 }
                    }
                    Row {
                        visible: ent.expanded; x: 138; spacing: 8
                        Badge { text: page.priName[ent.modelData.pri] || "info"; tone: ent.modelData.pri <= 3 ? "danger" : "neutral" }
                        Badge { visible: ent.modelData.unit !== ""; text: ent.modelData.unit }
                        Badge { visible: ent.modelData.pid !== ""; text: "pid " + ent.modelData.pid }
                        AxButton { icon: "content_copy"; text: "Copy"
                                   onClicked: Quickshell.execDetached(["wl-copy", "--", page.clock(ent.modelData.t) + " " + ent.modelData.ident + ": " + ent.modelData.msg]) }
                        AxButton { visible: ent.modelData.unit.endsWith(".service"); text: "Only this service"; onClicked: page.showUnit(ent.modelData.unit) }
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; z: -1; onClicked: page.open_ = ent.expanded ? -1 : ent.index }
            }
        }
    }

    Label { visible: page.notice !== ""; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }
}

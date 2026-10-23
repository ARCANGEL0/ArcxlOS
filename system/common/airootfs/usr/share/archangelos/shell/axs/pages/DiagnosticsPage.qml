// Diagnostics — everything about how the hardware is doing, live: processor, graphics, memory,
// disks (throughput, health, speed), temperatures and fans, the network (latency, DNS, speed),
// and what the machine is made of. Readings and tests come from /usr/lib/archangelos/axs-diag
// (runs as you); disk health, memory modules and the memory test need root (axs-admin).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Maintenance"
    title: "Diagnostics"
    desc: "How every part of this computer is doing — and tests to prove it."

    readonly property string diag: "/usr/lib/archangelos/axs-diag"
    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    readonly property var tabs: ["Overview", "CPU", "Graphics", "Memory", "Storage", "Thermals", "Network", "Hardware"]
    property int tab: 0

    property var s: null                          // the latest sample from `axs-diag watch`
    property var hist: ({ cpu: [], mem: [], dr: [], dw: [], rx: [], tx: [], gpu: [], temp: [] })
    property var dhist: ({})                      // per disk: { r: [], w: [] }
    property var hw: null
    property var smart: null                      // [smartctl -j objects]
    property var dimms: null                      // { max, slots, list: [{ k: v }] }
    property var cpuB: null
    property var memB: null
    property var diskB: null
    property var memtest: null                    // { ok, lines }
    property var pings: []
    property var dnsR: null
    property var speedR: null
    property string busy: ""
    property string error: ""
    property string notice: ""
    property bool allVulns: false
    property string benchDir: Quickshell.env("HOME")
    property int benchSize: 0
    property int mtSize: 0

    Cmd { id: cmd }
    Cmd { id: hwCmd }
    function ask(argv, cb) { cmd.run(argv, (c, o, e) => { let r = null; try { r = JSON.parse(o); } catch (x) {} cb(r, c, o, e); }); }
    Component.onCompleted: hwCmd.run([page.diag, "hw"], (c, o) => { try { page.hw = JSON.parse(o); } catch (e) {} })

    Process {
        id: watcher
        command: [page.diag, "watch", "1.5"]
        running: true
        stdout: SplitParser { onRead: (line) => page.feed(line) }
    }
    function push(arr, v) { const a = arr.concat([v]); return a.length > 60 ? a.slice(a.length - 60) : a; }
    function feed(line) {
        let x; try { x = JSON.parse(line); } catch (e) { return; }
        page.s = x;
        const h = page.hist, d = page.realDisks(x.disks), n = page.realNets(x.net);
        const hot = x.temps.length ? Math.max(...x.temps.map(t => t.c)) : 0;
        const g = x.gpus.find(g => g.busy !== null && g.busy !== undefined);
        page.hist = { cpu: page.push(h.cpu, x.cpu), mem: page.push(h.mem, 100 * x.mem.used / Math.max(1, x.mem.total)),
                      dr: page.push(h.dr, d.reduce((a, b) => a + b.r, 0)), dw: page.push(h.dw, d.reduce((a, b) => a + b.w, 0)),
                      rx: page.push(h.rx, n.reduce((a, b) => a + b.rx, 0)), tx: page.push(h.tx, n.reduce((a, b) => a + b.tx, 0)),
                      gpu: page.push(h.gpu, g ? g.busy : 0), temp: page.push(h.temp, hot) };
        const dh = Object.assign({}, page.dhist);
        for (const k of d) { const o = dh[k.dev] || { r: [], w: [] }; dh[k.dev] = { r: page.push(o.r, k.r), w: page.push(o.w, k.w) }; }
        page.dhist = dh;
    }
    function realDisks(ds) { return (ds || []).filter(d => !/^nbd/.test(d.dev)); }
    function realNets(ns) { return (ns || []).filter(n => !/^(veth|docker|br-|virbr|ifb|tun|wg|tailscale|vnet)/.test(n.dev) || n.up); }

    // ---- formatting ---------------------------------------------------------------------------
    function bytes(b, dec) {
        b = Number(b) || 0;
        const u = ["B", "KB", "MB", "GB", "TB", "PB"]; let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
        return (i === 0 ? Math.round(b) : b.toFixed(b >= 100 ? 0 : (dec ?? 1))) + " " + u[i];
    }
    function gib(b) { return (b / 1073741824).toFixed(1); }
    function rate(b) { return page.bytes(b) + "/s"; }
    function bits(b) { const m = b * 8 / 1e6; return m >= 1 ? m.toFixed(1) + " Mbit/s" : (b * 8 / 1e3).toFixed(0) + " kbit/s"; }
    function dur(sec) {
        sec = Math.floor(sec); const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m";
    }
    function ms(v) { return v === null || v === undefined ? "—" : (v < 10 ? v.toFixed(2) : v.toFixed(1)) + " ms"; }
    readonly property real hottest: s && s.temps.length ? Math.max(...s.temps.map(t => t.c)) : 0
    readonly property var gpuLive: s ? s.gpus : []

    function test(name, argv, done) {
        page.busy = name; page.error = "";
        page.ask(argv, (r, c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) { page.error = "Cancelled."; return; }
            if (c !== 0 && !r) { page.error = (e || o).trim().split("\n").pop() || "That test didn't run."; return; }
            if (r && r.error) page.error = r.error;
            done(r, o);
        });
    }
    function runPings() {
        page.pings = []; page.busy = "ping"; page.error = "";
        const hosts = ["gateway", "1.1.1.1", "8.8.8.8", "archlinux.org"];
        const step = (i) => {
            if (i >= hosts.length) { page.busy = ""; return; }
            page.ask([page.diag, "ping", hosts[i], "10"], (r) => {
                page.pings = page.pings.concat([Object.assign({ label: ["Your router", "Cloudflare", "Google", "archlinux.org"][i] }, r || { error: "No answer" })]);
                step(i + 1);
            });
        };
        step(0);
    }
    function readSmart() {
        page.busy = "smart"; page.error = "";
        cmd.run([page.admin, "diag-smart"], (c, o, e) => {
            page.busy = "";
            if (c !== 0) { page.error = c === 126 ? "Cancelled." : (e || o).trim() || "Couldn't read disk health."; return; }
            const list = [];
            for (const l of o.split("\n")) { try { if (l.trim()) list.push(JSON.parse(l)); } catch (x) {} }
            page.smart = list.length === 1 && list[0].missing ? [] : list;
            if (list.length === 1 && list[0].missing) page.error = "smartmontools isn't installed — sudo pacman -S smartmontools";
        });
    }
    function readDimms() {
        page.busy = "dmi"; page.error = "";
        cmd.run([page.admin, "diag-dmi"], (c, o, e) => {
            page.busy = "";
            if (c !== 0) { page.error = c === 126 ? "Cancelled." : (e || o).trim() || "Couldn't read the memory modules."; return; }
            const r = { max: "", slots: "", list: [] };
            for (const l of o.split("\n")) {
                if (l.startsWith("max=")) r.max = l.slice(4);
                else if (l.startsWith("slots=")) r.slots = l.slice(6);
                else if (l.startsWith("dimm=")) {
                    const m = {}; for (const kv of l.slice(5).split("|")) { const i = kv.indexOf("="); if (i > 0) m[kv.slice(0, i)] = kv.slice(i + 1); }
                    r.list.push(m);
                }
            }
            page.dimms = r;
        });
    }
    function runMemtest() {
        const free = page.s ? page.s.mem.avail / 1048576 : 2048;
        const mb = [256, 1024, 4096, Math.floor(free / 2)][page.mtSize];
        page.busy = "memtest"; page.error = ""; page.memtest = null;
        cmd.run([page.admin, "diag-memtest", String(Math.max(16, mb)), "1"], (c, o, e) => {
            page.busy = "";
            if (c === 126) { page.error = "Cancelled."; return; }
            const lines = o.split("\n").map(l => l.trim()).filter(l => l);
            if (c !== 0 && !lines.some(l => /FAILURE/.test(l))) { page.error = (e || o).trim().split("\n").pop() || "memtester didn't run."; return; }
            page.memtest = { ok: c === 0 && !lines.some(l => /FAILURE/.test(l)), mb: mb, lines: lines.filter(l => /:/.test(l) && !/^Loop|^Done|^memtester|^Copyright|^pagesize|^pagesizemask|^want|^got/.test(l)) };
        });
    }

    // SMART, flattened to what people care about
    function smartSum(j) {
        const nv = j.nvme_smart_health_information_log, at = (j.ata_smart_attributes || {}).table || [];
        const attr = (id) => { const a = at.find(x => x.id === id); return a ? a.raw.value : null; };
        const r = { dev: (j.device || {}).name || "", model: j.model_name || j.model_family || "", serial: j.serial_number || "",
                    passed: j.smart_status ? j.smart_status.passed : null, temp: (j.temperature || {}).current ?? null,
                    hours: (j.power_on_time || {}).hours ?? null, cycles: j.power_cycle_count ?? null,
                    nvme: !!nv, wear: null, written: null, read: null, realloc: null, pending: null, media: null, spare: null,
                    unsafe: null, selftest: "" , firmware: j.firmware_version || "", capacity: (j.user_capacity || {}).bytes || 0 };
        if (nv) {
            r.wear = nv.percentage_used; r.written = nv.data_units_written * 512000; r.read = nv.data_units_read * 512000;
            r.media = nv.media_errors; r.spare = nv.available_spare; r.unsafe = nv.unsafe_shutdowns;
            const t = ((j.nvme_self_test_log || {}).table || [])[0]; if (t) r.selftest = (t.self_test_result || {}).string || "";
        } else {
            r.realloc = attr(5); r.pending = attr(197); const lba = attr(241); if (lba !== null) r.written = lba * ((j.logical_block_size) || 512);
            const w = at.find(x => [177, 231, 233, 202].indexOf(x.id) >= 0); if (w) r.wear = 100 - w.value;
            const t = (((j.ata_smart_self_test_log || {}).standard || {}).table || [])[0]; if (t) r.selftest = (t.status || {}).string || "";
        }
        return r;
    }
    readonly property var smartList: (smart || []).filter(j => j.device).map(j => page.smartSum(j))
    function smartBad(r) { return r.passed === false || r.realloc > 0 || r.pending > 0 || r.media > 0 || (r.wear !== null && r.wear >= 90); }

    // ---- pieces -------------------------------------------------------------------------------
    component Graph: Rectangle {
        property string label: ""
        property string value: ""
        property string sub: ""
        property var a: []
        property var b: []
        property real max: 0
        width: (parent.width - 14) / 2; height: 136
        radius: Ax.radius; color: Ax.panel; border.width: 1; border.color: Ax.border
        Label { x: 16; y: 14; caption: true; text: parent.label }
        Label { anchors.right: parent.right; anchors.rightMargin: 16; y: 10; mono: true; font.pixelSize: Ax.fsHead; text: parent.value }
        Label { anchors.right: parent.right; anchors.rightMargin: 16; y: 32; font.pixelSize: Ax.fsSmall; color: Ax.muted; text: parent.sub }
        Spark { x: 14; y: 56; width: parent.width - 28; height: parent.height - 70; a: parent.a; b: parent.b; max: parent.max }
    }
    component KV: SRow {
        id: kv
        property string value: ""
        Label { text: kv.value; mono: true; color: Ax.subtext; font.pixelSize: Ax.fsSmall; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 420); elide: Text.ElideMiddle; horizontalAlignment: Text.AlignRight }
    }
    component Run: AxButton {
        property string job: ""
        kind: "primary"
        enabled_: page.busy === ""
        text: page.busy === job ? "Running…" : "Run"
    }
    component Check: SRow {
        id: chk
        property string level: "ok"         // ok | warn | bad
        Badge { text: chk.level === "ok" ? "good" : chk.level === "warn" ? "watch" : "problem"
                tone: chk.level === "ok" ? "ok" : chk.level === "warn" ? "neutral" : "danger"; anchors.verticalCenter: parent.verticalCenter }
    }

    header: AxButton {
        visible: page.tab === 7 && page.hw !== null
        icon: "content_copy"; text: page.notice || "Copy report"
        onClicked: { Quickshell.execDetached(["wl-copy", "--", page.report()]); page.notice = "Copied"; noticeT.restart(); }
    }
    Timer { id: noticeT; interval: 2500; onTriggered: page.notice = "" }

    AxSegment { options: page.tabs; current: page.tab; onPicked: (i) => page.tab = i }
    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    // ======================================================== Overview
    Column {
        visible: page.tab === 0
        width: parent.width; spacing: 14
        Rectangle {
            width: parent.width; height: 78
            radius: Ax.radius; color: Ax.panel; border.width: 1; border.color: Ax.border
            CornerTicks { len: 8; anchors.margins: 10 }
            Column {
                x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Label { text: page.hw ? (page.hw.system.product && !/To Be Filled|System Product/i.test(page.hw.system.product) ? page.hw.system.vendor + " " + page.hw.system.product : page.hw.system.host) : "This computer"; font.weight: Font.Medium; font.pixelSize: Ax.fsHead }
                Label { font.pixelSize: Ax.fsSmall; color: Ax.muted
                        text: (page.hw ? page.hw.cpu.model + "  ·  " + page.gib(page.hw.memory.total) + " GB" : "Reading…") + (page.s ? "  ·  up " + page.dur(page.s.uptime) : "") }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 22
                Repeater {
                    model: page.s ? [["Load", page.s.load[0]], ["Processes", page.s.procs], ["Kernel", page.hw ? page.hw.system.kernel.split("-")[0] : "—"]] : []
                    Column { required property var modelData; spacing: 2
                             Label { caption: true; text: modelData[0] }
                             Label { mono: true; text: modelData[1] } }
                }
            }
        }
        Row {
            width: parent.width; spacing: 14
            readonly property real w: (width - 42) / 4
            StatTile { width: parent.w; caption: "Processor"; value: page.s ? Math.round(page.s.cpu) : "—"; unit: "%"; meter: page.s ? page.s.cpu / 100 : 0 }
            StatTile { width: parent.w; caption: "Memory · " + (page.s ? page.gib(page.s.mem.total) + " GB" : ""); value: page.s ? page.gib(page.s.mem.used) : "—"; unit: "GB"
                       meter: page.s ? page.s.mem.used / page.s.mem.total : 0 }
            StatTile { width: parent.w; caption: "Graphics"; value: page.gpuLive.length && page.gpuLive[0].busy !== null ? Math.round(page.gpuLive[0].busy) : "—"; unit: page.gpuLive.length ? "%" : ""
                       meter: page.gpuLive.length && page.gpuLive[0].busy !== null ? page.gpuLive[0].busy / 100 : 0 }
            StatTile { width: parent.w; caption: "Hottest sensor"; value: page.hottest ? Math.round(page.hottest) : "—"; unit: page.hottest ? "°C" : ""; meter: page.hottest / 100 }
        }
        Flow {
            width: parent.width; spacing: 14
            Graph { label: "Processor"; value: page.s ? page.s.cpu.toFixed(0) + "%" : ""; sub: page.s ? "load " + page.s.load.join("  ") : ""; a: page.hist.cpu; max: 100 }
            Graph { label: "Memory"; value: page.s ? page.gib(page.s.mem.used) + " GB" : ""; sub: page.s ? page.gib(page.s.mem.avail) + " GB available" : ""; a: page.hist.mem; max: 100 }
            Graph { label: "Disks  ·  read / write"; value: page.rate(page.hist.dr[page.hist.dr.length - 1] || 0); sub: "write " + page.rate(page.hist.dw[page.hist.dw.length - 1] || 0); a: page.hist.dr; b: page.hist.dw }
            Graph { label: "Network  ·  down / up"; value: page.bits(page.hist.rx[page.hist.rx.length - 1] || 0); sub: "up " + page.bits(page.hist.tx[page.hist.tx.length - 1] || 0); a: page.hist.rx; b: page.hist.tx }
        }
        Section {
            title: "Quick check"
            Check { icon: "memory"; title: "Processor load"
                    readonly property real l: page.s ? +page.s.load[0] / Math.max(1, page.s.cores.length) : 0
                    level: l > 1.5 ? "bad" : l > 0.9 ? "warn" : "ok"
                    desc: page.s ? "Load " + page.s.load[0] + " on " + page.s.cores.length + " threads" : "…" }
            Check { icon: "memory_alt"; title: "Memory"
                    readonly property real f: page.s ? page.s.mem.avail / page.s.mem.total : 1
                    level: f < 0.05 ? "bad" : f < 0.15 ? "warn" : "ok"
                    desc: page.s ? page.gib(page.s.mem.avail) + " GB free of " + page.gib(page.s.mem.total) + " GB" + (page.s.mem.swapUsed > 0 ? "  ·  " + page.bytes(page.s.mem.swapUsed) + " in swap" : "") : "…" }
            Check { icon: "device_thermostat"; title: "Temperatures"
                    readonly property var worst: page.s ? page.s.temps.filter(t => t.crit > 0 && t.c >= t.crit * 0.9) : []
                    level: worst.length ? "bad" : page.hottest >= 85 ? "warn" : "ok"
                    desc: !page.s || !page.s.temps.length ? "No sensors reported" : worst.length ? worst[0].label + " is near its limit (" + worst[0].c + " °C)" : "Hottest " + page.hottest + " °C" }
            Check { icon: "hard_drive"; title: "Disk health"
                    level: page.smart === null ? "ok" : page.smartList.some(r => page.smartBad(r)) ? "bad" : "ok"
                    desc: page.smart === null ? "Not checked yet" : page.smartList.length === 0 ? "No drives report SMART" : page.smartList.map(r => r.dev.replace("/dev/", "") + (page.smartBad(r) ? " needs attention" : " healthy")).join("  ·  ")
                    AxButton { visible: page.smart === null; text: page.busy === "smart" ? "Reading…" : "Check"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.readSmart() } }
        }
        Row {
            width: parent.width; spacing: 14
            Section {
                width: (parent.width - 14) / 2; title: "Busiest  ·  processor"
                Repeater { model: page.s ? page.s.top : []
                    KV { required property var modelData; title: modelData.name; desc: "pid " + modelData.pid; value: modelData.cpu.toFixed(1) + "%" } }
            }
            Section {
                width: (parent.width - 14) / 2; title: "Busiest  ·  memory"
                Repeater { model: page.s ? page.s.topMem : []
                    KV { required property var modelData; title: modelData.name; desc: "pid " + modelData.pid; value: page.bytes(modelData.rss) } }
            }
        }
    }

    // ======================================================== CPU
    Column {
        visible: page.tab === 1
        width: parent.width; spacing: 14
        Section {
            title: "Processor"
            KV { icon: "memory"; title: page.hw ? page.hw.cpu.model : "…"; desc: page.hw ? page.hw.cpu.vendor + "  ·  " + page.hw.cpu.arch : ""
                 value: page.hw ? (page.hw.cpu.cores ? page.hw.cpu.cores * (page.hw.cpu.sockets || 1) + " cores · " : "") + page.hw.cpu.threads + " threads" : "" }
            KV { icon: "speed"; title: "Clock"; value: page.hw && page.hw.cpu.maxMhz ? Math.round(page.hw.cpu.minMhz) + " – " + Math.round(page.hw.cpu.maxMhz) + " MHz" : "—"
                 desc: page.s && page.s.freq.some(f => f) ? "Now " + Math.round(page.s.freq.filter(f => f).reduce((a, b) => a + b, 0) / page.s.freq.filter(f => f).length) + " MHz average" : "" }
            KV { icon: "tune"; title: "Frequency scaling"; value: page.hw && page.hw.cpu.driver ? page.hw.cpu.driver + " · " + page.hw.cpu.governor : "Not exposed" }
            KV { icon: "layers"; title: "Cache"; value: page.hw ? [["L1d", page.hw.cpu.l1d], ["L2", page.hw.cpu.l2], ["L3", page.hw.cpu.l3]].filter(x => x[1]).map(x => x[0] + " " + x[1].replace(/ \(.*\)$/, "")).join("  ·  ") : "" }
        }
        Graph { width: parent.width; label: "All cores"; value: page.s ? page.s.cpu.toFixed(0) + "%" : ""; sub: page.s ? "load " + page.s.load.join("  ") : ""; a: page.hist.cpu; max: 100 }
        Section {
            title: "Per thread"
            note: page.s ? page.s.cores.length + " threads" : ""
            Item {
                property bool topDivider: false
                width: parent.width; height: cores.implicitHeight + 32
                Flow {
                    id: cores
                    x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad; spacing: 10
                    Repeater {
                        model: page.s ? page.s.cores.length : 0
                        Rectangle {
                            required property int index
                            width: (cores.width - 30) / 4; height: 58; radius: Ax.radiusSm; color: Ax.raised; border.width: 1; border.color: Ax.border
                            Label { x: 10; y: 8; caption: true; text: "Thread " + parent.index }
                            Label { anchors.right: parent.right; anchors.rightMargin: 10; y: 6; mono: true; font.pixelSize: Ax.fsSmall
                                    text: Math.round(page.s.cores[parent.index]) + "%" }
                            Label { x: 10; y: 24; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.faint
                                    text: page.s.freq[parent.index] ? page.s.freq[parent.index] + " MHz" : "" }
                            Meter { x: 10; y: 44; width: parent.width - 20; height: 5; notches: 16; value: page.s.cores[parent.index] / 100 }
                        }
                    }
                }
            }
        }
        Section {
            title: "Benchmark"
            SRow {
                icon: "bolt"; title: "Hashing throughput"
                desc: page.cpuB ? "One thread " + page.cpuB.single + " MB/s  ·  all " + page.cpuB.threads + " threads " + page.cpuB.multi + " MB/s  ·  scales ×" + page.cpuB.scaling
                                : "SHA-256 on one thread, then on every thread — about 7 seconds"
                Run { job: "cpu"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.test("cpu", [page.diag, "cpu"], r => page.cpuB = r) }
            }
        }
        Section {
            visible: page.hw !== null
            title: "Features"
            Item {
                property bool topDivider: false
                width: parent.width; height: feats.implicitHeight + 30
                Flow {
                    id: feats
                    x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad; spacing: 8
                    Repeater { model: page.hw ? page.hw.cpu.features.map(f => ({ avx: "AVX", avx2: "AVX2", avx512f: "AVX-512", aes: "AES-NI", sha_ni: "SHA extensions", vmx: "Intel VT-x", svm: "AMD-V", rdrand: "Hardware RNG" })[f] || f) : []
                               Badge { required property string modelData; text: modelData; tone: "accent" } }
                }
            }
        }
        Section {
            visible: page.hw !== null
            title: "Security mitigations"
            note: page.hw ? page.hw.cpu.vulns.filter(v => /^Vulnerable/.test(v.state)).length + " vulnerable" : ""
            Repeater {
                model: page.hw ? page.hw.cpu.vulns.filter(v => page.allVulns || !/^Not affected/.test(v.state)) : []
                SRow {
                    required property var modelData
                    title: modelData.name.replace(/_/g, " "); desc: modelData.state
                    Badge { text: /^Vulnerable/.test(modelData.state) ? "vulnerable" : /^Not affected/.test(modelData.state) ? "not affected" : "mitigated"
                            tone: /^Vulnerable/.test(modelData.state) ? "danger" : "ok"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            SRow { title: page.allVulns ? "Hide the ones that don't apply" : "Show all"; clickable: true; chevron: true; onClicked: page.allVulns = !page.allVulns }
        }
    }

    // ======================================================== Graphics
    Column {
        visible: page.tab === 2
        width: parent.width; spacing: 14
        Section {
            visible: page.hw && page.hw.gpus.length === 0
            EmptyState { icon: "developer_board"; title: "No graphics card found"; desc: "lspci didn't list a display controller." }
        }
        Repeater {
            model: page.hw ? page.hw.gpus : []
            Section {
                id: gs
                required property var modelData
                required property int index
                readonly property var live: page.gpuLive.find(g => g.driver === modelData.driver) || null
                title: "Graphics " + (index + 1)
                KV { icon: "developer_board"; title: modelData.name; desc: "PCI " + modelData.slot; value: modelData.driver || "no driver" }
                KV { visible: !!gs.live && gs.live.busy !== null; icon: "speed"; title: "Load"; value: gs.live && gs.live.busy !== null ? Math.round(gs.live.busy) + "%" : "" }
                KV { visible: !!gs.live && !!gs.live.vramTotal; icon: "memory"; title: "Video memory"
                     value: gs.live && gs.live.vramTotal ? page.bytes(gs.live.vramUsed) + " of " + page.bytes(gs.live.vramTotal) : "" }
                KV { visible: !!gs.live && !!gs.live.freq; icon: "avg_pace"; title: "Core clock"; value: gs.live ? gs.live.freq || "" : "" }
                KV { visible: !!gs.live && gs.live.temp !== undefined && gs.live.temp !== null; icon: "device_thermostat"; title: "Temperature"; value: gs.live && gs.live.temp ? gs.live.temp + " °C" : "" }
                KV { visible: !!gs.live && !!gs.live.power; icon: "bolt"; title: "Power draw"; value: gs.live && gs.live.power ? gs.live.power + " W" : "" }
                SRow { visible: !gs.live || gs.live.busy === null; dim: true; icon: "info"; title: "No live readings"; desc: "This driver doesn't report load or memory to the system." }
            }
        }
        Graph { visible: page.gpuLive.some(g => g.busy !== null); width: parent.width; label: "Graphics load"; value: page.gpuLive.length && page.gpuLive[0].busy !== null ? Math.round(page.gpuLive[0].busy) + "%" : ""; a: page.hist.gpu; max: 100 }
    }

    // ======================================================== Memory
    Column {
        visible: page.tab === 3
        width: parent.width; spacing: 14
        Rectangle {
            id: memCard
            width: parent.width; height: 96
            radius: Ax.radius; color: Ax.panel; border.width: 1; border.color: Ax.border
            readonly property var m: page.s ? page.s.mem : null
            Label { x: 20; y: 16; caption: true; text: "Memory  ·  " + (memCard.m ? page.gib(memCard.m.total) + " GB" : "") }
            Row {
                x: 20; y: 40; width: parent.width - 40; height: 12
                Repeater {
                    model: memCard.m ? [[memCard.m.used, Ax.accent], [memCard.m.cached, Ax.alpha(Ax.accent, 0.35)], [memCard.m.total - memCard.m.used - memCard.m.cached, Ax.raised]] : []
                    Rectangle { required property var modelData; height: 12; width: Math.max(0, parent.width * modelData[0] / memCard.m.total); color: modelData[1] }
                }
            }
            Row {
                x: 20; y: 64; spacing: 22
                Repeater {
                    model: memCard.m ? [["In use", memCard.m.used, Ax.accent], ["Cache (freed on demand)", memCard.m.cached, Ax.alpha(Ax.accent, 0.35)], ["Available", memCard.m.avail, Ax.raised]] : []
                    Row { required property var modelData; spacing: 6
                          Rectangle { width: 9; height: 9; radius: 2; color: modelData[2]; anchors.verticalCenter: parent.verticalCenter; border.width: 1; border.color: Ax.border }
                          Label { font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: modelData[0] + "  " + page.gib(modelData[1]) + " GB" } }
                }
            }
        }
        Graph { width: parent.width; label: "Memory in use"; value: page.s ? (100 * page.s.mem.used / page.s.mem.total).toFixed(0) + "%" : ""; a: page.hist.mem; max: 100 }
        Section {
            title: "Details"
            KV { icon: "swap_horiz"; title: "Swap"; value: page.s && page.s.mem.swapTotal ? page.bytes(page.s.mem.swapUsed) + " of " + page.bytes(page.s.mem.swapTotal) : "None"
                 desc: page.hw && page.hw.memory.zram ? "Compressed in RAM (zram, " + page.bytes(page.hw.memory.zram) + ")" : "" }
            KV { icon: "edit_note"; title: "Waiting to be written"; value: page.s ? page.bytes(page.s.mem.dirty) : "" }
            KV { icon: "share"; title: "Shared"; value: page.s ? page.bytes(page.s.mem.shmem) : "" }
            KV { icon: "inventory"; title: "Buffers"; value: page.s ? page.bytes(page.s.mem.buffers) : "" }
        }
        Section {
            title: "Modules"
            note: page.dimms ? page.dimms.list.filter(d => !/No Module/i.test(d.Size)).length + " of " + (page.dimms.slots || page.dimms.list.length) + " slots" + (page.dimms.max ? "  ·  up to " + page.dimms.max : "") : ""
            SRow {
                visible: page.dimms === null
                icon: "memory_alt"; title: "Memory modules"; desc: "Size, speed, type and maker of each stick — needs your password"
                AxButton { text: page.busy === "dmi" ? "Reading…" : "Read"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.readDimms() }
            }
            Repeater {
                model: page.dimms ? page.dimms.list : []
                KV {
                    required property var modelData
                    readonly property bool empty: /No Module/i.test(modelData.Size || "")
                    dim: empty; icon: "memory_alt"
                    title: (modelData.Locator || "Slot") + (empty ? "  ·  empty" : "  ·  " + modelData.Size)
                    desc: empty ? "" : [modelData.Type, modelData["Form Factor"], modelData.Manufacturer, modelData["Part Number"]].filter(x => x && !/Unknown|Not Specified/i.test(x)).join("  ·  ")
                    value: empty ? "" : (modelData["Configured Memory Speed"] || modelData.Speed || "")
                }
            }
        }
        Section {
            title: "Memory test"
            SRow {
                icon: "fact_check"; title: "Test for faulty memory"
                desc: page.busy === "memtest" ? "Testing — this takes a few minutes, keep the computer otherwise idle"
                    : page.memtest ? (page.memtest.ok ? "Passed — " + page.bytes(page.memtest.mb * 1048576) + " tested, no errors" : "Errors found — a memory module may be failing")
                    : "Writes patterns to free memory with memtester and reads them back"
                Badge { visible: !!page.memtest; text: page.memtest && page.memtest.ok ? "passed" : "failed"; tone: page.memtest && page.memtest.ok ? "ok" : "danger"; anchors.verticalCenter: parent.verticalCenter }
                AxSegment { options: ["256 MB", "1 GB", "4 GB", "Half of free"]; current: page.mtSize; onPicked: (i) => page.mtSize = i; anchors.verticalCenter: parent.verticalCenter }
                Run { job: "memtest"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.runMemtest() }
            }
            Repeater {
                model: page.memtest ? page.memtest.lines : []
                KV { required property string modelData; readonly property var p: modelData.split(":"); title: p[0]; value: p.slice(1).join(":").trim() }
            }
            SRow {
                icon: "bolt"; title: "Bandwidth"
                desc: page.memB ? page.memB.copy + " GB/s copied  ·  " + page.memB.moved + " GB/s through the memory bus" : "How fast memory can be copied — 3 seconds"
                Run { job: "mem"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.test("mem", [page.diag, "mem"], r => page.memB = r) }
            }
        }
    }

    // ======================================================== Storage
    Column {
        visible: page.tab === 4
        width: parent.width; spacing: 14
        Repeater {
            model: page.hw ? page.hw.disks : []
            Section {
                id: ds
                required property var modelData
                readonly property var live: page.s ? page.s.disks.find(d => d.dev === modelData.name) : null
                readonly property var hh: page.dhist[modelData.name] || { r: [], w: [] }
                readonly property var sm: page.smartList.find(r => r.dev === modelData.path) || null
                title: modelData.name + "  ·  " + (modelData.tran === "nvme" || /^nvme/.test(modelData.name) ? "NVMe" : modelData.rota ? "Hard disk" : modelData.tran === "usb" ? "USB" : "SSD")
                note: page.bytes(modelData.size)
                KV { icon: "hard_drive"; title: modelData.model || modelData.name; desc: [modelData.tran ? modelData.tran.toUpperCase() : "", modelData.rev ? "firmware " + modelData.rev : "", modelData.sched ? "scheduler " + modelData.sched : ""].filter(x => x).join("  ·  ")
                     value: ds.live ? "busy " + Math.round(ds.live.busy) + "%" : "" }
                Item {
                    property bool topDivider: false
                    width: parent.width; height: 120
                    Rectangle { visible: parent.topDivider; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
                    Column {
                        x: Ax.pad; y: 16; spacing: 8; width: 210
                        Row { spacing: 8; Rectangle { width: 9; height: 9; radius: 2; color: Ax.accent; anchors.verticalCenter: parent.verticalCenter }
                              Label { mono: true; text: "Read  " + page.rate(ds.live ? ds.live.r : 0) } }
                        Row { spacing: 8; Rectangle { width: 9; height: 9; radius: 2; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
                              Label { mono: true; text: "Write " + page.rate(ds.live ? ds.live.w : 0) } }
                        Label { font.pixelSize: Ax.fsSmall; color: Ax.muted; text: ds.live ? Math.round(ds.live.riops) + " / " + Math.round(ds.live.wiops) + " operations a second" : "" }
                        Label { font.pixelSize: Ax.fsSmall; color: Ax.faint; text: ds.live ? "Since boot: " + page.bytes(ds.live.readTotal) + " read, " + page.bytes(ds.live.writeTotal) + " written" : "" }
                    }
                    Spark { x: 250; y: 14; width: parent.width - 250 - Ax.pad; height: 92; a: ds.hh.r; b: ds.hh.w }
                }
                // health
                Check {
                    visible: !!ds.sm
                    icon: "health_metrics"; title: "Health"
                    level: ds.sm && page.smartBad(ds.sm) ? "bad" : ds.sm && ds.sm.wear !== null && ds.sm.wear >= 70 ? "warn" : "ok"
                    desc: !ds.sm ? "" : [ds.sm.passed === null ? "" : ds.sm.passed ? "SMART passed" : "SMART FAILED",
                        ds.sm.wear !== null ? ds.sm.wear + "% worn" : "", ds.sm.temp !== null ? ds.sm.temp + " °C" : "",
                        ds.sm.hours !== null ? Math.round(ds.sm.hours).toLocaleString() + " hours on" : "", ds.sm.cycles !== null ? ds.sm.cycles + " power-ons" : ""].filter(x => x).join("  ·  ")
                }
                KV { visible: !!ds.sm && ds.sm.written !== null; icon: "edit"; title: "Written over its life"; value: ds.sm && ds.sm.written !== null ? page.bytes(ds.sm.written) + (ds.sm.read ? "  ·  read " + page.bytes(ds.sm.read) : "") : "" }
                KV { visible: !!ds.sm && (ds.sm.realloc !== null || ds.sm.media !== null); icon: "error"; title: ds.sm && ds.sm.nvme ? "Media errors" : "Bad sectors"
                     desc: ds.sm && ds.sm.nvme ? (ds.sm.spare !== null ? ds.sm.spare + "% spare left  ·  " : "") + (ds.sm.unsafe !== null ? ds.sm.unsafe + " unsafe shutdowns" : "") : "Reallocated, and waiting to be"
                     value: ds.sm ? (ds.sm.nvme ? String(ds.sm.media) : ds.sm.realloc + " / " + (ds.sm.pending ?? 0)) : "" }
                SRow {
                    visible: !!ds.sm
                    icon: "troubleshoot"; title: "Self-test"; desc: ds.sm && ds.sm.selftest ? "Last: " + ds.sm.selftest : "The drive checks itself in the background (short ~2 min, long can take hours)"
                    AxButton { text: "Short"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                               onClicked: page.test("selftest", [page.admin, "diag-smart-test", ds.modelData.path, "short"], (r, o) => page.error = o.trim()) }
                    AxButton { text: "Long"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                               onClicked: page.test("selftest", [page.admin, "diag-smart-test", ds.modelData.path, "long"], (r, o) => page.error = o.trim()) }
                }
            }
        }
        Section {
            visible: page.smart === null || page.smart.length === 0
            SRow {
                icon: "health_metrics"; title: "Disk health (SMART)"; desc: "Wear, bad sectors, temperature and lifetime writes — needs your password"
                AxButton { text: page.busy === "smart" ? "Reading…" : "Read"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.readSmart() }
            }
        }
        Section {
            title: "Speed test"
            SRow {
                icon: "folder"; title: "Test in"; desc: page.benchDir
                AxSegment { options: ["256 MB", "1 GB"]; current: page.benchSize; onPicked: (i) => page.benchSize = i; anchors.verticalCenter: parent.verticalCenter }
                AxButton { text: "Change…"; anchors.verticalCenter: parent.verticalCenter; onClicked: dirPick.open() }
                Run { job: "disk"; anchors.verticalCenter: parent.verticalCenter
                      onClicked: page.test("disk", [page.diag, "disk", page.benchDir, page.benchSize ? "1024" : "256"], r => page.diskB = r) }
            }
            KV { visible: !!page.diskB && !!page.diskB.write; icon: "upload"; title: "Sequential write"; value: page.diskB ? page.diskB.write + " MB/s" : "" }
            KV { visible: !!page.diskB && !!page.diskB.read; icon: "download"; title: "Sequential read"; value: page.diskB ? page.diskB.read + " MB/s" : ""
                 desc: page.diskB && page.diskB.read ? (page.diskB.read > 1500 ? "NVMe-class" : page.diskB.read > 300 ? "SATA SSD-class" : "Hard disk or USB-class") + (page.diskB.direct ? "" : "  ·  cache couldn't be bypassed here, so this reads high") : "" }
            KV { visible: !!page.diskB && !!page.diskB.iops; icon: "shuffle"; title: "Random 4K reads"; value: page.diskB ? page.diskB.iops.toLocaleString() + " IOPS" : ""
                 desc: page.diskB && page.diskB.lat ? page.diskB.lat + " ms each" : "" }
        }
        FilePick { id: dirPick; title: "Where to run the test"; pickFolder: true; folder: page.benchDir; onPicked: (p) => page.benchDir = p }
    }

    // ======================================================== Thermals
    Column {
        visible: page.tab === 5
        width: parent.width; spacing: 14
        Graph { width: parent.width; label: "Hottest sensor"; value: page.hottest ? page.hottest + " °C" : "—"; a: page.hist.temp; max: 100 }
        Section {
            title: "Temperatures"
            note: page.s ? page.s.temps.length + " sensors" : ""
            EmptyState { visible: !!page.s && page.s.temps.length === 0; icon: "device_thermostat"; title: "No temperature sensors"; desc: "Virtual machines and some laptops don't expose any." }
            Repeater {
                model: page.s ? page.s.temps : []
                SRow {
                    id: tr
                    required property var modelData
                    readonly property real lim: modelData.crit > 20 ? modelData.crit : 100
                    icon: /cpu|k10|core|package/i.test(modelData.chip + modelData.label) ? "memory" : /nvme|drive|sd/i.test(modelData.chip) ? "hard_drive" : /gpu|amdgpu|nouveau/i.test(modelData.chip) ? "developer_board" : "device_thermostat"
                    title: modelData.label; desc: modelData.chip + (modelData.crit > 20 ? "  ·  limit " + Math.round(modelData.crit) + " °C" : "")
                    Meter { width: 140; height: 6; notches: 18; value: Math.min(1, modelData.c / tr.lim); tint: modelData.c >= tr.lim * 0.9 ? Ax.danger : Ax.accent; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: 64; horizontalAlignment: Text.AlignRight; mono: true; text: modelData.c.toFixed(0) + " °C"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Section {
            title: "Fans"
            EmptyState { visible: !!page.s && page.s.fans.length === 0; icon: "mode_fan"; title: "No fans reported"; desc: "The board doesn't expose fan speeds, or it needs a sensor driver (see sensors-detect)." }
            Repeater {
                model: page.s ? page.s.fans : []
                SRow {
                    required property var modelData
                    icon: "mode_fan"; title: modelData.label; desc: modelData.chip + (modelData.rpm === 0 ? "  ·  stopped" : "")
                    Meter { width: 140; height: 6; notches: 18; value: Math.min(1, modelData.rpm / (modelData.max || 5000)); anchors.verticalCenter: parent.verticalCenter }
                    Label { width: 80; horizontalAlignment: Text.AlignRight; mono: true; text: modelData.rpm + " rpm"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Section {
            visible: !!page.s && (page.s.power.length > 0 || !!page.s.battery)
            title: "Power"
            Repeater { model: page.s ? page.s.power : []
                       KV { required property var modelData; icon: "bolt"; title: modelData.chip; value: modelData.w + " W" } }
            KV { visible: !!page.s && !!page.s.battery; icon: "battery_charging_full"; title: "Battery"
                 desc: page.s && page.s.battery ? page.s.battery.status + "  ·  " + page.s.battery.pct + "%" : ""
                 value: page.s && page.s.battery && page.s.battery.w ? page.s.battery.w + " W" : "" }
        }
    }

    // ======================================================== Network
    Column {
        visible: page.tab === 6
        width: parent.width; spacing: 14
        Graph { width: parent.width; label: "All interfaces  ·  down / up"; value: page.bits(page.hist.rx[page.hist.rx.length - 1] || 0); sub: "up " + page.bits(page.hist.tx[page.hist.tx.length - 1] || 0); a: page.hist.rx; b: page.hist.tx }
        Section {
            title: "Interfaces"
            Repeater {
                model: page.s ? page.realNets(page.s.net) : []
                KV {
                    required property var modelData
                    readonly property var nic: page.hw ? page.hw.nics.find(n => n.dev === modelData.dev) : null
                    icon: nic && nic.wireless ? "wifi" : /^(tun|wg)/.test(modelData.dev) ? "vpn_lock" : "lan"; dim: !modelData.up
                    title: modelData.dev + (nic && nic.speed ? "  ·  " + (nic.speed >= 1000 ? nic.speed / 1000 + " Gbit/s" : nic.speed + " Mbit/s") + " link" : "")
                    desc: "Since boot: " + page.bytes(modelData.rxTotal) + " down, " + page.bytes(modelData.txTotal) + " up"
                    value: modelData.up ? "↓ " + page.bits(modelData.rx) + "   ↑ " + page.bits(modelData.tx) : "down"
                }
            }
        }
        Section {
            title: "Latency"
            SRow {
                icon: "network_ping"; title: "Ping"; desc: page.busy === "ping" ? "Measuring…" : "Ten round trips each to your router, Cloudflare, Google and archlinux.org"
                Run { job: "ping"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.runPings() }
            }
            Repeater {
                model: page.pings
                SRow {
                    required property var modelData
                    icon: modelData.loss >= 100 || modelData.error ? "signal_disconnected" : "timer"
                    title: modelData.label + (modelData.host ? "  ·  " + modelData.host : "")
                    desc: modelData.error ? modelData.error : "min " + page.ms(modelData.min) + "  ·  max " + page.ms(modelData.max) + "  ·  jitter " + page.ms(modelData.jitter) + "  ·  " + modelData.loss + "% lost"
                    Badge { visible: !modelData.error; text: modelData.loss > 0 ? modelData.loss + "% loss" : modelData.avg < 30 ? "fast" : modelData.avg < 80 ? "ok" : "slow"
                            tone: modelData.loss > 0 || modelData.avg >= 80 ? "danger" : "ok"; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: 80; horizontalAlignment: Text.AlignRight; mono: true; text: page.ms(modelData.avg); anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Section {
            title: "DNS"
            note: page.dnsR && page.dnsR.resolver !== null ? "system lookup " + page.ms(page.dnsR.resolver) : ""
            SRow {
                icon: "dns"; title: "Resolver speed"; desc: page.dnsR ? "Using " + (page.dnsR.system.join(", ") || "nothing configured") : "How fast your DNS and the popular public resolvers answer"
                Run { job: "dns"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.test("dns", [page.diag, "dns"], r => page.dnsR = r) }
            }
            Repeater {
                model: page.dnsR ? page.dnsR.servers.slice().sort((a, b) => (a.avg ?? 1e9) - (b.avg ?? 1e9)) : []
                SRow {
                    required property var modelData
                    required property int index
                    icon: "dns"; dim: modelData.avg === null
                    title: modelData.name; desc: modelData.ip + (modelData.failed ? "  ·  " + modelData.failed + " of 4 lookups failed" : "")
                    Badge { visible: index === 0 && modelData.avg !== null; text: "fastest"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: 80; horizontalAlignment: Text.AlignRight; mono: true; text: modelData.avg === null ? "no answer" : page.ms(modelData.avg); anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Section {
            title: "Internet speed"
            SRow {
                icon: "speed"; title: "Speed test"
                desc: page.busy === "speed" ? "Downloading, then uploading…" : page.speedR && page.speedR.down ? "Through " + (page.speedR.colo || "Cloudflare") + (page.speedR.loc ? " (" + page.speedR.loc + ")" : "") : "Downloads 25 MB and uploads 10 MB to speed.cloudflare.com"
                Run { job: "speed"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.test("speed", [page.diag, "speed", "25"], r => page.speedR = r) }
            }
            Item {
                visible: !!page.speedR && !!page.speedR.down
                property bool topDivider: false
                width: parent.width; height: 104
                Rectangle { visible: parent.topDivider; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
                Row {
                    x: Ax.pad; y: 14; spacing: 14; width: parent.width - 2 * Ax.pad
                    StatTile { width: (parent.width - 42) / 4; caption: "Download"; value: page.speedR ? page.speedR.down : ""; unit: "Mbit/s" }
                    StatTile { width: (parent.width - 42) / 4; caption: "Upload"; value: page.speedR && page.speedR.up ? page.speedR.up : "—"; unit: "Mbit/s" }
                    StatTile { width: (parent.width - 42) / 4; caption: "Latency"; value: page.speedR ? Math.round(page.speedR.latency) : ""; unit: "ms" }
                    StatTile { width: (parent.width - 42) / 4; caption: "Public address"; value: page.speedR && page.speedR.ip ? (page.speedR.ip.length > 15 ? "IPv6" : page.speedR.ip) : "—"; unit: "" }
                }
            }
        }
    }

    // ======================================================== Hardware
    Column {
        visible: page.tab === 7
        width: parent.width; spacing: 14
        Section {
            visible: page.hw === null
            EmptyState { icon: "hourglass_empty"; title: "Reading the hardware…"; desc: "" }
        }
        Section {
            visible: page.hw !== null
            title: "System"
            KV { icon: "computer"; title: "Model"; value: page.hw ? [page.hw.system.vendor, page.hw.system.product, page.hw.system.version].filter(x => x && !/To Be Filled|Default string|System (Product|Version)/i.test(x)).join(" ") || "—" : "" }
            KV { icon: "developer_board"; title: "Motherboard"; value: page.hw ? page.hw.system.board || "—" : "" }
            KV { icon: "settings_applications"; title: "Firmware"; value: page.hw ? [page.hw.system.firmware, page.hw.system.bios + (page.hw.system.biosDate ? " (" + page.hw.system.biosDate + ")" : "")].filter(x => x).join("  ·  ") : "" }
            KV { icon: "deployed_code"; title: "Operating system"; value: page.hw ? page.hw.system.os + "  ·  Linux " + page.hw.system.kernel : "" }
            KV { visible: !!page.hw && page.hw.system.virt !== "" && page.hw.system.virt !== "none"; icon: "cloud"; title: "Running inside"; value: page.hw ? page.hw.system.virt : "" }
        }
        Section {
            visible: page.hw !== null
            title: "Processor & memory"
            KV { icon: "memory"; title: page.hw ? page.hw.cpu.model : ""; value: page.hw ? page.hw.cpu.threads + " threads" : "" }
            KV { icon: "memory_alt"; title: "Memory"; value: page.hw ? page.gib(page.hw.memory.total) + " GB" + (page.hw.memory.swap ? "  ·  swap " + page.bytes(page.hw.memory.swap) : "") : "" }
        }
        Section {
            visible: page.hw !== null && page.hw.gpus.length > 0
            title: "Graphics"
            Repeater { model: page.hw ? page.hw.gpus : []
                       KV { required property var modelData; icon: "developer_board"; title: modelData.name; value: modelData.driver } }
            Repeater { model: page.hw ? page.hw.displays : []
                       KV { required property var modelData; icon: "desktop_windows"; title: "Display " + modelData.name; value: "connected" } }
        }
        Section {
            visible: page.hw !== null
            title: "Storage"
            Repeater { model: page.hw ? page.hw.disks : []
                       KV { required property var modelData; icon: "hard_drive"; title: modelData.model || modelData.name
                            desc: modelData.path + (modelData.serial ? "  ·  " + modelData.serial : ""); value: page.bytes(modelData.size) + (modelData.tran ? "  ·  " + modelData.tran.toUpperCase() : "") } }
        }
        Section {
            visible: page.hw !== null && page.hw.nics.length > 0
            title: "Network adapters"
            Repeater { model: page.hw ? page.hw.nics : []
                       KV { required property var modelData; icon: modelData.wireless ? "wifi" : "lan"; title: modelData.dev; desc: modelData.mac + "  ·  MTU " + modelData.mtu; value: modelData.driver } }
        }
        Section {
            visible: page.hw !== null && (page.hw.usb.length > 0 || page.hw.audio.length > 0)
            title: "Devices"
            Repeater { model: page.hw ? page.hw.audio : []
                       KV { required property string modelData; icon: "speaker"; title: modelData; value: "audio" } }
            Repeater { model: page.hw ? page.hw.usb : []
                       KV { required property var modelData; icon: "usb"; title: modelData.name; value: modelData.id } }
        }
        Section {
            visible: page.hw !== null && page.hw.batteries.length > 0
            title: "Battery"
            Repeater { model: page.hw ? page.hw.batteries : []
                       KV { required property var modelData; icon: "battery_full"; title: [modelData.maker, modelData.model].filter(x => x).join(" ") || modelData.name
                            desc: modelData.tech + (modelData.cycles ? "  ·  " + modelData.cycles + " cycles" : "")
                            value: modelData.health !== null ? modelData.health + "% of design capacity" : "" } }
        }
    }

    function report() {
        const h = page.hw; if (!h) return "";
        const L = ["ArchangelOS hardware report", ""];
        L.push("System:   " + [h.system.vendor, h.system.product].join(" ").trim(), "Board:    " + h.system.board, "Firmware: " + h.system.firmware + " " + h.system.bios + " " + h.system.biosDate,
               "OS:       " + h.system.os + " · Linux " + h.system.kernel, "CPU:      " + h.cpu.model + " (" + h.cpu.threads + " threads)",
               "Memory:   " + page.gib(h.memory.total) + " GB");
        for (const g of h.gpus) L.push("GPU:      " + g.name + " [" + g.driver + "]");
        for (const d of h.disks) L.push("Disk:     " + (d.model || d.name) + " " + page.bytes(d.size) + " " + (d.tran || ""));
        for (const n of h.nics) L.push("Network:  " + n.dev + " [" + n.driver + "]");
        for (const r of page.smartList) L.push("Health:   " + r.dev + " " + (page.smartBad(r) ? "NEEDS ATTENTION" : "ok") + (r.wear !== null ? " · " + r.wear + "% worn" : ""));
        return L.join("\n");
    }
}

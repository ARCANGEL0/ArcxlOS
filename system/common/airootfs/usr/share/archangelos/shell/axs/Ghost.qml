// GhostWired state, shared by its three pages: polls /usr/lib/archangelos/ghostwired while
// Settings is open and runs its commands.
pragma Singleton

import QtQuick
import Quickshell
import qs.axs.ui
import qs.ns.services as NSS

Singleton {
    id: root
    readonly property string tool: "/usr/lib/archangelos/ghostwired"
    property var st: ({})
    property bool loaded: false
    property string busy: ""          // which action is in flight
    property string error: ""
    property var exit: null           // { IP, IsTor }
    property bool macRandom: false

    readonly property bool installed: st.installed === "1" && st.nft === "1"
    readonly property bool running: st.active === "active" || st.active === "activating" || st.active === "reloading"
    readonly property int boot: parseInt(st.bootstrap || "0")
    readonly property bool ready: st.active === "active" && boot >= 100
    readonly property bool blocked: st.blocked === "1" && !running
    readonly property string phase: !loaded ? "Checking…"
        : blocked ? "Tor stopped — every packet is held back until you turn the tunnel off"
        : !running ? (st.armed === "1" ? "Lifting the rules…" : "Off — this computer connects directly")
        : ready ? "Every packet leaves through Tor. Anything else is rejected"
        : "Building circuits " + boot + "%" + (st.phase ? " · " + st.phase : "")

    Cmd { id: cmd }
    Cmd { id: poller }
    function parse(text) {
        const o = {};
        for (const line of text.split("\n")) { const i = line.indexOf("="); if (i > 0) o[line.slice(0, i)] = line.slice(i + 1); }
        return o;
    }
    function refresh() {
        if (poller.busy) return;
        poller.run([root.tool, "status"], (code, out) => { root.st = root.parse(out); root.loaded = true; });
        poller.sh('[ -f /etc/NetworkManager/conf.d/90-archangelos-mac.conf ] && echo 1 || echo 0', [], (c, o) => root.macRandom = o.trim() === "1");
    }
    Timer {
        interval: root.running && !root.ready ? 1200 : 4000
        running: NSS.Shell.settingsVisible; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onReadyChanged: { root.exit = null; if (ready) root.checkExit(); }

    function fail(code, out, err) {
        if (code === 126 || code === 127) return "Cancelled.";
        return (err || out).trim().replace(/^ghostwired: /, "") || "That didn't work.";
    }
    function act(name, args, input, done) {
        root.busy = name; root.error = "";
        cmd.run([root.tool].concat(args), (code, out, err) => {
            root.busy = "";
            if (code !== 0) root.error = root.fail(code, out, err);
            root.refresh();
            if (done) done(code === 0);
        }, input);
    }
    function setOpt(kv) { root.act("set", ["set"].concat(kv)); }
    function checkExit() {
        root.busy = "exit";
        cmd.run([root.tool, "exitip"], (code, out) => {
            root.busy = "";
            try { root.exit = JSON.parse(out); } catch (e) { root.exit = null; }
        });
    }
    function newIdentity() {
        root.busy = "newnym";
        cmd.run([root.tool, "newnym"], (c, o, e) => {
            root.busy = "";
            if (c !== 0) root.error = root.fail(c, o, e);
            else { root.exit = null; exitLater.restart(); }
        });
    }
    Timer { id: exitLater; interval: 2500; onTriggered: root.checkExit() }
    function setMac(on) {
        root.busy = "mac";
        cmd.run(["/usr/lib/archangelos/axs-admin", "mac-random", on ? "1" : "0"], (c, o, e) => {
            root.busy = ""; if (c !== 0) root.error = root.fail(c, o, e); root.refresh();
        });
    }
}

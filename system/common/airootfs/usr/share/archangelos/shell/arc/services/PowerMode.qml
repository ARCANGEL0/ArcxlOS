pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: pm

    property string mode: ""
    property string pending: ""
    property string error: ""
    property bool nativePerf: true
    readonly property var modes: ["saver", "balanced", "performance"]

    readonly property string script: 'h=/usr/lib/archangelos/power-mode
if [ -x "$h" ]; then exec "$h" "$@"; fi
command -v powerprofilesctl >/dev/null 2>&1 || exit 127
case "$1" in
    get)
        m=$(powerprofilesctl get) || exit 1
        [ "$m" = power-saver ] && m=saver
        echo "mode=$m"
        echo "native_perf=$(powerprofilesctl list 2>/dev/null | grep -q "performance:" && echo 1 || echo 0)" ;;
    set)
        m=$2
        [ "$m" = saver ] && m=power-saver
        powerprofilesctl set "$m" && echo ok ;;
esac'

    property var job: null
    property var queue: []

    function refresh() {
        if (pm.queue.some(j => j.read)) return;
        pm.push({ args: ["get"], read: true });
    }

    function apply(id) {
        if (pm.pending !== "" || id === pm.mode || pm.modes.indexOf(id) < 0) return;
        pm.pending = id;
        pm.error = "";
        pm.push({ args: ["set", id], read: false });
        pm.push({ args: ["get"], read: true });
    }

    function push(j) {
        pm.queue = pm.queue.concat([j]);
        if (!pm.job) pm.next();
    }

    function next() {
        if (pm.queue.length === 0) return;
        pm.job = pm.queue[0];
        pm.queue = pm.queue.slice(1);
        proc.left = 3;
        proc.command = ["sh", "-c", pm.script, "power-mode"].concat(pm.job.args);
        proc.running = true;
    }

    function finish(code, out, err) {
        const j = pm.job;
        pm.job = null;
        const last = err.split("\n").map(l => l.trim()).filter(l => l !== "").pop() || "";
        if (code === 127) {
            pm.error = "No power backend installed";
        } else if (j.read) {
            const vals = {};
            for (const l of out.split("\n")) {
                const i = l.indexOf("=");
                if (i > 0) vals[l.slice(0, i)] = l.slice(i + 1).trim();
            }
            if (code === 0 && pm.modes.indexOf(vals.mode) >= 0) {
                pm.mode = vals.mode;
                pm.nativePerf = vals.native_perf !== "0";
            } else if (pm.error === "") {
                pm.error = "Couldn't read the power mode" + (last ? ": " + last : "");
            }
        } else if (code !== 0) {
            pm.error = "Couldn't switch power mode" + (last ? ": " + last : "");
        }
        if (!j.read) pm.pending = "";
        pm.next();
    }

    Process {
        id: proc
        property int code: 0
        property int left: 0
        onExited: (c) => { code = c; guard.restart(); proc.done(); }
        stdout: StdioCollector { id: out; onStreamFinished: proc.done() }
        stderr: StdioCollector { id: err; onStreamFinished: proc.done() }
        function done() {
            if (--left > 0) return;
            guard.stop();
            pm.finish(code, out.text, err.text);
        }
    }

    Timer {
        id: guard
        interval: 1500
        onTriggered: if (pm.job) { proc.left = 1; proc.done(); }
    }

    Component.onCompleted: refresh()
}

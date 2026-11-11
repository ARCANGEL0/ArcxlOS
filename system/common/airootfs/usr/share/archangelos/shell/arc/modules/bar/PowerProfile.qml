import QtQuick
import Quickshell.Io

QtObject {
    id: pp

    property string cli: "powerprofilesctl"
    property string profile: ""
    property string pending: ""
    property string error: ""
    readonly property bool busy: pp._job !== null

    readonly property var _known: ["performance", "balanced", "power-saver"]
    property var _job: null
    property var _queue: []
    property int _left: 0
    property int _code: 0

    function refresh() {
        if (pp._queue.some(j => j.read)) return;
        pp._push({ args: ["get"], read: true });
    }

    function apply(id) {
        if (pp.pending !== "" || id === pp.profile || pp._known.indexOf(id) < 0) return;
        pp.pending = id;
        pp.error = "";
        pp._push({ args: ["set", id], read: false });
        pp._push({ args: ["get"], read: true });
    }

    function _push(job) {
        pp._queue = pp._queue.concat([job]);
        if (!pp._job) pp._next();
    }

    function _next() {
        if (pp._queue.length === 0) return;
        pp._job = pp._queue[0];
        pp._queue = pp._queue.slice(1);
        pp._left = 3;
        pp._proc.command = ["sh", "-c", 'exec "$0" "$@"', pp.cli].concat(pp._job.args);
        pp._proc.running = true;
    }

    function _lastLine(text) {
        const lines = text.split("\n").map(l => l.trim()).filter(l => l !== "");
        return lines.length ? lines[lines.length - 1] : "";
    }

    function _finish() {
        if (--pp._left > 0) return;
        pp._guard.stop();
        const job = pp._job, code = pp._code;
        const out = pp._out.text.trim(), err = pp._lastLine(pp._err.text);
        pp._job = null;
        if (code === 127) {
            pp.error = "power-profiles-daemon is not installed";
        } else if (job.read) {
            if (code === 0 && pp._known.indexOf(out) >= 0) pp.profile = out;
            else if (pp.error === "") pp.error = "Couldn't read the power mode" + (err ? ": " + err : "");
        } else if (code !== 0) {
            pp.error = "Couldn't switch power mode" + (err ? ": " + err : "");
        }
        if (!job.read) pp.pending = "";
        pp._next();
    }

    property Process _proc: Process {
        onExited: code => { pp._code = code; pp._guard.restart(); pp._finish(); }
        stdout: StdioCollector { onStreamFinished: pp._finish() }
        stderr: StdioCollector { onStreamFinished: pp._finish() }
    }
    readonly property StdioCollector _out: pp._proc.stdout
    readonly property StdioCollector _err: pp._proc.stderr

    property Timer _guard: Timer {
        interval: 1500
        onTriggered: if (pp._job) { pp._left = 1; pp._finish(); }
    }
}

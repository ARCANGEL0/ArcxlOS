// Runs commands one at a time: run(argv, cb, stdin) → cb(code, stdout, stderr). Later calls queue.
import QtQuick
import Quickshell.Io

Item {
    id: c
    visible: false
    property var _q: []
    property var _job: null
    property int _left: 0
    property int _code: 0
    readonly property bool busy: _job !== null

    function run(argv, cb, input) {
        c._q = c._q.concat([{ argv: argv, cb: cb, input: input }]);
        if (!c._job) c._next();
    }
    // Shell snippet with positional arguments: sh("echo $1", ["x"], cb).
    function sh(script, args, cb, input) { c.run(["sh", "-c", script, "sh"].concat(args || []), cb, input); }

    function _next() {
        if (c._q.length === 0) return;
        c._job = c._q[0];
        c._q = c._q.slice(1);
        c._left = 3;
        proc.stdinEnabled = c._job.input !== undefined;
        proc.command = c._job.argv;
        proc.running = true;
    }
    function _done() {
        if (--c._left > 0) return;
        guard.stop();
        const j = c._job, code = c._code, o = out.text, e = err.text;
        c._job = null;
        if (j && j.cb) j.cb(code, o, e);
        c._next();
    }
    Process {
        id: proc
        onStarted: {
            if (c._job && c._job.input !== undefined) { write(c._job.input); stdinEnabled = false; }
        }
        onExited: (code) => { c._code = code; guard.restart(); c._done(); }
        stdout: StdioCollector { id: out; onStreamFinished: c._done() }
        stderr: StdioCollector { id: err; onStreamFinished: c._done() }
    }
    // If a stream never reports its end, don't wedge the queue.
    Timer { id: guard; interval: 1500; onTriggered: if (c._job) { c._left = 1; c._done(); } }
}

import QtQuick
import Quickshell
import Quickshell.Io
import "." as Bar

ShellRoot {
    id: root
    readonly property string dir: Quickshell.env("FAKE_PPCTL_DIR")
    property var steps: []
    property int failures: 0

    Bar.PowerProfile {
        id: pp
        cli: Quickshell.env("FAKE_PPCTL")
    }

    Process { id: sh }

    function check(name, ok, detail) {
        console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  — " + detail));
        if (!ok) root.failures++;
    }

    function shell(script, then) {
        sh.command = ["sh", "-c", script, "sh", root.dir];
        sh.exited.connect(function once() { sh.exited.disconnect(once); then(); });
        sh.running = true;
    }

    function waitIdle(then) {
        if (!pp.busy) then();
        else Qt.callLater(() => waitTimer.later(then));
    }

    Timer {
        id: waitTimer
        property var fn: null
        interval: 20
        function later(f) { fn = f; start(); }
        onTriggered: root.waitIdle(fn)
    }

    function run(i) {
        if (i >= root.steps.length) {
            console.log(root.failures === 0 ? "ALL PASSED" : root.failures + " FAILED");
            Qt.exit(root.failures === 0 ? 0 : 1);
            return;
        }
        root.steps[i](() => root.run(i + 1));
    }

    Component.onCompleted: {
        root.steps = [
            next => { pp.refresh(); root.waitIdle(() => {
                root.check("reads the applied profile on refresh", pp.profile === "balanced", "got " + pp.profile);
                next(); }); },
            next => { pp.apply("performance"); root.waitIdle(() => {
                root.check("successful switch selects the new profile", pp.profile === "performance", "got " + pp.profile);
                root.check("successful switch shows no error", pp.error === "", "got " + pp.error);
                next(); }); },
            next => root.shell("echo power-saver > \"$1/reject\"", next),
            next => { pp.apply("power-saver"); root.waitIdle(() => {
                root.check("rejected switch keeps the real profile selected", pp.profile === "performance", "got " + pp.profile);
                root.check("rejected switch reports the failure", pp.error !== "", "error was empty");
                next(); }); },
            next => root.shell("echo balanced > \"$1/profile\"", next),
            next => { pp.refresh(); root.waitIdle(() => {
                root.check("picks up a change made outside the popup", pp.profile === "balanced", "got " + pp.profile);
                next(); }); },
            next => { pp.cli = root.dir + "/missing-binary"; pp.refresh(); root.waitIdle(() => {
                root.check("missing tool reports an error", pp.error !== "", "error was empty");
                next(); }); }
        ];
        root.run(0);
    }

    Timer { interval: 15000; running: true; onTriggered: { console.log("FAIL timed out"); Qt.exit(1); } }
}

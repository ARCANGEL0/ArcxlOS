pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.arc

Singleton {
    id: root

    property int failedUnits: 0
    property var failedNames: []
    readonly property bool diskHigh: Sys.disk >= 0.9
    readonly property bool hotCpu: Sys.temp >= 90
    readonly property var healthIssues: {
        const list = [];
        if (root.failedUnits > 0) list.push(root.failedUnits + " failed service" + (root.failedUnits > 1 ? "s" : "") + ": " + root.failedNames.slice(0, 3).join(", "));
        if (root.diskHigh) list.push("Disk " + Math.round(Sys.disk * 100) + "% full");
        if (root.hotCpu) list.push("CPU at " + Sys.temp + "°C");
        return list;
    }
    readonly property string healthLevel: root.hotCpu || Sys.disk >= 0.97 ? "bad" : (root.healthIssues.length > 0 ? "warn" : "ok")

    property int repoUpdates: -1
    property int aurUpdates: 0
    readonly property int totalUpdates: Math.max(0, root.repoUpdates) + root.aurUpdates

    property bool micInUse: false
    property bool camInUse: false
    property bool screenShared: false
    property bool micMuted: false
    readonly property bool privacyActive: root.micInUse || root.camInUse || root.screenShared

    property int pingMs: -1

    property var drives: []

    property int dockerRunning: 0
    property int realDockerRunning: 0
    property var realDrives: []
    property bool realMicInUse: false

    property bool demo: false
    onDemoChanged: {
        root.drives = root.demo ? root.realDrives.concat([root.demoDrive]) : root.realDrives
        root.dockerRunning = root.demo ? 3 : root.realDockerRunning
        root.micInUse = root.demo ? true : root.realMicInUse
    }
    readonly property var demoDrive: ({ dev: "", parent: "", label: "SANDISK 64G", mount: "/run/media/demo", free: 41800000000, size: 61500000000, demo: true })
    readonly property var btBattery: {
        const real = Bt.devices.filter(d => d.connected && d.batteryAvailable)
            .map(d => ({ name: d.name, battery: d.battery, icon: d.icon ?? "" }));
        return root.demo ? real.concat([{ name: "WH-1000XM5 (demo)", battery: 0.64, icon: "audio-headphones" }, { name: "DualSense (demo)", battery: 0.15, icon: "input-gaming" }]) : real;
    }

    IpcHandler {
        target: "dock-demo"
        function toggle(): void { root.demo = !root.demo }
        function on(): void { root.demo = true }
        function off(): void { root.demo = false }
    }

    function shortCount(n) { return n >= 1000 ? (n / 1000).toFixed(1).replace(".0", "") + "k" : String(n); }

    Process {
        id: healthProc
        command: ["sh", "-c", "{ systemctl --failed --no-legend --plain 2>/dev/null; systemctl --user --failed --no-legend --plain 2>/dev/null; } | awk '{print $1}' | grep -v '^$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(l => l.trim() !== "");
                root.failedNames = names;
                root.failedUnits = names.length;
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: healthProc.running = true }

    Process {
        id: updatesProc
        command: ["sh", "-c", "out=$(checkupdates 2>/dev/null); s=$?; if [ $s -eq 0 ]; then r=$(printf '%s\\n' \"$out\" | wc -l); elif [ $s -eq 2 ]; then r=0; else r=-1; fi; a=$( (paru -Qua 2>/dev/null || yay -Qua 2>/dev/null) | wc -l); echo \"$r $a\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length !== 2 || !p.every(n => Number.isFinite(n))) return;
                if (p[0] >= 0) root.repoUpdates = p[0];
                root.aurUpdates = p[1];
            }
        }
    }
    Timer { id: updatesDelay; interval: 10000; running: true; onTriggered: updatesProc.running = true }
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: updatesProc.running = true }
    function refreshUpdates() { if (!updatesProc.running) updatesProc.running = true; }

    Process {
        id: privacyProc
        command: ["sh", "-c",
            "mic=$(pactl -f json list source-outputs 2>/dev/null | jq '[.[] | select((((.properties[\"application.process.binary\"] // \"\") + \" \" + (.properties[\"application.name\"] // \"\") + \" \" + (.properties[\"media.name\"] // \"\")) | test(\"cava|quickshell|peak detect\"; \"i\") | not))] | length' 2>/dev/null); "
            + "cam=$(fuser /dev/video* 2>/dev/null | wc -w); "
            + "scr=$(pw-cli ls Node 2>/dev/null | grep -c 'xdph'); "
            + "mute=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -c yes); "
            + "echo \"${mic:-0} ${cam:-0} ${scr:-0} ${mute:-0}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length !== 4) return;
                root.realMicInUse = p[0] > 0;
                root.micInUse = root.demo || root.realMicInUse;
                root.camInUse = p[1] > 0;
                root.screenShared = p[2] > 0;
                root.micMuted = p[3] > 0;
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!privacyProc.running) privacyProc.running = true }

    Process {
        id: pingProc
        command: ["sh", "-c", "ping -c1 -W2 1.1.1.1 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.trim());
                root.pingMs = Number.isFinite(v) ? Math.round(v) : -1;
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!pingProc.running) pingProc.running = true }

    Process {
        id: drivesProc
        command: ["sh", "-c", "lsblk -J -b -o NAME,PKNAME,LABEL,MOUNTPOINT,RM,HOTPLUG,SIZE,FSAVAIL,TRAN 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = [];
                try {
                    const walk = (devs, parentRemovable, parent) => {
                        for (const d of devs ?? []) {
                            const removable = parentRemovable || d.rm === true || d.hotplug === true || d.rm === "1" || d.hotplug === "1";
                            if (removable && d.mountpoint && !d.mountpoint.startsWith("/boot") && d.mountpoint !== "/")
                                out.push({ dev: "/dev/" + d.name, parent: "/dev/" + (d.pkname || parent || d.name),
                                           label: d.label || d.name, mount: d.mountpoint,
                                           free: Number(d.fsavail) || 0, size: Number(d.size) || 0 });
                            walk(d.children, removable, d.name);
                        }
                    };
                    walk(JSON.parse(text).blockdevices, false, "");
                } catch (e) {}
                root.realDrives = out;
                root.drives = root.demo ? out.concat([root.demoDrive]) : out;
            }
        }
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!drivesProc.running) drivesProc.running = true }

    function open(drive) {
        if (drive.demo) { Quickshell.execDetached(["notify-send", "-a", "Drives", drive.label, "Would open " + drive.mount + " (demo)"]); return; }
        Quickshell.execDetached(["xdg-open", drive.mount]);
    }

    function eject(drive) {
        if (drive.demo) { root.demo = false; Quickshell.execDetached(["notify-send", "-a", "Drives", drive.label, "Safe to remove (demo)"]); return; }
        Quickshell.execDetached(["sh", "-c", "udisksctl unmount -b \"$1\" && udisksctl power-off -b \"$2\"; notify-send -a Drives \"$3\" \"Safe to remove\"", "sh", drive.dev, drive.parent, drive.label]);
        ejectRefresh.restart();
    }
    Timer { id: ejectRefresh; interval: 1500; onTriggered: drivesProc.running = true }

    function fmtBytes(b) {
        if (b >= 1e12) return (b / 1e12).toFixed(1) + " TB";
        if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB";
        return Math.round(b / 1e6) + " MB";
    }

    Process {
        id: dockerProc
        command: ["sh", "-c", "docker ps -q 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.realDockerRunning = parseInt(text.trim()) || 0;
                root.dockerRunning = root.demo ? 3 : root.realDockerRunning;
            }
        }
    }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!dockerProc.running) dockerProc.running = true }
}

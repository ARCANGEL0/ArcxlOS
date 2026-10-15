pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory load in percent, sampled from /proc every two seconds.
Singleton {
    id: stats

    property int cpu: 0
    property int mem: 0
    property var _prev: null

    Process {
        id: sample
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: stats._parse(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sample.running = true
    }

    function _parse(out) {
        const lines = out.trim().split("\n")
        const f = lines[0].split(/\s+/).slice(1).map(Number)
        const idle = f[3] + (f[4] || 0)
        const total = f.reduce((a, b) => a + b, 0)
        if (_prev && total > _prev.total)
            cpu = Math.round(100 * (1 - (idle - _prev.idle) / (total - _prev.total)))
        _prev = { idle: idle, total: total }

        let memTotal = 0, memAvail = 0
        for (const l of lines.slice(1)) {
            const kb = parseInt(l.split(/\s+/)[1])
            if (l.startsWith("MemTotal")) memTotal = kb
            else memAvail = kb
        }
        if (memTotal > 0)
            mem = Math.round(100 * (1 - memAvail / memTotal))
    }
}

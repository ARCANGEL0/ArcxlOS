// ArchangelOS: system pane — CPU / RAM / GPU, a live history chart, and the top
// processes with a kill button. Grows out of the left dock's monitors.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.arc
import qs.arc.components
import qs.arc.services

BarPopout {
    id: pop
    name: "sys"
    implicitWidth: 280
    bodyHeight: 388 + ((Sys.hasGpu || Sys.hasBattery) ? 74 : 0)
    reportOnHover: true

    onOpened: { Sys.active = true; psTimer.start(); psProc.running = true }
    onDismissed: psTimer.stop()

    Timer { id: psTimer; interval: 3000; repeat: true; onTriggered: if (!psProc.running) psProc.running = true }

    // top processes by CPU → model rows {pid, name, cpu}
    property var procs: []
    Process {
        id: psProc
        command: ["sh", "-c", "ps -eo pid,comm,pcpu,pmem --sort=-pcpu | sed 1d | head -6"]
        stdout: StdioCollector {
            id: psOut
            onStreamFinished: {
                const rows = [];
                for (const line of psOut.text.trim().split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(\S+)\s+([\d.]+)\s+([\d.]+)/);
                    if (m) rows.push({ pid: m[1], name: m[2], cpu: m[3], mem: m[4] });
                }
                pop.procs = rows;
            }
        }
    }

    component Gauge: ColumnLayout {
        id: g
        property string label
        property real value: 0
        property string sub
        property color tint: Config.accent
        spacing: 3
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 52; implicitHeight: 52
            Canvas {
                id: ring
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2, r = 22;
                    ctx.lineWidth = 5; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.strokeStyle = Config.surface; ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0, Math.min(1, g.value)));
                    ctx.strokeStyle = g.tint; ctx.stroke();
                }
                Component.onCompleted: requestPaint()
                Connections { target: g; function onValueChanged() { ring.requestPaint() } }
            }
            Text {
                anchors.centerIn: parent
                text: Math.round(g.value * 100)
                color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; font.bold: true
            }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: g.label; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.bold: true }
        Text { Layout.alignment: Qt.AlignHCenter; text: g.sub; color: Config.dim; font.family: Config.textFont; font.pixelSize: 8 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 14 + Config.popFillet * 2 - pop.botPad + pop.topPad
        anchors.bottomMargin: 14 + pop.botPad
        spacing: 10

        Text { text: "SYSTEM"; color: Config.accent; font.family: Config.textFont; font.pixelSize: 11; font.bold: true; Layout.bottomMargin: 2 }

        // CPU / RAM / GPU / Disk / Battery — GPU and Battery appear only when present
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Gauge { width: (parent.width - 8) / 3; label: "CPU"; value: Sys.cpu; tint: Config.accent
                    sub: Sys.cores > 0 ? (Sys.load.toFixed(1) + "/" + Sys.cores) : (Sys.temp + "°") }
            Gauge { width: (parent.width - 8) / 3; label: "RAM"; value: Sys.mem; tint: Config.tertiary
                    sub: Sys.memUsedGb.toFixed(1) + "/" + Math.round(Sys.memTotalGb) + "G" }
            Gauge { width: (parent.width - 8) / 3; label: "GPU"; value: Sys.gpu; tint: Config.accent
                    sub: Sys.gpuTemp + "°"; visible: Sys.hasGpu }
            Gauge { width: (parent.width - 8) / 3; label: "DISK"; value: Sys.disk; tint: Config.tertiary
                    sub: Math.round(Sys.diskUsedGb) + "/" + Math.round(Sys.diskTotalGb) + "G" }
            Gauge { width: (parent.width - 8) / 3; label: "BATT"; value: Sys.batteryPct / 100
                    tint: Sys.batteryPct <= 20 ? Config.tertiary : Config.accent
                    sub: Sys.batteryCharging ? "chg" : (Sys.batteryPct + "%"); visible: Sys.hasBattery }
        }

        // --- live history chart (CPU filled, RAM line) ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 54
            radius: 8
            color: Config.surface
            Canvas {
                id: chart
                anchors.fill: parent
                anchors.margins: 6
                function plot(ctx, hist, w, h) {
                    if (!hist || hist.length < 2) return;
                    const n = hist.length, step = w / (n - 1);
                    ctx.beginPath();
                    for (let i = 0; i < n; i++) ctx.lineTo(i * step, h - hist[i] * h);
                    return;
                }
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    const w = width, h = height;
                    const cpu = Sys.cpuHist, mem = Sys.memHist;
                    if (cpu && cpu.length > 1) {
                        const n = cpu.length, step = w / (n - 1);
                        ctx.beginPath(); ctx.moveTo(0, h);
                        for (let i = 0; i < n; i++) ctx.lineTo(i * step, h - cpu[i] * h);
                        ctx.lineTo(w, h); ctx.closePath();
                        ctx.fillStyle = Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22);
                        ctx.fill();
                        ctx.beginPath();
                        for (let i = 0; i < n; i++) ctx.lineTo(i * step, h - cpu[i] * h);
                        ctx.strokeStyle = Config.accent; ctx.lineWidth = 1.5; ctx.stroke();
                    }
                    if (mem && mem.length > 1) {
                        const n = mem.length, step = w / (n - 1);
                        ctx.beginPath();
                        for (let i = 0; i < n; i++) ctx.lineTo(i * step, h - mem[i] * h);
                        ctx.strokeStyle = Config.dim; ctx.lineWidth = 1; ctx.stroke();
                    }
                }
                Connections { target: Sys; function onCpuHistChanged() { chart.requestPaint() } }
                Component.onCompleted: requestPaint()
            }
        }

        Text { text: "TOP PROCESSES"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.bold: true }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3
            Repeater {
                model: pop.procs
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 6
                    color: rowHov.hovered ? Config.container : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 4
                        spacing: 6
                        Text { Layout.fillWidth: true; text: row.modelData.name; color: Config.fg; font.family: Config.textFont; font.pixelSize: 10; elide: Text.ElideRight }
                        Text { text: row.modelData.cpu + "%"; color: Config.accent; font.family: Config.textFont; font.pixelSize: 10 }
                        Rectangle {
                            implicitWidth: 18; implicitHeight: 18; radius: 5
                            color: killMa.containsMouse ? Config.accent : "transparent"
                            MatIcon { anchors.centerIn: parent; text: "close"; font.pixelSize: 12
                                      color: killMa.containsMouse ? Config.accentText : Config.dim }
                            MouseArea {
                                id: killMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Quickshell.execDetached(["kill", row.modelData.pid]); psProc.running = true }
                            }
                        }
                    }
                    HoverHandler { id: rowHov }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}

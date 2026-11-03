// Per-meter hover pane: CPU / GPU / system load / temp / top CPU processes with KILL buttons + history graph.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.arc
import qs.arc.components
import qs.arc.services
import "../../../frame/components" as FC

BarPopout {
    id: pop
    name: "cpu"
    implicitWidth: 290
    bodyHeight: bodyCol.implicitHeight + 20

    property var procs: []
    readonly property color cpuTint: Config.severity(Sys.cpu, Config.series[0], 0.75, 0.85)
    readonly property color gpuTint: Config.severity(Sys.gpu, Config.series[2], 0.8, 0.9)

    Timer { id: refreshTimer; interval: 3000; repeat: true; running: false; onTriggered: if (!cpuProc.running) cpuProc.running = true }

    Process {
        id: cpuProc
        command: ["sh", "-c", "ps -eo pid,comm,pcpu --sort=-pcpu | sed 1d | head -8"]
        running: false
        stdout: StdioCollector {
            id: cpuOut
            onStreamFinished: {
                const rows = [];
                for (const line of cpuOut.text.trim().split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(\S+)\s+([\d.]+)/);
                    if (m) rows.push({ pid: m[1], name: m[2], cpu: Number(m[3]) });
                }
                pop.procs = rows;
            }
        }
    }

    onOpened: { refreshTimer.start(); if (!cpuProc.running) cpuProc.running = true }
    onDismissed: refreshTimer.stop()

    ColumnLayout {
        id: bodyCol
        Layout.fillWidth: true
        spacing: 12
        anchors {
            top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 14 + Config.popFillet * 2 - pop.botPad + pop.topPad
            leftMargin: 20; rightMargin: 16; bottomMargin: 16 + pop.botPad
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 30; implicitHeight: 30; radius: 8
                color: Qt.rgba(pop.cpuTint.r, pop.cpuTint.g, pop.cpuTint.b, 0.14)
                MatIcon { anchors.centerIn: parent; text: "speed"; font.pixelSize: 16; color: pop.cpuTint }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: Math.round(Sys.cpu * 100) + "%"; color: pop.cpuTint; font.family: Config.textFont; font.pixelSize: 26; font.weight: Font.Bold }
                Text { text: "CPU usage"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9 }
            }
            ColumnLayout {
                Layout.preferredWidth: 64
                spacing: 1
                Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: Sys.hasGpu ? Math.round(Sys.gpu * 100) + "%" : "—"; color: Sys.hasGpu ? pop.gpuTint : Config.fg; font.family: Config.textFont; font.pixelSize: 16; font.weight: Font.Bold }
                Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: Sys.hasGpu ? "GPU" : "no GPU"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9 }
            }
        }

        SectionRow { label: "System load"; value: Sys.load.toFixed(2) + "  ·  " + Sys.cores + " cores" }
        SectionRow { label: "Temperature"; value: (Sys.temp > 0 ? Sys.temp + "°C" : "—") + (Sys.hasGpu && Sys.gpuTemp > 0 ? "  ·  GPU " + Sys.gpuTemp + "°C" : "") }

        Text { text: "CPU"; color: pop.cpuTint; font.family: Config.textFont; font.pixelSize: 8; font.bold: true; Layout.topMargin: 2 }
        HistChart { Layout.fillWidth: true; implicitHeight: 56; hist: Sys.cpuHist; line: pop.cpuTint }

        Text { visible: Sys.hasGpu; text: "GPU"; color: pop.gpuTint; font.family: Config.textFont; font.pixelSize: 8; font.bold: true; Layout.topMargin: 2 }
        HistChart { visible: Sys.hasGpu; Layout.fillWidth: true; implicitHeight: 40; hist: Sys.gpuHist; line: pop.gpuTint }

        Text { text: "TOP PROCESSES (CPU)"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.bold: true; Layout.topMargin: 4; Layout.bottomMargin: 2 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: pop.procs
                delegate: Item {
                    id: procRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 22
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        Text { Layout.fillWidth: true; text: procRow.modelData.name; color: Config.fg; font.family: Config.textFont; font.pixelSize: 10; elide: Text.ElideRight }
                        Text { text: procRow.modelData.cpu.toFixed(0) + "%"; color: Config.accent; font.family: Config.textFont; font.pixelSize: 10 }
                        Rectangle {
                            implicitWidth: 36; implicitHeight: 18
                            radius: 4
                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12)
                            border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.45)
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "KILL"; color: Config.accent; font.pixelSize: 7; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.color = Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.35)
                                onExited:  parent.color = Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12)
                                onClicked: { Quickshell.execDetached(["kill", "-9", procRow.modelData.pid]); cpuProc.running = true }
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        FC.Tip { text: "CPU details"; suppressed: bar.popout !== "" }
    }
}

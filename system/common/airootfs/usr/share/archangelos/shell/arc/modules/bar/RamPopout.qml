// Per-meter hover pane: RAM usage / total / used / free / available + top RAM processes with KILL buttons + history graph.
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
    name: "ram"
    implicitWidth: 290
    bodyHeight: bodyCol.implicitHeight + 20

    property var procs: []

    Timer { id: refreshTimer; interval: 3000; repeat: true; running: false; onTriggered: if (!ramProc.running) ramProc.running = true }

    Process {
        id: ramProc
        command: ["sh", "-c", "ps -eo pid,comm,pmem --sort=-pmem | sed 1d | head -8"]
        running: false
        stdout: StdioCollector {
            id: ramOut
            onStreamFinished: {
                const rows = [];
                for (const line of ramOut.text.trim().split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(\S+)\s+([\d.]+)/);
                    if (m) rows.push({ pid: m[1], name: m[2], mem: Number(m[3]) });
                }
                pop.procs = rows;
            }
        }
    }

    readonly property real usedGb: Sys.memUsedGb
    readonly property real availGb: Sys.memAvailGb
    readonly property real totalGb: Sys.memTotalGb
    readonly property color ramTint: Config.severity(Sys.mem, Config.series[1], 0.8, 0.9)

    onOpened: { refreshTimer.start(); if (!ramProc.running) ramProc.running = true }
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
                color: Qt.rgba(pop.ramTint.r, pop.ramTint.g, pop.ramTint.b, 0.14)
                MatIcon { anchors.centerIn: parent; text: "memory"; font.pixelSize: 16; color: pop.ramTint }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: Math.round(Sys.mem * 100) + "%"; color: pop.ramTint; font.family: Config.textFont; font.pixelSize: 26; font.weight: Font.Bold }
                Text { text: "RAM usage"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9 }
            }
            ColumnLayout {
                Layout.preferredWidth: 64
                spacing: 1
                Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: totalGb.toFixed(1) + "G"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 16; font.weight: Font.Bold }
                Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: "total"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9 }
            }
        }

        SectionRow { label: "Used"; value: usedGb.toFixed(1) + " GB" }
        SectionRow { label: "Available"; value: availGb.toFixed(1) + " GB" }
        SectionRow { visible: Sys.swapTotalGb > 0; label: "Swap"; value: Sys.swapUsedGb.toFixed(1) + " / " + Sys.swapTotalGb.toFixed(1) + " GB" }

        HistChart { Layout.fillWidth: true; implicitHeight: 56; hist: Sys.memHist; line: pop.ramTint }

        Text { text: "TOP PROCESSES (RAM)"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.bold: true; Layout.topMargin: 4; Layout.bottomMargin: 2 }

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
                        Text { text: procRow.modelData.mem.toFixed(0) + "%"; color: Config.accent; font.family: Config.textFont; font.pixelSize: 10 }
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
                                onClicked: { Quickshell.execDetached(["kill", "-9", procRow.modelData.pid]); ramProc.running = true }
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        FC.Tip { text: "RAM details"; suppressed: bar.popout !== "" }
    }
}

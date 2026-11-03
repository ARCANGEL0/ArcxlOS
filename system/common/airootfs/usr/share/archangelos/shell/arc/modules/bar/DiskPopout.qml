// Per-meter hover pane: disk size, partition, trimmed bytes, heaviest folders/files under home.
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
    name: "disk"
    implicitWidth: 280
    bodyHeight: bodyCol.implicitHeight + 20

    property string partition: ""
    property var heavy: []
    property string fstype: "—"
    property string mount: "—"

    Process {
        id: dfProc
        command: ["sh", "-c", "df -P \"$HOME\" | tail -1"]
        running: false
        stdout: StdioCollector {
            id: dfOut
            onStreamFinished: {
                const f = dfOut.text.trim().split(/\s+/);
                if (f.length >= 6) {
                    pop.partition = f[0];
                    const total = Number(f[1]) / 1048576;
                    const used  = Number(f[2]) / 1048576;
                    pop._diskTotal = total;
                    pop._diskUsed  = used;
                }
            }
        }
    }

    // du -ah lists every file; keep only regular sizes (M/G/T) so the list stays readable.
    Process {
        id: heavyProc
        command: ["sh", "-c", "timeout 180 du -ah \"$HOME\" 2>/dev/null | sort -rh | head -8 | sed \"s|$HOME|~|g\""]
        running: false
        stdout: StdioCollector {
            id: heavyOut
            onStreamFinished: {
                const rows = [];
                for (const line of heavyOut.text.trim().split("\n")) {
                    const m = line.match(/^([\d.]+\w?)\s+(.*)$/);
                    if (m) rows.push({ size: m[1], path: m[2] });
                }
                pop.heavy = rows;
            }
        }
    }

    Process {
        id: fsProc
        command: ["sh", "-c", "findmnt -no FSTYPE,TARGET \"$HOME\" 2>/dev/null || df -P -T \"$HOME\" | tail -1 | awk '{print $2, $7}'"]
        running: false
        stdout: StdioCollector {
            id: fsOut
            onStreamFinished: {
                const f = fsOut.text.trim().split(/\s+/);
                if (f.length >= 1 && f[0] !== "") pop.fstype = f[0];
                if (f.length >= 2) pop.mount = f[1];
            }
        }
    }

    function diskTotalGb() { return pop._diskTotal !== undefined ? pop._diskTotal : Sys.diskTotalGb; }
    function diskUsedGb()  { return pop._diskUsed  !== undefined ? pop._diskUsed  : Sys.diskUsedGb; }

    // A full du over the home tree takes minutes on this machine, so it runs in the
    // background from shell start and refreshes periodically; the pane shows the last scan.
    Timer { id: heavyTimer; interval: 120000; repeat: true; running: true; onTriggered: if (!heavyProc.running) heavyProc.running = true }
    Component.onCompleted: { heavyProc.running = true; if (pop.name === bar.popout) { dfProc.running = true; fsProc.running = true } }
    onOpened: { dfProc.running = true; fsProc.running = true }

    ColumnLayout {
        id: bodyCol
        Layout.fillWidth: true
        spacing: 12
        anchors {
            top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 14 + Config.popFillet * 2 - pop.botPad + pop.topPad
            leftMargin: 20; rightMargin: 16; bottomMargin: 16 + pop.botPad
        }

        Text { text: "STORAGE"; color: Config.tertiary; font.family: Config.textFont; font.pixelSize: 11; font.bold: true; Layout.bottomMargin: 2 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: Math.round(Sys.disk * 100) + "%"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 24; font.bold: true }
                Text { text: "Disk usage"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: diskTotalGb().toFixed(1) + "G"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 24; font.bold: true }
                Text { text: "Total size"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9 }
            }
        }

        SectionRow { label: "Partition"; value: partition !== "" ? partition : "—" }
        SectionRow { label: "Used"; value: diskUsedGb().toFixed(1) + " GB" }
        SectionRow { label: "Free"; value: Math.max(0, diskTotalGb() - diskUsedGb()).toFixed(1) + " GB" }
        SectionRow { label: "Filesystem"; value: fstype }
        SectionRow { label: "Mount point"; value: mount }

        Text { text: "HEAVIEST UNDER HOME"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.bold: true; Layout.topMargin: 4; Layout.bottomMargin: 2 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { visible: pop.heavy.length === 0; text: "scanning home…"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.italic: true }
            Repeater {
                model: pop.heavy
                delegate: Item {
                    id: heavyRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 18
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        Text { text: heavyRow.modelData.size; color: Config.accent; font.family: Config.textFont; font.pixelSize: 9; width: 30 }
                        Text { Layout.fillWidth: true; text: heavyRow.modelData.path; color: Config.fg; font.family: Config.textFont; font.pixelSize: 9; elide: Text.ElideRight }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        FC.Tip { text: "Storage details"; suppressed: bar.popout !== "" }
    }
}

// Audit — Lynis (a full security audit with a hardening score) and rkhunter (looks for rootkits
// and tampered system files), run on demand, results as readable lists.
import QtQuick
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Audit"
    desc: "Have the system checked from top to bottom."

    readonly property string sec: "/usr/lib/archangelos/axs-sec"
    property var lynis: null           // { score, warnings: [], suggestions: [], when }
    property var rk: null              // [lines]
    property string busy: ""
    property string error: ""
    property bool allSugg: false
    Cmd { id: cmd }
    function item(v) { const f = v.split("|"); return { id: f[0], text: f[1] || f[0], detail: f[2] && f[2] !== "-" ? f[2] : "" }; }
    function runLynis() {
        page.busy = "lynis"; page.error = "";
        cmd.run([page.sec, "lynis"], (c, o, e) => {
            page.busy = "";
            if (c !== 0) { page.error = c === 126 ? "Cancelled." : (e || o).trim(); return; }
            const r = { score: 0, warnings: [], suggestions: [], when: "" };
            for (const l of o.split("\n")) {
                const i = l.indexOf("="), k = l.slice(0, i), v = l.slice(i + 1);
                if (k === "hardening_index") r.score = +v;
                else if (k === "warning[]") r.warnings.push(page.item(v));
                else if (k === "suggestion[]") r.suggestions.push(page.item(v));
                else if (k === "report_datetime_end") r.when = v;
            }
            page.lynis = r;
        });
    }
    function runRk() {
        page.busy = "rk"; page.error = "";
        cmd.run([page.sec, "rkhunter"], (c, o, e) => {
            page.busy = "";
            if (c !== 0) { page.error = c === 126 ? "Cancelled." : (e || o).trim(); return; }
            page.rk = o.split("\n").filter(l => l && l !== "--done");
        });
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    // Lynis
    Rectangle {
        width: parent.width; height: 150
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Column {
            x: 28; anchors.verticalCenter: parent.verticalCenter; spacing: 6
            Label { caption: true; text: "Lynis  ·  security audit" }
            Row {
                spacing: 8
                Label { id: sc; mono: true; font.pixelSize: 44; text: page.lynis ? page.lynis.score : "—" }
                Label { anchors.baseline: sc.baseline; color: Ax.subtext; text: page.lynis ? "/ 100 hardening index" : "not run yet" }
            }
            Label { color: Ax.subtext; font.pixelSize: Ax.fsSmall
                    text: page.busy === "lynis" ? "Auditing… this takes a minute or two" : page.lynis ? page.lynis.warnings.length + " warnings, " + page.lynis.suggestions.length + " suggestions" + (page.lynis.when ? "  ·  " + page.lynis.when : "") : "Checks hundreds of settings: boot, kernel, accounts, services, network, files" }
        }
        AxButton { anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter
                   icon: "play_arrow"; text: page.busy === "lynis" ? "Running…" : page.lynis ? "Run again" : "Run audit"; kind: "primary"; enabled_: page.busy === ""; onClicked: page.runLynis() }
    }

    Section {
        visible: !!page.lynis && page.lynis.warnings.length > 0
        title: "Warnings"
        Repeater {
            model: page.lynis ? page.lynis.warnings : []
            SRow { required property var modelData; icon: "warning"; title: modelData.text; desc: modelData.id + (modelData.detail ? "  ·  " + modelData.detail : "")
                   Badge { text: "warning"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter } }
        }
    }
    Section {
        visible: !!page.lynis && page.lynis.suggestions.length > 0
        title: "Suggestions"
        note: page.lynis ? page.lynis.suggestions.length + "" : ""
        Repeater {
            model: page.lynis ? (page.allSugg ? page.lynis.suggestions : page.lynis.suggestions.slice(0, 12)) : []
            SRow { required property var modelData; icon: "lightbulb"; title: modelData.text; desc: modelData.id + (modelData.detail ? "  ·  " + modelData.detail : ""); dim: true }
        }
        SRow {
            visible: !!page.lynis && page.lynis.suggestions.length > 12 && !page.allSugg
            icon: "expand_more"; title: "Show all " + (page.lynis ? page.lynis.suggestions.length : 0); clickable: true; onClicked: page.allSugg = true
        }
    }

    // rkhunter
    Section {
        title: "Rootkit check"
        note: "rkhunter"
        SRow {
            icon: "bug_report"; title: page.rk === null ? "Look for rootkits and changed system files" : page.rk.length === 0 ? "Nothing suspicious found" : page.rk.length + " things to look at"
            desc: page.busy === "rk" ? "Scanning… a few minutes" : "Compares system binaries against what was installed and checks for known rootkits"
            AxButton { text: page.busy === "rk" ? "Scanning…" : "Scan"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.runRk() }
        }
        Repeater {
            model: page.rk || []
            SRow { required property string modelData; icon: "report"; title: modelData.slice(0, 120); dim: true }
        }
    }
}

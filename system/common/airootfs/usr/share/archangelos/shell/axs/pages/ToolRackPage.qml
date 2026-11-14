import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Fallen"
    title: "Tool rack"
    desc: "Every security tool on this machine, sorted by what it does."

    property var cats: []
    property int total: 0
    property bool loaded: false
    property string query: ""
    property string open_: ""

    Cmd { id: cmd }
    function load() {
        cmd.run(["/usr/bin/archangelos-menugen", "--redteam"], (c, o) => {
            try {
                const d = JSON.parse(o);
                const src = d.categories || [];
                let out = [];
                let n = 0;
                for (const cat of src) {
                    const items = cat.items || [];
                    if (!items.length) continue;
                    const tools = items.map(it => ({
                        name: it.name, exec: it.exec,
                        comment: it.pkg || "",
                        terminal: it.terminal !== undefined ? it.terminal : !it.gui
                    }));
                    out.push({ group: cat.name, tools: tools });
                    n += tools.length;
                }
                page.cats = out;
                page.total = n;
            } catch (e) { page.cats = []; page.total = 0; }
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function shq(s) { return "'" + String(s).split("'").join("'\\''") + "'"; }
    function launch(t) {
        const q = page.shq(t.exec);
        let script;
        if (t.terminal) {
            script = "AXEXE=" + q + "; export AXEXE; TERM_EMU=;"
                   + "for term in rio konsole alacritty foot kitty wezterm xterm; do command -v \"$term\" >/dev/null 2>&1 && { TERM_EMU=$term; break; }; done;"
                   + "setsid \"$TERM_EMU\" -e bash -c 'exec $AXEXE' >/dev/null 2>&1 &";
        } else {
            script = "AXEXE=" + q + "; export AXEXE; setsid bash -c 'exec $AXEXE' >/dev/null 2>&1 &";
        }
        Quickshell.execDetached(["sh", "-c", script]);
    }

    readonly property var glyphs: ({
        "Information Gathering": "travel_explore", "Vulnerability Analysis": "bug_report", "Web Application": "language",
        "Exploitation": "gps_fixed", "Password Attacks": "password", "Wireless Attacks": "wifi", "Bluetooth & RF": "bluetooth",
        "Sniffing & Spoofing": "network_check", "Reverse Engineering": "memory", "Forensics": "fingerprint",
        "Anonymity & Tunneling": "visibility_off", "Defense & Hardening": "verified_user", "Database Assessment": "database",
        "Malware Analysis": "coronavirus", "Fuzzing": "shuffle", "Code & Supply Chain": "code",
        "Automation & Utilities": "build"
    })
    function glyph(g) { return page.glyphs[g] || "terminal"; }

    readonly property var shown: {
        const q = page.query.trim().toLowerCase();
        if (!q) return page.cats;
        return page.cats.map(c => ({ group: c.group, tools: c.tools.filter(t => (t.name + " " + t.comment + " " + t.exec).toLowerCase().includes(q)) }))
                        .filter(c => c.tools.length);
    }

    header: AxField { width: 240; icon: "search"; placeholder: "Find a tool"; onTextChanged: page.query = text }

    Rectangle {
        width: parent.width; height: 74
        radius: Ax.radius; color: Ax.panel; border.width: 1; border.color: Ax.border
        CornerTicks { len: 8; anchors.margins: 10 }
        Row {
            x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 14
            Icon { name: "swords"; size: 24; color: Ax.accent; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 3
                Label { text: page.total + " tools across " + page.cats.length + " categories"; font.weight: Font.Medium }
                Label { text: "The same set the wheel opens with Super + Space"; font.pixelSize: Ax.fsSmall; color: Ax.muted }
            }
        }
        AxButton {
            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
            icon: "radio_button_checked"; text: "Open the wheel"
            onClicked: Quickshell.execDetached(["sh", "-c", "archangelos-wheel >/dev/null 2>&1 &"])
        }
    }

    Section {
        visible: page.loaded && page.total === 0
        EmptyState { icon: "inventory_2"; title: "No security tools found"; desc: "This edition ships the BlackArch tools; on a minimal install there may be none yet." }
    }

    Repeater {
        model: page.shown
        Section {
            id: catSec
            required property var modelData
            readonly property bool expanded: page.open_ === modelData.group || page.query.trim() !== ""
            title: catSec.modelData.group
            note: catSec.modelData.tools.length + ""
            SRow {
                visible: !catSec.expanded
                icon: page.glyph(catSec.modelData.group); title: catSec.modelData.group
                desc: catSec.modelData.tools.slice(0, 5).map(t => t.name).join(", ") + (catSec.modelData.tools.length > 5 ? "…" : "")
                clickable: true; chevron: true; onClicked: page.open_ = catSec.modelData.group
            }
            Repeater {
                model: catSec.expanded ? catSec.modelData.tools : []
                SRow {
                    required property var modelData
                    icon: "chevron_right"; title: modelData.name
                    desc: modelData.comment || modelData.exec
                    AxButton { visible: modelData.terminal; icon: "terminal"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.launch(modelData) }
                    AxButton { text: "Launch"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.launch(modelData) }
                }
            }
            SRow {
                visible: catSec.expanded && page.query.trim() === ""
                icon: "expand_less"; title: "Collapse"; clickable: true; onClicked: page.open_ = ""
            }
        }
    }
}

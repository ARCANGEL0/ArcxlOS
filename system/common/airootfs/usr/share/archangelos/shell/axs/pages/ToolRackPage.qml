// Tool rack (Fallen) — the security tools installed on this machine, grouped by what they're for,
// searchable, each able to launch. It's the same catalogue the desktop wheel (Super+Space) draws
// from: /usr/lib/archangelos/axs-tools reads the installed .desktop files. It launches only; it
// installs nothing.
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

    property var cats: []              // { group, tools: [{name, exec, comment, terminal}] }
    property int total: 0
    property bool loaded: false
    property string query: ""
    property string open_: ""

    Cmd { id: cmd }
    function load() {
        cmd.run(["/usr/lib/archangelos/axs-tools"], (c, o) => {
            try { const d = JSON.parse(o); page.cats = d.categories || []; page.total = d.total || 0; }
            catch (e) { page.cats = []; }
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function launch(t) {
        if (t.terminal) Quickshell.execDetached(["sh", "-c", "for term in rio foot kitty alacritty xterm; do command -v $term >/dev/null && exec $term -e sh -c '" + t.exec.replace(/'/g, "'\\''") + "; exec $SHELL'; done"]);
        else Quickshell.execDetached(["sh", "-c", t.exec + " >/dev/null 2>&1 &"]);
    }

    readonly property var glyphs: ({
        "Information Gathering": "travel_explore", "Vulnerability Analysis": "bug_report", "Web Applications": "language",
        "Exploitation": "gps_fixed", "Passwords": "password", "Wireless": "wifi", "Bluetooth & RF": "bluetooth",
        "Sniffing & Spoofing": "network_check", "Reverse Engineering": "memory", "Forensics": "fingerprint",
        "Anonymity": "visibility_off", "Blue Team & Defense": "verified_user", "Databases": "database",
        "Malware Analysis": "coronavirus", "Hardware & RF": "cable", "Cryptography": "enhanced_encryption",
        "Mobile": "smartphone", "VoIP": "call", "Social Engineering": "groups", "Utilities": "build"
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

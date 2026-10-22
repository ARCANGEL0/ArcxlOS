// Encryption › Checksums — fingerprint a file (or typed text) with any hash the system has, check
// it against a published value, or compute an HMAC. The hashing is done on this computer by
// /usr/lib/archangelos/axs-crypto; nothing is uploaded.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Encryption"
    title: "Checksums"
    desc: "Prove a download is exactly what its publisher released — it never leaves this computer."

    readonly property string tool: "/usr/lib/archangelos/axs-crypto"
    property var catalog: []                      // [{ key, title, note }]
    property string file: ""
    property string text: ""
    property int mode: 0                           // 0 file, 1 text
    property var picked: ["sha256", "sha512", "blake2b"]
    property var results: ({})
    property string hmacKey: ""
    property bool busy: false

    Cmd { id: cmd }
    function ask(req, cb) { cmd.run([page.tool], (c, o) => { let r = {}; try { r = JSON.parse(o); } catch (x) {} cb(r); }, JSON.stringify(req)); }
    Component.onCompleted: ask({ op: "algos" }, (r) => page.catalog = r.algos || [])
    function title(k) { const a = page.catalog.find(x => x.key === k); return a ? a.title : k; }

    function compute() {
        if (page.mode === 0 && page.file === "") return;
        page.busy = true;
        const req = { op: "hash", algos: page.picked };
        if (page.mode === 0) req.file = page.file; else req.text = page.text;
        if (page.hmacKey) req.hmac = page.hmacKey;
        page.ask(req, (r) => { page.results = r.results || ({}); page.busy = false; });
    }
    // accept a bare hash, or a line from a SHA256SUMS file
    readonly property string want: (/([0-9a-f]{8,128})/.exec(compare.text.trim().toLowerCase()) || ["", ""])[1]
    readonly property var byLength: ({ 8: ["crc32"], 16: ["xxh64"], 32: ["md5"], 40: ["sha1"], 56: ["sha224", "sha3_224"],
        64: ["sha256", "sha3_256", "blake2s", "sm3"], 96: ["sha384", "sha3_384"], 128: ["sha512", "sha3_512", "blake2b"] })
    onWantChanged: {
        const ks = (page.byLength[page.want.length] || []).filter(k => page.catalog.some(a => a.key === k));
        const missing = ks.filter(k => page.picked.indexOf(k) < 0);
        if (missing.length) { page.picked = page.picked.concat(missing); page.compute(); }
    }
    readonly property string match: { for (const k in page.results) if (want !== "" && page.results[k] === want) return k; return ""; }

    FilePick { id: pick; title: "Choose a file"; folder: Quickshell.env("HOME"); onPicked: (p) => { page.file = p; page.compute(); } }
    header: AxButton { icon: "arrow_back"; text: "Encryption"; onClicked: NSS.Shell.openSettings("encryption") }

    Rectangle {
        visible: page.mode === 0
        width: parent.width; height: how.implicitHeight + 36
        radius: Ax.radius; color: Ax.panel; border.width: 1; border.color: Ax.border
        Row {
            id: how
            x: 20; y: 18; width: parent.width - 40; spacing: 22
            Repeater {
                model: [["1", "Choose the file you downloaded"], ["2", "Paste the hash from the download page — the right algorithm is picked automatically"], ["3", "A green match means the file is genuine and unmodified"]]
                Row {
                    required property var modelData
                    width: (how.width - 44) / 3; spacing: 10
                    Rectangle { width: 24; height: 24; radius: 12; color: Ax.accentSoft; border.width: 1; border.color: Ax.accentLine
                                Label { anchors.centerIn: parent; mono: true; font.pixelSize: Ax.fsSmall; text: modelData[0]; color: Ax.accent } }
                    Label { width: parent.width - 34; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: modelData[1] }
                }
            }
        }
    }

    Section {
        title: "Input"
        SRow {
            icon: page.mode === 0 ? "description" : "text_fields"
            title: page.mode === 0 ? (page.file ? page.file.split("/").pop() : "Choose a file") : "Type text below"
            desc: page.mode === 0 ? (page.file || "An ISO, an installer, a download") : "Hashes the exact text you type"
            AxSegment { options: ["File", "Text"]; current: page.mode; onPicked: (i) => { page.mode = i; page.results = ({}); } ; anchors.verticalCenter: parent.verticalCenter }
            AxButton { visible: page.mode === 0; text: "Choose…"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: pick.open() }
        }
        Item {
            visible: page.mode === 1
            property bool topDivider: false
            width: parent.width; height: 90
            AxTextArea { id: textIn; x: Ax.pad; y: 12; width: parent.width - 2 * Ax.pad; height: 66; placeholder: "Text to hash"
                         onTextChanged: { page.text = text; page.compute(); } }
        }
        SRow {
            icon: "vpn_key"; title: "HMAC key"; desc: "Optional — keyed hash, to prove a message is from someone who knows the key"
            AxField { id: hmacF; width: 220; placeholder: "Leave empty for a plain hash"; anchors.verticalCenter: parent.verticalCenter
                      onTextChanged: { page.hmacKey = text; page.compute(); } }
        }
        Item {
            property bool topDivider: false
            width: parent.width; height: chips.height + 30
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Flow {
                id: chips
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad; spacing: 8
                Repeater {
                    model: page.catalog
                    ChipToggle { required property var modelData; text: modelData.title; icon: "tag"
                                 checked: page.picked.indexOf(modelData.key) >= 0
                                 onToggled: (on) => { page.picked = on ? page.picked.concat([modelData.key]) : page.picked.filter(k => k !== modelData.key); page.compute(); } }
                }
            }
        }
    }

    Section {
        visible: (page.mode === 0 && page.file !== "") || (page.mode === 1 && page.text !== "")
        title: page.hmacKey ? "HMAC" : "Hashes"
        note: page.busy ? "computing…" : ""
        Repeater {
            model: page.picked.filter(k => page.catalog.some(a => a.key === k))
            SRow {
                required property string modelData
                readonly property var a: page.catalog.find(x => x.key === modelData)
                icon: page.match === modelData ? "verified" : "tag"
                title: page.title(modelData) + (a && a.note ? "  ·  " + a.note : "")
                desc: page.results[modelData] || (page.busy ? "…" : "—")
                Badge { visible: page.match === modelData; text: "match"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { icon: "content_copy"; anchors.verticalCenter: parent.verticalCenter; enabled_: !!page.results[modelData]
                           onClicked: Quickshell.execDetached(["wl-copy", "--", page.results[modelData]]) }
            }
        }
        SRow {
            visible: !page.hmacKey
            icon: "compare_arrows"; title: "Compare"
            desc: page.want === "" ? "Paste a published hash — any algorithm, recognised by length"
                : page.busy ? "Checking…" : page.match !== "" ? "Matches " + page.title(page.match) + " — genuine and unmodified"
                : "No match — the file is damaged or not the one published"
            AxField { id: compare; width: 340; placeholder: "Paste the published hash"; anchors.verticalCenter: parent.verticalCenter }
            Badge { visible: page.want !== ""; text: page.match !== "" ? "verified" : "mismatch"; tone: page.match !== "" ? "accent" : "danger"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}

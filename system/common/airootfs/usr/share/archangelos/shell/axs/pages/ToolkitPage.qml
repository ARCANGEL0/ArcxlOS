// Encryption › Crypto toolkit — the small jobs that don't fit a file: encode and decode text,
// encrypt and decrypt a short message, hash or HMAC typed text, generate and check password
// hashes, make random secrets and keys, guess what a hash is, and read a certificate. Everything
// goes through /usr/lib/archangelos/axs-crypto, which runs as you and keeps secrets off the
// command line.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Encryption"
    title: "Crypto toolkit"
    desc: "Everyday cryptography: encode, hash, encrypt a message, make a password or a key."

    readonly property string tool: "/usr/lib/archangelos/axs-crypto"
    property int tab: 0
    readonly property var tabs: ["Encode", "Message", "Text hash", "Passwords", "Generate", "Identify", "Certificate"]
    readonly property var codecs: [["base64", "Base64"], ["base64url", "Base64 (URL-safe)"], ["base32", "Base32"],
        ["hex", "Hex"], ["url", "URL (percent)"], ["html", "HTML entities"], ["quoted", "Quoted-printable"], ["rot13", "ROT13"]]
    readonly property var pwSchemes: [["bcrypt", "bcrypt"], ["argon2", "Argon2id"], ["yescrypt", "yescrypt"], ["sha512", "sha512crypt"], ["sha256", "sha256crypt"]]
    readonly property var keyKinds: [["ssh-ed25519", "SSH (Ed25519)"], ["ssh-rsa", "SSH (RSA 4096)"], ["ssh-ecdsa", "SSH (ECDSA 521)"], ["age", "age (encryption)"]]
    property string error: ""

    Cmd { id: cmd }
    // one call: send a JSON request on stdin, get the parsed reply back
    function ask(req, cb) {
        page.error = "";
        cmd.run([page.tool], (c, o, e) => {
            let r = {}; try { r = JSON.parse(o); } catch (x) { r = { ok: false, error: (e || o).trim() || "No answer." }; }
            if (!r.ok && r.error) page.error = r.error;
            cb(r);
        }, JSON.stringify(req));
    }
    function copy(s) { if (s) Quickshell.execDetached(["wl-copy", "--", s]); }

    // tab bar
    Item {
        width: parent.width; height: 40
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: page.tabs
                Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool on: page.tab === index
                    height: 32; width: tl.implicitWidth + 24; radius: 16
                    color: on ? Ax.accentSoft : (tma.containsMouse ? Ax.raised : "transparent")
                    border.width: 1; border.color: on ? Ax.accentLine : Ax.border
                    Label { id: tl; anchors.centerIn: parent; text: modelData; font.pixelSize: Ax.fsSmall; color: on ? Ax.accent : Ax.subtext }
                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.tab = index }
                }
            }
        }
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    // ── Encode / decode ──────────────────────────────────────────────────────────
    Section {
        visible: page.tab === 0
        title: "Encode & decode"
        SRow {
            icon: "swap_horiz"; title: "Encoding"
            AxSelect { id: codec; width: 220; anchors.verticalCenter: parent.verticalCenter; model: page.codecs.map(c => c[1]); current: 0 }
            AxSegment { id: dir; options: ["Encode", "Decode"]; current: 0; onPicked: (i) => current = i; anchors.verticalCenter: parent.verticalCenter }
        }
        Item {
            property bool topDivider: false
            width: parent.width; height: enCol.implicitHeight + 30
            Column {
                id: enCol
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad; spacing: 10
                AxTextArea { id: enIn; width: parent.width; height: 90; placeholder: "Text in" }
                Row { spacing: 8
                    AxButton { text: dir.current ? "Decode" : "Encode"; kind: "primary"
                               onClicked: page.ask({ op: "encode", text: enIn.text, codec: page.codecs[codec.current][0], decode: dir.current === 1 }, (r) => enOut.text = r.result || "") }
                    AxButton { text: "Swap"; icon: "swap_vert"; onClicked: { const t = enIn.text; enIn.text = enOut.text; enOut.text = t; dir.current = dir.current ? 0 : 1; } }
                    AxButton { text: "Copy"; icon: "content_copy"; onClicked: page.copy(enOut.text) }
                }
                AxTextArea { id: enOut; width: parent.width; height: 90; placeholder: "Result" }
            }
        }
    }

    // ── Message encrypt/decrypt ──────────────────────────────────────────────────
    readonly property var msgCiphers: ["aes-256-cbc", "camellia-256-cbc", "aes-256-ctr", "chacha20"]
    Section {
        visible: page.tab === 1
        title: "Encrypt a message"
        note: "openssl · passphrase"
        SRow {
            icon: "shield"; title: "Cipher"; desc: "Stretched with PBKDF2-SHA256, 100k rounds. The result is Base64 you can paste anywhere"
            AxSelect { id: msgCipher; width: 200; anchors.verticalCenter: parent.verticalCenter
                       model: ["AES-256-CBC", "Camellia-256", "AES-256-CTR", "ChaCha20"]; current: 0 }
        }
        SRow {
            icon: "key"; title: "Passphrase"
            AxField { id: msgPw; width: 240; password: true; placeholder: "Passphrase"; anchors.verticalCenter: parent.verticalCenter }
        }
        Item {
            property bool topDivider: false
            width: parent.width; height: msgCol.implicitHeight + 30
            Column {
                id: msgCol
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad; spacing: 10
                AxTextArea { id: msgIn; width: parent.width; height: 100; placeholder: "Message, or encrypted text to open" }
                Row { spacing: 8
                    AxButton { text: "Encrypt"; kind: "primary"; enabled_: msgPw.text !== "" && msgIn.text !== ""
                               onClicked: page.ask({ op: "encrypt-text", text: msgIn.text, password: msgPw.text, cipher: page.msgCiphers[msgCipher.current] }, (r) => { if (r.ok) msgOut.text = r.result || ""; }) }
                    AxButton { text: "Decrypt"; enabled_: msgPw.text !== "" && msgIn.text !== ""
                               onClicked: page.ask({ op: "decrypt-text", text: msgIn.text, password: msgPw.text, cipher: page.msgCiphers[msgCipher.current] }, (r) => { if (r.ok) msgOut.text = r.result || ""; }) }
                    AxButton { text: "Copy"; icon: "content_copy"; onClicked: page.copy(msgOut.text) }
                }
                AxTextArea { id: msgOut; width: parent.width; height: 100; placeholder: "Result" }
            }
        }
    }

    // ── Text hash ────────────────────────────────────────────────────────────────
    Section {
        visible: page.tab === 2
        title: "Hash typed text"
        note: "and HMAC"
        Item {
            property bool topDivider: false
            width: parent.width; height: thCol.implicitHeight + 30
            Column {
                id: thCol
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad; spacing: 10
                AxTextArea { id: thIn; width: parent.width; height: 70; placeholder: "Text to hash" }
                Row { spacing: 8
                    AxField { id: thKey; width: 220; placeholder: "HMAC key (optional)" }
                    AxButton { text: "Hash"; kind: "primary"
                               onClicked: page.ask({ op: "hash", text: thIn.text, hmac: thKey.text || undefined,
                                                     algos: ["md5", "sha1", "sha256", "sha512", "sha3_256", "blake2b"] }, (r) => page.thRes = r.results || ({})) }
                }
            }
        }
        Repeater {
            model: page.thRes ? Object.keys(page.thRes) : []
            SRow {
                required property var modelData
                icon: "tag"; title: ({ md5: "MD5", sha1: "SHA-1", sha256: "SHA-256", sha512: "SHA-512", sha3_256: "SHA3-256", blake2b: "BLAKE2b" })[modelData] || modelData
                desc: page.thRes[modelData] || "—"
                AxButton { icon: "content_copy"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.copy(page.thRes[modelData]) }
            }
        }
    }
    property var thRes: null

    // ── Passwords ────────────────────────────────────────────────────────────────
    Section {
        visible: page.tab === 3
        title: "Create a password hash"
        SRow {
            icon: "password"; title: "Scheme"; desc: "bcrypt and Argon2 are the modern choices for storing passwords"
            AxSelect { id: pwScheme; width: 180; anchors.verticalCenter: parent.verticalCenter; model: page.pwSchemes.map(x => x[1]); current: 0 }
        }
        SRow {
            icon: "key"; title: "Password"
            AxField { id: pwIn; width: 220; password: true; placeholder: "Password"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Hash"; kind: "primary"; enabled_: pwIn.text !== ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.ask({ op: "pwhash", password: pwIn.text, scheme: page.pwSchemes[pwScheme.current][0] }, (r) => pwHash.text = r.hash || "") }
        }
        SRow {
            visible: pwHash.text !== ""
            icon: "data_object"; title: "Hash"; desc: pwHash.text
            AxButton { icon: "content_copy"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.copy(pwHash.text) }
        }
        Item { property bool topDivider: true; width: 1; height: 1; Label { id: pwHash; visible: false } }
    }
    Section {
        visible: page.tab === 3
        title: "Check a password against a hash"
        SRow {
            icon: "check_circle"; title: "Password"
            AxField { id: vPw; width: 200; password: true; placeholder: "Password"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "data_object"; title: "Hash"
            AxField { id: vHash; width: 320; placeholder: "$2b$… or $argon2… or $6$…"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Check"; kind: "primary"; enabled_: vPw.text !== "" && vHash.text !== ""; anchors.verticalCenter: parent.verticalCenter
                       onClicked: page.ask({ op: "pwverify", password: vPw.text, hash: vHash.text }, (r) => page.vResult = r.ok ? (r.valid ? "yes" : "no") : "") }
            Badge { visible: page.vResult !== ""; text: page.vResult === "yes" ? "matches" : "no match"; tone: page.vResult === "yes" ? "accent" : "danger"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    property string vResult: ""

    // ── Generate ─────────────────────────────────────────────────────────────────
    Section {
        visible: page.tab === 4
        title: "Random secrets"
        SRow {
            icon: "password"; title: "Password"; desc: genPw.text || "Letters, digits and symbols"
            AxButton { text: "16"; onClicked: page.ask({ op: "random", kind: "password", length: 16 }, (r) => genPw.text = r.value || "") ; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "24"; onClicked: page.ask({ op: "random", kind: "password", length: 24 }, (r) => genPw.text = r.value || "") ; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "40"; onClicked: page.ask({ op: "random", kind: "password", length: 40 }, (r) => genPw.text = r.value || "") ; anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "content_copy"; onClicked: page.copy(genPw.text); anchors.verticalCenter: parent.verticalCenter }
            Label { id: genPw; visible: false }
        }
        SRow {
            icon: "menu_book"; title: "Passphrase"; desc: genPp.text || "Random words, easy to type"
            AxButton { text: "5 words"; onClicked: page.ask({ op: "random", kind: "passphrase", words: 5 }, (r) => genPp.text = r.value || ""); anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "7 words"; onClicked: page.ask({ op: "random", kind: "passphrase", words: 7 }, (r) => genPp.text = r.value || ""); anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "content_copy"; onClicked: page.copy(genPp.text); anchors.verticalCenter: parent.verticalCenter }
            Label { id: genPp; visible: false }
        }
        SRow {
            icon: "tag"; title: "Key / token"; desc: genTok.text || "Hex or Base64, for API keys and the like"
            AxButton { text: "Hex 32"; onClicked: page.ask({ op: "random", kind: "hex", length: 32 }, (r) => genTok.text = r.value || ""); anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Base64"; onClicked: page.ask({ op: "random", kind: "base64", length: 32 }, (r) => genTok.text = r.value || ""); anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "UUID"; onClicked: page.ask({ op: "random", kind: "uuid" }, (r) => genTok.text = r.value || ""); anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "content_copy"; onClicked: page.copy(genTok.text); anchors.verticalCenter: parent.verticalCenter }
            Label { id: genTok; visible: false }
        }
    }
    Section {
        visible: page.tab === 4
        title: "Generate a key"
        SRow {
            icon: "vpn_key"; title: "Key type"
            AxSelect { id: keyKind; width: 200; anchors.verticalCenter: parent.verticalCenter; model: page.keyKinds.map(k => k[1]); current: 0 }
        }
        SRow {
            icon: "badge"; title: "Comment"; desc: "A label, usually you@computer (SSH only)"
            AxField { id: keyComment; width: 220; placeholder: Quickshell.env("USER") + "@archangelos"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "lock"; title: "Protect with a passphrase"; desc: "Recommended for SSH keys"
            AxField { id: keyPass; width: 200; password: true; placeholder: "Passphrase (optional)"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Create"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                       onClicked: keyPick.open() }
        }
        SRow {
            visible: page.keyPub !== ""
            icon: "key"; title: "Public key"; desc: page.keyPub
            AxButton { icon: "content_copy"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.copy(page.keyPub) }
        }
    }
    property string keyPub: ""
    FilePick {
        id: keyPick; title: "Save the new key as…"; save: true; folder: Quickshell.env("HOME") + "/.ssh"; suggested: "id_new"
        onPicked: (p) => page.ask({ op: "keygen", kind: ["ssh-ed25519", "ssh-rsa", "ssh-ecdsa", "age"][keyKind.current], path: p, comment: keyComment.text, passphrase: keyPass.text }, (r) => { if (r.ok) page.keyPub = r.public || "(key saved)"; })
    }

    // ── Identify ─────────────────────────────────────────────────────────────────
    Section {
        visible: page.tab === 5
        title: "What kind of hash is this?"
        SRow {
            icon: "quiz"; title: "Hash"; desc: page.idInfo
            AxField { id: idIn; width: 340; placeholder: "Paste a hash"; anchors.verticalCenter: parent.verticalCenter
                      onTextChanged: page.ask({ op: "identify", hash: text }, (r) => page.idInfo = !text ? "" : (r.candidates && r.candidates.length ? r.candidates.join(", ") + "  (" + r.length + " chars)" : "Unrecognised" + (r.length ? "  (" + r.length + " chars)" : ""))) }
        }
    }
    property string idInfo: ""

    // ── Certificate viewer ───────────────────────────────────────────────────────
    Section {
        visible: page.tab === 6
        title: "Read a certificate or key"
        SRow {
            icon: "badge"; title: page.certFile ? page.certFile.split("/").pop() : "Choose a file"
            desc: page.certFile || "Certificates (.crt .pem .cer), signing requests and public keys"
            AxButton { text: "Choose…"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: certPick.open() }
        }
        Item {
            visible: page.certText !== ""
            property bool topDivider: false
            width: parent.width; height: 300
            AxTextArea { x: Ax.pad; y: 12; width: parent.width - 2 * Ax.pad; height: 280; text: page.certText }
        }
    }
    property string certFile: ""
    property string certText: ""
    FilePick { id: certPick; title: "Choose a certificate or key"; filters: ["Certificates & keys (*.crt *.pem *.cer *.der *.csr *.key *.pub)", "All files (*)"]; folder: Quickshell.env("HOME")
               onPicked: (p) => { page.certFile = p; page.certText = "Reading…"; page.ask({ op: "certinfo", file: p }, (r) => page.certText = r.ok ? r.text : ""); } }

    header: AxButton { icon: "arrow_back"; text: "Encryption"; onClicked: NSS.Shell.openSettings("encryption") }
}

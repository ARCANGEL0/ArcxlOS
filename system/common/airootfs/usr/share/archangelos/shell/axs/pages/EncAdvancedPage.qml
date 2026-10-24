// Encryption › Advanced — the cipher, key size, hash and key derivation for drives encrypted from
// here, how account passwords are hashed, and your GPG keys.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Encryption"
    title: "Advanced"
    desc: "The algorithms behind it all. The defaults are strong; change them only for a reason."

    readonly property var ciphers: [["aes-xts-plain64", "AES-XTS", "Hardware-accelerated almost everywhere"], ["serpent-xts-plain64", "Serpent-XTS", "Large safety margin, slower"], ["twofish-xts-plain64", "Twofish-XTS", "AES finalist, fast in software"]]
    readonly property var hashes: ["sha256", "sha512", "sha3-256", "sha3-512", "blake2b-512"]
    readonly property var pbkdfs: [["argon2id", "Argon2id", "Memory-hard; resists GPU guessing (recommended)"], ["argon2i", "Argon2i", "Memory-hard, side-channel resistant"], ["pbkdf2", "PBKDF2", "Old and compatible, weakest against GPUs"]]
    property string method: ""
    property int rounds: 0
    property var keys: []
    property string busy: ""
    property string error: ""
    property string notice: ""

    FileView {
        path: "/etc/login.defs"
        onLoaded: {
            const t = text(), g = (k) => { const m = new RegExp("^\\s*" + k + "\\s+(\\S+)", "m").exec(t); return m ? m[1] : ""; };
            page.method = g("ENCRYPT_METHOD") || "YESCRYPT";
            page.rounds = +(page.method === "YESCRYPT" ? (g("YESCRYPT_COST_FACTOR") || 5) : (g("SHA_CRYPT_MIN_ROUNDS") || 5000));
        }
    }
    Cmd { id: cmd }
    function loadKeys() {
        cmd.run(["gpg", "--list-secret-keys", "--with-colons"], (c, o) => {
            const out = []; let cur = null;
            for (const l of o.split("\n")) {
                const f = l.split(":");
                if (f[0] === "sec") { cur = { algo: ({ "1": "RSA", "17": "DSA", "18": "ECDH", "19": "ECDSA", "22": "Ed25519" })[f[3]] || "key", bits: f[2], expires: f[6], id: f[4], uid: "" }; out.push(cur); }
                else if (f[0] === "fpr" && cur && !cur.fpr) cur.fpr = f[9];
                else if (f[0] === "uid" && cur && !cur.uid) cur.uid = f[9];
            }
            page.keys = out;
        });
    }
    Component.onCompleted: loadKeys()
    function run(what, argv, input, ok, after) {
        page.busy = what; page.error = ""; page.notice = "";
        cmd.run(argv, (c, o, e) => { page.busy = ""; if (c === 126 || c === 127) page.error = "Cancelled."; else if (c !== 0) page.error = (e || o).trim().split("\n").pop(); else { page.notice = ok; if (after) after(); } }, input);
    }

    header: AxButton { icon: "arrow_back"; text: "Encryption"; onClicked: NSS.Shell.openSettings("encryption") }
    Label { visible: page.error !== "" || page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
            color: page.error !== "" ? Ax.danger : Ax.ok; text: page.error || page.notice }

    Section {
        title: "New encrypted drives"
        note: "LUKS2"
        SRow {
            icon: "shield"; title: "Cipher"; desc: page.ciphers.find(c => c[0] === Store.data.luksCipher)?.[2] ?? ""
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter; model: page.ciphers.map(c => c[1])
                       current: page.ciphers.findIndex(c => c[0] === Store.data.luksCipher); onPicked: (i) => Store.data.luksCipher = page.ciphers[i][0] }
        }
        SRow {
            icon: "key"; title: "Key size"; desc: "XTS splits the key in two: 512 bits means 256-bit security"
            AxSegment { anchors.verticalCenter: parent.verticalCenter; options: ["256-bit", "512-bit"]; current: Store.data.luksKeyBits === 256 ? 0 : 1
                        onPicked: (i) => Store.data.luksKeyBits = i ? 512 : 256 }
        }
        SRow {
            icon: "tag"; title: "Hash"; desc: "Used for the key slots and anti-forensic splitting"
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter; model: page.hashes.map(h => h.toUpperCase())
                       current: page.hashes.indexOf(Store.data.luksHash); onPicked: (i) => Store.data.luksHash = page.hashes[i] }
        }
        SRow {
            icon: "memory"; title: "Key derivation"; desc: page.pbkdfs.find(p => p[0] === Store.data.luksPbkdf)?.[2] ?? ""
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter; model: page.pbkdfs.map(p => p[1])
                       current: page.pbkdfs.findIndex(p => p[0] === Store.data.luksPbkdf); onPicked: (i) => Store.data.luksPbkdf = page.pbkdfs[i][0] }
        }
    }

    Section {
        title: "Account passwords"
        note: "/etc/login.defs"
        SRow {
            icon: "password"; title: "Hashing for new passwords"; desc: "Takes effect the next time a password is set or changed"
            AxSelect { id: hm; width: 180; anchors.verticalCenter: parent.verticalCenter
                       readonly property var ms: ["YESCRYPT", "SHA512", "SHA256"]
                       model: ["yescrypt (recommended)", "SHA-512 crypt", "SHA-256 crypt"]; current: Math.max(0, ms.indexOf(page.method))
                       onPicked: (i) => { page.method = ms[i]; page.rounds = i === 0 ? 5 : 656000; } }
        }
        SRow {
            icon: "speed"; title: page.method === "YESCRYPT" ? "Cost factor" : "Rounds"
            desc: page.method === "YESCRYPT" ? "1–11. Each step doubles the work for anyone guessing" : "More rounds, slower guessing (and logins)"
            AxSlider { visible: page.method === "YESCRYPT"; width: 220; anchors.verticalCenter: parent.verticalCenter; from: 1; to: 11; stepSize: 1; value: page.rounds; onReleased: (v) => page.rounds = Math.round(v) }
            AxField { visible: page.method !== "YESCRYPT"; width: 110; text: String(page.rounds); anchors.verticalCenter: parent.verticalCenter; onTextChanged: if (/^\d+$/.test(text)) page.rounds = +text }
            AxButton { text: "Apply"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; enabled_: page.busy === ""
                       onClicked: page.run("pw", ["/usr/lib/archangelos/axs-sec", "pw-hash", page.method, String(page.rounds)], undefined, "Saved. Change your password once to rehash it.") }
        }
    }

    Section {
        title: "GPG keys"
        note: page.keys.length ? page.keys.length + "" : ""
        EmptyState { visible: page.keys.length === 0; icon: "key"; title: "No keys yet"; desc: "A key lets people send you encrypted files and verify what you sign." }
        Repeater {
            model: page.keys
            SRow {
                required property var modelData
                icon: "key"; title: modelData.uid || modelData.id
                desc: modelData.algo + (modelData.bits && modelData.algo === "RSA" ? " " + modelData.bits : "") + "  ·  " + (modelData.fpr || modelData.id).replace(/(.{4})/g, "$1 ").trim()
                      + (modelData.expires ? "  ·  expires " + Qt.formatDate(new Date(+modelData.expires * 1000), "d MMM yyyy") : "")
                AxButton { icon: "ios_share"; text: "Export public"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: page.run("exp", ["sh", "-c", 'gpg --armor --export "$1" > "$2"', "sh", modelData.fpr || modelData.id, Quickshell.env("HOME") + "/" + (modelData.id || "key") + ".asc"],
                                               undefined, "Saved to ~/" + (modelData.id || "key") + ".asc — share that file freely.") }
            }
        }
        Item {
            property bool topDivider: false
            width: parent.width; height: gk.implicitHeight + 32
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: gk
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad; spacing: 10
                Label { text: "New key"; font.weight: Font.Medium }
                Row {
                    spacing: 8
                    AxField { id: gName; width: 180; placeholder: "Your name" }
                    AxField { id: gMail; width: 220; placeholder: "you@example.com" }
                    AxSelect { id: gAlgo; width: 170; model: ["Ed25519 (modern)", "RSA 4096", "RSA 3072"]; current: 0 }
                    AxSelect { id: gExp; width: 140; model: ["Expires in 1 year", "2 years", "5 years", "Never"]; current: 1 }
                }
                Row {
                    spacing: 8
                    AxField { id: g1; width: 200; password: true; icon: "key"; placeholder: "Passphrase (8+)" }
                    AxField { id: g2; width: 150; password: true; placeholder: "Again" }
                    AxButton {
                        text: page.busy === "gen" ? "Generating…" : "Create key"; kind: "primary"
                        enabled_: page.busy === "" && gName.text.trim() !== "" && /^\S+@\S+\.\S+$/.test(gMail.text) && g1.text.length >= 8 && g1.text === g2.text
                        onClicked: {
                            const algo = ["ed25519", "rsa4096", "rsa3072"][gAlgo.current], exp = ["1y", "2y", "5y", "never"][gExp.current];
                            page.run("gen", ["sh", "-c", 'IFS= read -r pw; printf "%s" "$pw" | gpg --batch --pinentry-mode loopback --passphrase-fd 0 --quick-gen-key "$1" "$2" default "$3"',
                                             "sh", gName.text.trim() + " <" + gMail.text.trim() + ">", algo, exp], g1.text + "\n", "Key created.", () => page.loadKeys());
                            g1.text = ""; g2.text = "";
                        }
                    }
                }
            }
        }
    }
}

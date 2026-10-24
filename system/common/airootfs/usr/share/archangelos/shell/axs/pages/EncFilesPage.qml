// Encryption › Files, folders & vaults — GPG-encrypt a file or a whole folder with a passphrase,
// decrypt it again, and gocryptfs vaults: folders that are encrypted on disk and open as a normal
// folder while unlocked.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Encryption"
    title: "Files, folders & vaults"
    desc: "Lock away single files, whole folders, or keep a vault that opens like a normal folder."

    readonly property string home: Quickshell.env("HOME")
    property string target: ""
    property bool targetIsDir: false
    property string source: ""          // something.gpg to decrypt
    property string busy: ""
    property string error: ""
    property string notice: ""
    property var mounted: ({})
    property bool hasVaults: false
    property bool hasAge: false
    property bool has7z: false
    readonly property var gpgCiphers: [["AES256", "AES-256"], ["TWOFISH", "Twofish"], ["CAMELLIA256", "Camellia-256"]]
    readonly property var sslCiphersEnc: ["aes-256-cbc", "aes-256-ctr", "chacha20", "camellia-256-cbc"]
    // [id, label, needs]
    readonly property var encFormats: [
        ["gpg-pass", "GPG — passphrase", ""],
        ["gpg-key", "GPG — to a public key", ""],
        ["openssl", "OpenSSL — passphrase", ""],
        ["age", "age — to a recipient", "age"],
        ["7z", "7-Zip (AES-256)", "7z"]
    ]
    function encFmtOk(f) { return f[2] === "" || (f[2] === "age" && page.hasAge) || (f[2] === "7z" && page.has7z); }

    Cmd { id: cmd }
    function check() {
        cmd.sh('command -v gocryptfs >/dev/null && echo has=1; command -v age >/dev/null && echo age=1; { command -v 7z >/dev/null || command -v 7za >/dev/null; } && echo z7=1; for m in "$@"; do mountpoint -q "$m" 2>/dev/null && echo "m=$m"; done', Store.data.vaults.map(v => v.mount), (c, o) => {
            const m = {}; for (const l of o.split("\n")) if (l.startsWith("m=")) m[l.slice(2)] = true;
            page.mounted = m; page.hasVaults = o.indexOf("has=1") >= 0; page.hasAge = o.indexOf("age=1") >= 0; page.has7z = o.indexOf("z7=1") >= 0;
        });
    }
    Component.onCompleted: check()
    function run(what, script, args, input, ok, after) {
        page.busy = what; page.error = ""; page.notice = "";
        cmd.run(["bash", "-c", script, "bash"].concat(args), (c, o, e) => {
            page.busy = "";
            if (c !== 0) page.error = (e || o).trim().split("\n").filter(l => l && !/^gpg: (AES|WARNING: no command)/.test(l)).pop() || "That didn't work.";
            else { page.notice = ok; if (after) after(); }
            page.check();
        }, input);
    }
    // Passphrases arrive on fd 3 (never on the command line); for folders stdin stays free for tar.
    function encrypt() {
        const t = page.target, dir = page.targetIsDir, shred = shredSw.checked;
        const fmt = page.encFormats[encFmt.current][0];
        const gpgC = page.gpgCiphers[gpgCipher.current][0], sslC = page.sslCiphersEnc[sslCipherE.current];
        const ext = ({ "gpg-pass": ".gpg", "gpg-key": ".gpg", "openssl": ".enc", "age": ".age", "7z": ".7z" })[fmt];
        const base = dir ? t.replace(/\/$/, "") : t;
        const out = fmt === "7z" ? base + ".7z" : (dir ? base + ".tar" + ext : t + ext);
        // the data to encrypt: a file as-is, a folder as a tar stream (except 7z, which packs itself)
        const feed = dir ? 'd=$(dirname "$1"); b=$(basename "$1"); tar -C "$d" -cf - "$b"' : 'cat "$1"';
        const shredTail = shred ? (dir ? ' && find "$1" -type f -exec shred -u {} + 2>/dev/null; rm -rf "$1"' : ' && shred -u "$1"') : "";
        let body, input = "", need = "";
        if (fmt === "gpg-pass")
            body = 'IFS= read -r pw; ' + feed + ' | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 3 '
                 + '--symmetric --cipher-algo "$3" --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712 --compress-algo zlib -o "$2" 3< <(printf %s "$pw")' + shredTail,
            input = p1.text + "\n";
        else if (fmt === "gpg-key") {
            if (recip.text.trim() === "") { page.error = "Enter a recipient (a key ID, fingerprint or email in your keyring)."; return; }
            const rcpts = recip.text.trim().split(/[,\s]+/).map(r => '--recipient "' + r.replace(/"/g, "") + '"').join(" ");
            body = feed + ' | gpg --batch --yes --quiet --trust-model always ' + rcpts + (signSw.checked ? ' --sign' : '') + ' --compress-algo zlib -o "$2"' + shredTail;
        } else if (fmt === "openssl")
            body = 'IFS= read -r pw; ' + feed + ' | openssl enc -"$3" -pbkdf2 -iter 100000 -md sha512 -salt -pass fd:3 -out "$2" 3< <(printf %s "$pw")' + shredTail,
            input = p1.text + "\n";
        else if (fmt === "age") {
            if (recip.text.trim() === "") { page.error = "Enter an age recipient (an age1… public key)."; return; }
            const rcpts = recip.text.trim().split(/[,\s]+/).map(r => '-r "' + r.replace(/"/g, "") + '"').join(" ");
            body = feed + ' | age ' + rcpts + ' -o "$2"' + shredTail;
        } else if (fmt === "7z") {
            // 7-Zip takes the passphrase as a switch; it is the one format that doesn't use fd 3
            const z = 'Z=$(command -v 7z || command -v 7za); IFS= read -r pw; "$Z" a -t7z -mx=5 -mhe=on -p"$pw" -- "$2" "$1" >/dev/null';
            body = z + shredTail, input = p1.text + "\n";
        }
        page.run("enc", body, [t, out, fmt === "gpg-pass" ? gpgC : sslC], input || undefined,
                 "Saved " + out + (shred ? " and shredded the original." : "."), () => { page.target = ""; });
        p1.text = ""; p2.text = "";
    }
    readonly property bool encNeedsPw: { const f = page.encFormats[encFmt.current][0]; return f === "gpg-pass" || f === "openssl" || f === "7z"; }
    readonly property bool encNeedsRecip: { const f = page.encFormats[encFmt.current][0]; return f === "gpg-key" || f === "age"; }

    FilePick { id: filePick; title: "Choose a file to encrypt"; folder: page.home; onPicked: (p) => { page.target = p; page.targetIsDir = false; } }
    FilePick { id: dirPick; title: "Choose a folder to encrypt"; pickFolder: true; folder: page.home; onPicked: (p) => { page.target = p; page.targetIsDir = true; } }
    FilePick { id: gpgPick; title: "Choose an encrypted file"; filters: ["Encrypted (*.gpg *.asc *.pgp *.enc *.age)", "All files (*)"]; folder: page.home; onPicked: (p) => { page.source = p; page.detect(p); } }
    FilePick { id: vaultPick; title: "Where to keep the vault's encrypted data"; pickFolder: true; folder: page.home; onPicked: (p) => vaultDir.text = p }

    header: AxButton { icon: "arrow_back"; text: "Encryption"; onClicked: NSS.Shell.openSettings("encryption") }

    Label { visible: page.error !== "" || page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
            color: page.error !== "" ? Ax.danger : Ax.ok; text: page.error || page.notice }

    Section {
        title: "Encrypt"
        note: page.encFormats[encFmt.current][1]
        SRow {
            icon: page.targetIsDir ? "folder" : "description"
            title: page.target === "" ? "Choose what to encrypt" : page.target.split("/").pop()
            desc: page.target === "" ? "A single file, or a folder (packed into one encrypted archive)" : page.target
            AxButton { icon: "description"; text: "File"; anchors.verticalCenter: parent.verticalCenter; onClicked: filePick.open() }
            AxButton { icon: "folder"; text: "Folder"; anchors.verticalCenter: parent.verticalCenter; onClicked: dirPick.open() }
        }
        SRow {
            visible: page.target !== ""
            icon: "category"; title: "Format"
            desc: ({ "gpg-pass": "OpenPGP, unlocked by a passphrase — widely supported",
                     "gpg-key": "OpenPGP, only the holders of these keys can open it",
                     "openssl": "OpenSSL, AES/ChaCha20 with a passphrase (PBKDF2-SHA512)",
                     "age": "age, modern and simple, to a recipient's public key",
                     "7z": "A 7-Zip archive with AES-256 and encrypted file names" })[page.encFormats[encFmt.current][0]]
            AxSelect { id: encFmt; width: 220; anchors.verticalCenter: parent.verticalCenter
                       model: page.encFormats.map(f => f[1] + (page.encFmtOk(f) ? "" : "  — not installed")); current: 0 }
        }
        SRow {
            visible: page.target !== "" && page.encFormats[encFmt.current][0] === "gpg-pass"
            icon: "shield"; title: "Cipher"; desc: "Passphrase stretched with SHA-512 (65 million rounds)"
            AxSelect { id: gpgCipher; width: 180; anchors.verticalCenter: parent.verticalCenter; model: page.gpgCiphers.map(c => c[1]); current: 0 }
        }
        SRow {
            visible: page.target !== "" && page.encFormats[encFmt.current][0] === "openssl"
            icon: "shield"; title: "Cipher"; desc: "PBKDF2-SHA512, 200k rounds"
            AxSelect { id: sslCipherE; width: 180; anchors.verticalCenter: parent.verticalCenter
                       model: ["AES-256-CBC", "AES-256-CTR", "ChaCha20", "Camellia-256"]; current: 0 }
        }
        SRow {
            visible: page.target !== "" && page.encNeedsRecip
            icon: "group"; title: page.encFormats[encFmt.current][0] === "age" ? "Recipients (age public keys)" : "Recipients"
            desc: page.encFormats[encFmt.current][0] === "age" ? "One or more age1… keys, space or comma separated"
                                                              : "Key IDs, fingerprints or emails already in your keyring"
            AxField { id: recip; width: 320; placeholder: page.encFormats[encFmt.current][0] === "age" ? "age1… age1…" : "0xKEYID or name@example.com"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.target !== "" && page.encFormats[encFmt.current][0] === "gpg-key"
            icon: "draw"; title: "Also sign it"; desc: "Prove it came from you (uses your default GPG key)"
            AxSwitch { id: signSw; checked: false; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.target !== "" && page.encNeedsPw
            icon: "key"; title: "Passphrase"
            AxField { id: p1; width: 200; password: true; placeholder: "Passphrase"; anchors.verticalCenter: parent.verticalCenter }
            AxField { id: p2; width: 150; password: true; placeholder: "Again"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.target !== "" && page.encFormats[encFmt.current][0] === "7z"
            icon: "info"; dim: true; title: "7-Zip and the passphrase"
            desc: "Unlike the others, 7-Zip takes the passphrase as a program argument, so it is briefly visible to other logged-in users on a shared machine"
        }
        SRow {
            visible: page.target !== ""
            icon: "delete_forever"; title: "Shred the original"; desc: "Overwrite and delete the unencrypted copy afterwards"
            AxSwitch { id: shredSw; checked: false; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.target !== ""
            icon: "lock"; title: "Create the encrypted file"
            AxButton { text: page.busy === "enc" ? "Encrypting…" : "Encrypt"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                       enabled_: page.busy === "" && page.encFmtOk(page.encFormats[encFmt.current])
                                 && (!page.encNeedsPw || (p1.text.length >= 8 && p1.text === p2.text))
                                 && (!page.encNeedsRecip || recip.text.trim() !== "")
                       onClicked: page.encrypt() }
        }
    }

    // ── decrypt ────────────────────────────────────────────────────────────────
    property string fmt: ""             // detected: gpg | openssl | age | unknown
    property string inspect: ""
    property bool adv: false
    property string outDir: ""
    property string verify: ""
    readonly property var sslCiphers: ["aes-256-cbc", "aes-256-ctr", "aes-192-cbc", "aes-128-cbc", "chacha20", "camellia-256-cbc", "aria-256-cbc"]
    function detect(p) {
        page.fmt = ""; page.inspect = ""; page.verify = "";
        cmd.sh('mg=$(od -An -tx1 -N6 "$1" | tr -d " \\n"); case "$mg" in 377abcaf271c*) echo 7z; exit;; 504b0304*|504b0506*) echo zip; exit;; esac; '
             + 'h=$(head -c 32 "$1" | tr -d "\\000"); case "$h" in Salted__*) echo openssl;; age-encryption.org*) echo age;; "-----BEGIN AGE"*) echo age;; "-----BEGIN PGP"*) echo gpg;; *) '
             + 'gpg --batch --pinentry-mode cancel --list-packets "$1" 2>&1 | grep -q "enc packet" && echo gpg || { head -c 64 "$1" | base64 -d 2>/dev/null | head -c 8 | grep -q Salted__ && echo openssl-b64 || echo unknown; };; esac; command -v age >/dev/null && echo has-age', [p], (c, o) => {
            const l = o.split("\n"); page.fmt = l[0] || "unknown"; page.hasAge = l.indexOf("has-age") >= 0;
            if (page.fmt === "openssl-b64") { page.fmt = "openssl"; b64.checked = true; }
            const i = page.decMethods.indexOf(page.fmt); method.current = i >= 0 ? i : 0;
        });
    }
    readonly property var decMethods: ["auto", "gpg", "openssl"].concat(page.hasAge ? ["age"] : []).concat(page.has7z ? ["7z", "zip"] : [])
    readonly property var decLabels: ({ auto: "Auto", gpg: "GPG", openssl: "OpenSSL", age: "age", "7z": "7-Zip", zip: "Zip" })
    function doInspect() {
        page.inspect = "Reading…";
        if (page.fmt !== "gpg") { page.inspect = page.fmt === "openssl" ? "OpenSSL file (salted). Its cipher and settings aren't stored inside — pick the ones it was made with below." : page.fmt === "age" ? "age file. Decrypts with the passphrase or an identity (key) file." : "Unknown format."; return; }
        cmd.sh('gpg --batch --pinentry-mode cancel --list-packets "$1" 2>&1 | grep -E "enc packet|literal data|compressed packet|keyid" | head -n 8', [page.source], (c, o) => {
            const cipher = { "7": "AES-128", "8": "AES-192", "9": "AES-256", "10": "Twofish", "11": "Camellia-128", "12": "Camellia-192", "13": "Camellia-256", "3": "CAST5", "2": "3DES" };
            const hash = { "2": "SHA-1", "8": "SHA-256", "9": "SHA-384", "10": "SHA-512", "11": "SHA-224" };
            const out = [];
            let m;
            if ((m = /symkey enc packet: version \d+, cipher (\d+)(?:, aead \d+)?, s2k (\d+), hash (\d+)/.exec(o))) out.push("Passphrase-encrypted with " + (cipher[m[1]] || "cipher " + m[1]) + ", key stretched with " + (hash[m[3]] || "hash " + m[3]) + (m[2] === "3" ? " (iterated)" : ""));
            const keys = o.match(/keyid ([0-9A-F]{16})/g); if (keys) out.push("Encrypted to key" + (keys.length > 1 ? "s " : " ") + keys.map(k => k.slice(6)).join(", ") + " — decrypts with that key's passphrase");
            if (/compressed packet/.test(o)) out.push("Compressed inside");
            if ((m = /literal data packet:.*?name="([^"]*)"/.exec(o)) && m[1]) out.push("Original name: " + m[1]);
            page.inspect = out.join("\n") || o.trim().split("\n").slice(0, 3).join("\n");
        });
    }
    function decrypt() {
        const s = page.source, m = page.decMethods[method.current] || "auto", how = m === "auto" ? page.fmt : m;
        const dir = page.outDir || s.replace(/\/[^\/]*$/, "");
        let name = (outName.text.trim() || s.split("/").pop().replace(/\.(gpg|pgp|asc|enc|age)$/i, "")).replace(/\//g, "_");
        if (name === s.split("/").pop()) name += ".decrypted";
        const out = dir + "/" + name;
        const guard = overwrite.checked ? "" : '[ -e "$2" ] && { echo "$2 already exists — turn on overwrite or pick another name." >&2; exit 1; }; ';
        const after = rmSrc.checked ? ' && rm -f "$1"' : "";
        let body;
        if (how === "7z" || how === "zip") {
            // extract the archive into a folder next to it; 7z opens encrypted zip too
            const into = dir + "/" + s.split("/").pop().replace(/\.(7z|zip)$/i, "") + "-unpacked";
            body = 'IFS= read -r pw; Z=$(command -v 7z || command -v 7za); mkdir -p "$2"; "$Z" x -p"$pw" -y -o"$2" -- "$1" >/dev/null 2>&1 || { echo "Wrong passphrase, or not a readable archive." >&2; exit 1; }' + after;
            page.busy = "dec"; page.error = ""; page.notice = ""; page.verify = "";
            cmd.run(["bash", "-c", body, "bash", s, into], (c, o, e) => {
                page.busy = "";
                if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "Couldn't open the archive.";
                else { page.notice = "Unpacked into " + into; page.source = ""; }
            }, dp.text + "\n");
            dp.text = ""; return;
        }
        if (how === "openssl") {
            const md = ["sha512", "sha256", "sha1", "md5"][sslMd.current];
            const cph = page.sslCiphers[sslCipher.current];
            const a = b64.checked ? " -a" : "";
            // try the chosen iteration count, then the usual defaults, so a file made anywhere opens
            const iters = pbkdf.checked ? '"$3" 100000 200000 10000 600000' : "";
            body = guard + 'IFS= read -r pw; ok=0; for n in ' + (iters || '""') + '; do '
                 + (pbkdf.checked ? 'A="-pbkdf2 -iter $n"' : 'A=""') + '; '
                 + 'openssl enc -d -' + cph + ' $A -md ' + md + a + ' -in "$1" -out "$2" -pass fd:3 3< <(printf %s "$pw") 2>/dev/null && { ok=1; break; }; done; '
                 + '[ "$ok" = 1 ] || { rm -f "$2"; echo "Wrong passphrase or settings: OpenSSL couldn\'t decrypt it." >&2; exit 1; }' + after;
        }
        else if (how === "age")
            body = guard + (ageKey.text ? 'age -d -i "$3" -o "$2" "$1"' : 'echo "age needs an identity file for decrypting here (passphrase mode only works in a terminal)." >&2; exit 1') + after;
        else if (/\.tar\.gpg$/.test(s) && !outName.text.trim())
            body = 'IFS= read -r pw; mkdir -p "$4"; gpg --batch --status-fd 2 --pinentry-mode loopback --passphrase-fd 3 -d "$1" 3< <(printf %s "$pw") 2>/tmp/axs-gpg.$$ | tar -C "$4" -xf -; r=${PIPESTATUS[0]}; grep -o "GOODSIG.*\\|BADSIG.*" /tmp/axs-gpg.$$ >&2; rm -f /tmp/axs-gpg.$$; [ "$r" = 0 ] || { echo "Wrong passphrase, or not a GPG file." >&2; exit 1; }' + after;
        else
            body = guard + 'IFS= read -r pw; gpg --batch --yes --status-fd 2 --pinentry-mode loopback --passphrase-fd 3 -o "$2" -d "$1" 3< <(printf %s "$pw") 2>/tmp/axs-gpg.$$; r=$?; grep -o "GOODSIG.*\\|BADSIG.*" /tmp/axs-gpg.$$ | sed "s/^/sig: /"; rm -f /tmp/axs-gpg.$$; [ "$r" = 0 ] || { echo "Wrong passphrase, or not a GPG file." >&2; exit 1; }' + after;
        page.busy = "dec"; page.error = ""; page.notice = ""; page.verify = "";
        cmd.run(["bash", "-c", body, "bash", s, out, how === "age" ? ageKey.text : iter.text, dir], (c, o, e) => {
            page.busy = "";
            const sig = /(GOODSIG|BADSIG)\s+\S+\s+(.*)/.exec(o + "\n" + e);
            if (sig) page.verify = sig[1] === "GOODSIG" ? "Signed by " + sig[2] + " — signature is good" : "Signature from " + sig[2] + " is BAD — the file was changed";
            if (c !== 0) page.error = (e || o).trim().split("\n").filter(l => !/SIG/.test(l)).pop() || "Couldn't decrypt it.";
            else { page.notice = "Decrypted to " + (/\.tar\.gpg$/.test(s) && !outName.text.trim() ? dir : out); page.source = ""; }
        }, how === "age" ? undefined : dp.text + "\n");
        dp.text = "";
    }
    FilePick { id: outPick; title: "Where to save the decrypted file"; pickFolder: true; folder: page.home; onPicked: (p) => page.outDir = p }
    FilePick { id: keyPick; title: "Choose an age identity (key) file"; folder: page.home; onPicked: (p) => ageKey.text = p }

    Section {
        title: "Decrypt"
        note: page.fmt !== "" ? page.fmt.toUpperCase() : ""
        SRow {
            icon: "lock_open"; title: page.source === "" ? "Choose an encrypted file" : page.source.split("/").pop()
            desc: page.source === "" ? "GPG (.gpg .asc .pgp, and .tar.gpg folders), OpenSSL (.enc) and age (.age) are recognised" : page.source
            AxButton { visible: page.source !== ""; icon: "manage_search"; text: "Inspect"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.doInspect() }
            AxButton { text: "Choose…"; anchors.verticalCenter: parent.verticalCenter; onClicked: gpgPick.open() }
        }
        Label {
            visible: page.inspect !== ""
            x: Ax.pad + 46; width: parent.width - 2 * Ax.pad - 46; bottomPadding: 12
            mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; wrapMode: Text.WordWrap; text: page.inspect
        }
        SRow {
            visible: page.source !== ""
            icon: "key"; title: "Passphrase"; desc: page.fmt === "gpg" ? "Or your key's passphrase, if it was encrypted to your key" : ""
            AxField { id: dp; width: 220; password: true; placeholder: "Passphrase"; anchors.verticalCenter: parent.verticalCenter; onAccepted: if (dp.text !== "") page.decrypt() }
            AxButton { text: page.busy === "dec" ? "Decrypting…" : "Decrypt"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                       enabled_: page.busy === "" && (dp.text !== "" || page.decMethods[method.current] === "age"); onClicked: page.decrypt() }
        }
        SRow {
            visible: page.verify !== ""
            icon: /BAD/.test(page.verify) ? "gpp_bad" : "verified"; title: page.verify
        }
        SRow {
            visible: page.source !== ""
            icon: "tune"; title: "Advanced options"; clickable: true; onClicked: page.adv = !page.adv
            Icon { name: page.adv ? "expand_less" : "expand_more"; size: 20; color: Ax.faint; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.source !== "" && page.adv
            icon: "category"; title: "Format"; desc: "Auto uses what the file looks like"
            AxSelect { id: method; width: 180; anchors.verticalCenter: parent.verticalCenter
                       model: page.decMethods.map(k => page.decLabels[k]); current: 0 }
        }
        SRow {
            visible: page.source !== "" && page.adv && (method.current === 2 || (method.current === 0 && page.fmt === "openssl"))
            icon: "shield"; title: "OpenSSL cipher"
            AxSelect { id: sslCipher; width: 180; anchors.verticalCenter: parent.verticalCenter; model: page.sslCiphers; current: 0 }
        }
        SRow {
            visible: page.source !== "" && page.adv && (method.current === 2 || (method.current === 0 && page.fmt === "openssl"))
            icon: "memory"; title: "Key derivation"; desc: "PBKDF2 with this many iterations, and the digest it used"
            AxSwitch { id: pbkdf; checked: true; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
            AxField { id: iter; width: 90; text: "10000"; anchors.verticalCenter: parent.verticalCenter }
            AxSelect { id: sslMd; width: 110; anchors.verticalCenter: parent.verticalCenter; model: ["SHA-256", "SHA-512", "SHA-1", "MD5"]; current: 0 }
        }
        SRow {
            visible: page.source !== "" && page.adv && (method.current === 2 || (method.current === 0 && page.fmt === "openssl"))
            icon: "text_fields"; title: "Base64 (ASCII) input"
            AxSwitch { id: b64; checked: false; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.source !== "" && page.adv && (method.current === 3 || (method.current === 0 && page.fmt === "age"))
            icon: "badge"; title: "age identity file"
            AxField { id: ageKey; width: 260; placeholder: "~/.config/age/key.txt"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "folder_open"; anchors.verticalCenter: parent.verticalCenter; onClicked: keyPick.open() }
        }
        SRow {
            visible: page.source !== "" && page.adv
            icon: "drive_file_move"; title: "Save to"; desc: page.outDir || "Next to the encrypted file"
            AxField { id: outName; width: 180; placeholder: "Same name"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "folder_open"; anchors.verticalCenter: parent.verticalCenter; onClicked: outPick.open() }
        }
        SRow {
            visible: page.source !== "" && page.adv
            icon: "edit_document"; title: "Overwrite if it exists"
            AxSwitch { id: overwrite; checked: false; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: page.source !== "" && page.adv
            icon: "delete"; title: "Delete the encrypted file afterwards"
            AxSwitch { id: rmSrc; checked: false; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Section {
        title: "Vaults"
        note: "gocryptfs"
        EmptyState { visible: !page.hasVaults; icon: "inventory_2"; title: "gocryptfs isn't installed"; desc: "Install it with  sudo pacman -S gocryptfs  to use vaults." }
        Repeater {
            model: page.hasVaults ? Store.data.vaults : []
            delegate: Column {
                id: v
                required property var modelData
                required property int index
                property bool topDivider: false
                readonly property bool isOpen: !!page.mounted[modelData.mount]
                width: parent.width
                SRow {
                    topDivider: v.topDivider
                    icon: v.isOpen ? "lock_open" : "lock"; title: v.modelData.name
                    desc: v.isOpen ? "Open at " + v.modelData.mount : "Locked  ·  data in " + v.modelData.cipher
                    AxButton { visible: v.isOpen; icon: "folder_open"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["xdg-open", v.modelData.mount]) }
                    AxButton { visible: v.isOpen; text: "Lock"; anchors.verticalCenter: parent.verticalCenter
                               onClicked: page.run("v", 'fusermount3 -u "$1" 2>/dev/null || fusermount -u "$1"', [v.modelData.mount], undefined, v.modelData.name + " locked.") }
                    AxButton { visible: !v.isOpen; icon: "close"; anchors.verticalCenter: parent.verticalCenter
                               onClicked: { const l = Store.data.vaults.slice(); l.splice(v.index, 1); Store.data.vaults = l; } }
                }
                Row {
                    visible: !v.isOpen
                    x: Ax.pad + 46; spacing: 8; bottomPadding: 14
                    AxField { id: vp; width: 220; password: true; icon: "key"; placeholder: "Passphrase"; onAccepted: vo.clicked() }
                    AxButton { id: vo; text: "Unlock"; kind: "primary"; enabled_: vp.text !== "" && page.busy === ""
                               onClicked: { page.run("v", 'mkdir -p "$2" && gocryptfs -q -passfile /dev/stdin "$1" "$2"', [v.modelData.cipher, v.modelData.mount], vp.text + "\n", v.modelData.name + " is open."); vp.text = ""; } }
                }
            }
        }
        Item {
            visible: page.hasVaults
            property bool topDivider: false
            width: parent.width; height: nv.implicitHeight + 32
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: nv
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad; spacing: 10
                Label { text: "New vault"; font.weight: Font.Medium }
                Row {
                    spacing: 8
                    AxField { id: vName; width: 150; placeholder: "Name"; text: "Private" }
                    AxField { id: vaultDir; width: 280; placeholder: "Folder for the encrypted data"; text: page.home + "/.vaults/private" }
                    AxButton { icon: "folder_open"; onClicked: vaultPick.open() }
                    AxSelect { id: vCipher; width: 170; model: ["AES-256-GCM", "XChaCha20-Poly1305"]; current: 0 }
                }
                Row {
                    spacing: 8
                    AxField { id: n1; width: 200; password: true; icon: "key"; placeholder: "Passphrase (8+)" }
                    AxField { id: n2; width: 150; password: true; placeholder: "Again" }
                    AxButton {
                        text: "Create vault"; kind: "primary"
                        enabled_: page.busy === "" && /^[A-Za-z0-9 _.-]{1,32}$/.test(vName.text) && vaultDir.text.startsWith("/") && n1.text.length >= 8 && n1.text === n2.text
                        onClicked: {
                            const mount = page.home + "/Vaults/" + vName.text, data = vaultDir.text, name = vName.text;
                            page.run("new", 'mkdir -p "$1" && [ -z "$(ls -A "$1")" ] || { echo "Pick an empty folder for the vault data." >&2; exit 1; }; gocryptfs -q -init ' + (vCipher.current ? "-xchacha " : "") + '-passfile /dev/stdin "$1" >/dev/null',
                                     [data], n1.text + "\n", "Vault created. Unlock it to start using it.",
                                     () => { Store.data.vaults = Store.data.vaults.concat([{ name: name, cipher: data, mount: mount }]); });
                            n1.text = ""; n2.text = "";
                        }
                    }
                }
                Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.muted; font.pixelSize: Ax.fsSmall
                        text: "Unlocked vaults open under ~/Vaults/. The encrypted data folder is safe to sync to any cloud — it's unreadable without the passphrase, and there's no way to recover it if the passphrase is lost." }
            }
        }
    }
}

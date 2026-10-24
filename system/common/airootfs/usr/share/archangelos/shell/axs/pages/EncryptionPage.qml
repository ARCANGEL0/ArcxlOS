// Encryption — encrypted disks (details, passphrases, header backup), USB drives (unlock, lock,
// encrypt), and the way to files, vaults, checksums and the advanced defaults.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Encryption"
    desc: "Keep disks, drives and files unreadable to anyone without the key."

    readonly property string sec: "/usr/lib/archangelos/axs-sec"
    property var devs: []              // every block device, flattened
    property string rootSrc: ""
    property bool loaded: false
    property string open_: ""          // device whose drawer is open
    property string mode: ""           // "info" | "add" | "remove" | "unlock" | "encrypt"
    property string info: ""
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    function flat(list, parent, disk) {
        let out = [];
        for (const d of list || []) {
            const dk = d.type === "disk" ? d : disk;
            out.push(Object.assign({}, d, { parentPath: parent ? parent.path : "", disk: dk ? dk.path : "", removable: dk ? (dk.rm || dk.hotplug) : false, model: dk ? (dk.model || "") : "" }));
            out = out.concat(page.flat(d.children, d, dk));
        }
        return out;
    }
    function load() {
        cmd.sh('lsblk -J -b -o NAME,PATH,TYPE,FSTYPE,MOUNTPOINT,SIZE,LABEL,RM,HOTPLUG,MODEL 2>/dev/null; echo "--root"; findmnt -no SOURCE / 2>/dev/null', [], (c, o) => {
            const [j, r] = o.split("--root");
            try { page.devs = page.flat(JSON.parse(j).blockdevices, null, null); } catch (e) { page.devs = []; }
            page.rootSrc = (r || "").trim(); page.loaded = true;
        });
    }
    Component.onCompleted: load()
    function human(b) { b = +b || 0; const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0; while (b >= 1000 && i < 4) { b /= 1000; i++; } return (i ? b.toFixed(b >= 100 ? 0 : 1) : b) + " " + u[i]; }
    readonly property var luks: devs.filter(d => d.fstype === "crypto_LUKS")
    function opened(d) { return page.devs.find(x => x.parentPath === d.path && x.type === "crypt") ?? null; }
    readonly property bool rootEncrypted: { const m = page.devs.find(x => x.path === page.rootSrc || ("/dev/mapper/" + x.name) === page.rootSrc); return !!m && m.type === "crypt"; }
    readonly property var usbParts: devs.filter(d => d.removable && (d.type === "part" || (d.type === "disk" && d.fstype)) && d.fstype !== "")
    function drawer(path, m) { page.error = ""; page.notice = ""; if (page.open_ === path && page.mode === m) { page.open_ = ""; page.mode = ""; } else { page.open_ = path; page.mode = m; } }
    function run(what, argv, input, ok) {
        page.busy = what; page.error = "";
        cmd.run(argv, (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim().split("\n").pop() || "That didn't work.";
            else { if (ok) page.notice = ok; page.open_ = ""; page.mode = ""; }
            page.load();
        }, input);
    }
    function details(d) {
        page.drawer(d.path, "info"); page.info = "Reading…";
        cmd.run([page.sec, "luks-info", d.path], (c, o) => {
            if (c !== 0) { page.info = ""; return; }
            const g = (re) => { const m = re.exec(o); return m ? m[1] : "—"; };
            const slots = (o.match(/^\s+\d+: luks2/mg) || []).length;
            page.info = "LUKS" + g(/^Version:\s+(\d+)/m) + "  ·  " + g(/cipher:\s+(\S+)/) + "  ·  " + g(/Cipher key:\s+(\d+ bits)/)
                      + "\nKey derivation " + g(/PBKDF:\s+(\S+)/) + "  ·  hash " + g(/Hash:\s+(\S+)/) + "  ·  " + slots + (slots === 1 ? " passphrase" : " passphrases");
        });
    }
    FilePick {
        id: headerPick
        property string dev: ""
        title: "Save the header backup"; save: true; filters: ["LUKS header (*.img)"]
        folder: Quickshell.env("HOME"); suggested: "luks-header.img"
        onPicked: (p) => page.run("hdr", [page.sec, "luks-header", dev, p], undefined, "Header saved to " + p + ". Keep it somewhere safe — with it and a passphrase the volume can be rescued.")
    }

    // ── status ─────────────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width; height: 120
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: page.rootEncrypted ? Ax.alpha(Ax.accent, 0.35) : Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Row {
            x: 28; anchors.verticalCenter: parent.verticalCenter; spacing: 20
            Rectangle { width: 56; height: 56; radius: 14; color: page.rootEncrypted ? Ax.accentSoft : Ax.raised; border.width: 1; border.color: page.rootEncrypted ? Ax.accentLine : Ax.border
                        Icon { anchors.centerIn: parent; name: page.rootEncrypted ? "enhanced_encryption" : "no_encryption"; size: 28; color: page.rootEncrypted ? Ax.accent : Ax.subtext } }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 5
                Label { caption: true; text: "System drive" }
                Label { font.pixelSize: 22; font.weight: Font.DemiBold; text: !page.loaded ? "Checking…" : page.rootEncrypted ? "Encrypted" : "Not encrypted" }
                Label { color: Ax.subtext; font.pixelSize: Ax.fsSmall; width: 640; wrapMode: Text.WordWrap
                        text: page.rootEncrypted ? "Without your passphrase the disk is unreadable, even if it's taken out of the computer."
                            : "Encrypting a running system in place isn't safe. Choose \"Encrypt the disk\" in the ArchangelOS installer when you next install." }
            }
        }
    }

    Label { visible: page.error !== "" || page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
            color: page.error !== "" ? Ax.danger : Ax.ok; text: page.error || page.notice }

    // ── encrypted volumes ──────────────────────────────────────────────────────
    Section {
        visible: page.luks.some(d => !d.removable)
        title: "Encrypted volumes"
        Repeater {
            model: page.luks.filter(d => !d.removable)
            delegate: Column {
                id: vol
                required property var modelData
                property bool topDivider: false
                readonly property bool here: page.open_ === modelData.path
                width: parent.width
                SRow {
                    topDivider: vol.topDivider
                    icon: page.opened(vol.modelData) ? "lock_open" : "lock"
                    title: (vol.modelData.label || vol.modelData.name) + "  ·  " + page.human(vol.modelData.size)
                    desc: vol.modelData.path + (page.opened(vol.modelData) && page.opened(vol.modelData).path === page.rootSrc ? "  ·  holds the system" : page.opened(vol.modelData) ? "  ·  unlocked" : "  ·  locked")
                    AxButton { text: "Details"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.details(vol.modelData) }
                    AxButton { icon: "key"; text: "Passphrases"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.drawer(vol.modelData.path, "add") }
                    AxButton { icon: "save"; anchors.verticalCenter: parent.verticalCenter; onClicked: { headerPick.dev = vol.modelData.path; headerPick.open(); } }
                }
                Label {
                    visible: vol.here && page.mode === "info"
                    x: Ax.pad + 46; width: parent.width - 2 * Ax.pad - 46; bottomPadding: 14
                    mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: page.info; wrapMode: Text.WordWrap
                }
                Column {
                    visible: vol.here && (page.mode === "add" || page.mode === "remove")
                    x: Ax.pad + 46; width: parent.width - 2 * Ax.pad - 46; spacing: 10; bottomPadding: 16
                    AxSegment { options: ["Add a passphrase", "Remove one"]; current: page.mode === "remove" ? 1 : 0; onPicked: (i) => page.mode = i ? "remove" : "add" }
                    Row {
                        spacing: 8
                        AxField { id: k1; width: 220; password: true; icon: "key"; placeholder: page.mode === "add" ? "A current passphrase" : "Passphrase to remove" }
                        AxField { id: k2; visible: page.mode === "add"; width: 200; password: true; icon: "add"; placeholder: "New passphrase" }
                        AxField { id: k3; visible: page.mode === "add"; width: 160; password: true; placeholder: "Again" }
                        AxButton {
                            text: page.mode === "add" ? "Add" : "Remove"; kind: page.mode === "add" ? "primary" : "danger"
                            enabled_: page.busy === "" && k1.text !== "" && (page.mode === "remove" || (k2.text.length >= 8 && k2.text === k3.text))
                            onClicked: {
                                if (page.mode === "add") page.run("key", [page.sec, "luks-addkey", vol.modelData.path], k1.text + "\n" + k2.text + "\n", "Passphrase added.");
                                else page.run("key", [page.sec, "luks-removekey", vol.modelData.path], k1.text + "\n", "Passphrase removed.");
                                k1.text = ""; k2.text = ""; k3.text = "";
                            }
                        }
                    }
                }
            }
        }
    }

    // ── usb drives ─────────────────────────────────────────────────────────────
    Section {
        title: "USB drives"
        EmptyState { visible: page.usbParts.length === 0; icon: "usb"; title: "No USB drives plugged in"; desc: "Plug one in to encrypt it, or to unlock one you encrypted before." }
        Repeater {
            model: page.usbParts
            delegate: Column {
                id: drv
                required property var modelData
                property bool topDivider: false
                readonly property bool isLuks: modelData.fstype === "crypto_LUKS"
                readonly property var clear: page.opened(modelData)
                readonly property bool here: page.open_ === modelData.path
                width: parent.width
                SRow {
                    topDivider: drv.topDivider
                    icon: drv.isLuks ? (drv.clear ? "lock_open" : "lock") : "usb"
                    title: (drv.modelData.label || drv.modelData.model || drv.modelData.name) + "  ·  " + page.human(drv.modelData.size)
                    desc: drv.modelData.path + "  ·  " + (drv.isLuks ? (drv.clear ? "encrypted, unlocked" + (drv.clear.mountpoint ? " at " + drv.clear.mountpoint : "") : "encrypted, locked") : (drv.modelData.fstype || "no filesystem") + ", not encrypted")
                    AxButton { visible: drv.isLuks && !drv.clear; text: "Unlock"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.drawer(drv.modelData.path, "unlock") }
                    AxButton { visible: drv.isLuks && !!drv.clear; text: "Lock"; anchors.verticalCenter: parent.verticalCenter
                               onClicked: page.run("lock", ["sh", "-c", 'udisksctl unmount -b "$1" >/dev/null 2>&1; udisksctl lock -b "$2"', "sh", drv.clear.path, drv.modelData.path], undefined, "Locked — safe to unplug.") }
                    AxButton { visible: !drv.isLuks; icon: "enhanced_encryption"; text: "Encrypt…"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.drawer(drv.modelData.path, "encrypt") }
                }
                Row {
                    visible: drv.here && page.mode === "unlock"
                    x: Ax.pad + 46; spacing: 8; bottomPadding: 16
                    AxField { id: up; width: 260; password: true; icon: "key"; placeholder: "Passphrase"; onAccepted: ub.clicked() }
                    AxButton { id: ub; text: "Unlock and open"; kind: "primary"; enabled_: up.text !== "" && page.busy === ""
                               onClicked: { page.run("unlock", ["sh", "-c", 'o=$(udisksctl unlock -b "$1" --key-file /dev/stdin) || exit 1; d=$(printf %s "$o" | grep -o "/dev/dm-[0-9]*" | head -n1); [ -n "$d" ] && udisksctl mount -b "$d" >/dev/null', "sh", drv.modelData.path], up.text, "Unlocked."); up.text = ""; } }
                }
                Column {
                    visible: drv.here && page.mode === "encrypt"
                    x: Ax.pad + 46; width: parent.width - 2 * Ax.pad - 46; spacing: 10; bottomPadding: 16
                    Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.danger; font.pixelSize: Ax.fsSmall
                            text: "Everything on " + drv.modelData.path + " will be erased. The drive is then encrypted with " + Store.data.luksCipher.split("-")[0].toUpperCase()
                                + " " + Store.data.luksKeyBits + "-bit, " + Store.data.luksHash + ", " + Store.data.luksPbkdf + " (change in Advanced)." }
                    Row {
                        spacing: 8
                        AxField { id: lab; width: 140; placeholder: "Label"; text: "secure" }
                        AxSelect { id: fsSel; width: 230; model: ["exFAT — works everywhere", "ext4 — Linux only", "btrfs — Linux only"]; current: 0 }
                    }
                    Row {
                        spacing: 8
                        AxField { id: e1; width: 200; password: true; icon: "key"; placeholder: "Passphrase (8+)" }
                        AxField { id: e2; width: 160; password: true; placeholder: "Again" }
                        AxField { id: conf; width: 170; placeholder: "Type " + drv.modelData.name + " to confirm" }
                        AxButton {
                            text: page.busy === "fmt" ? "Encrypting…" : "Erase and encrypt"; kind: "danger"
                            enabled_: page.busy === "" && e1.text.length >= 8 && e1.text === e2.text && conf.text === drv.modelData.name
                            onClicked: { page.run("fmt", [page.sec, "luks-format", drv.modelData.path, Store.data.luksCipher, String(Store.data.luksKeyBits), Store.data.luksHash,
                                                          Store.data.luksPbkdf, ["exfat", "ext4", "btrfs"][fsSel.current], lab.text], e1.text + "\n", "Encrypted. Unlock it to use it.");
                                         e1.text = ""; e2.text = ""; conf.text = ""; }
                        }
                    }
                }
            }
        }
    }

    Section {
        title: "More"
        SRow { icon: "folder_zip"; title: "Files, folders & vaults"; desc: "Encrypt single files, whole folders, or keep an encrypted vault folder"
               clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("encryption-files") }
        SRow { icon: "fingerprint"; title: "Checksums"; desc: "MD5, SHA-1, SHA-2, SHA-3 and BLAKE2 hashes of any file, and compare them"
               clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("encryption-hash") }
        SRow { icon: "construction"; title: "Crypto toolkit"; desc: "Encode and decode text, hash it, encrypt a short message, make passwords, keys and secrets"
               clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("toolkit") }
        SRow { icon: "tune"; title: "Advanced"; desc: "Ciphers and key derivation for new drives, password hashing, GPG keys"
               clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("encryption-advanced") }
    }
}

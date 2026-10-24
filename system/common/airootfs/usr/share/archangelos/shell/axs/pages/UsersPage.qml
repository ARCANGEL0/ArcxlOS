// Users & Accounts — your picture, name and password; other people on this computer; adding one.
// Account changes go through /usr/lib/archangelos/axs-admin, which asks for your password.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import "../../frame" as Frame

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Users & Accounts"
    desc: "Who can sign in to this computer, and what they're allowed to change."

    readonly property string me: Quickshell.env("USER") || (Quickshell.env("HOME") || "").split("/").pop()
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    property var users: []            // { name, uid, full, home, admin, online }
    property string busy: ""
    property string error: ""
    property string notice: ""
    property string open_: ""         // user whose options are expanded
    property int faceRev: 0
    readonly property var self: users.find(u => u.name === me) ?? null

    Cmd { id: cmd }
    function load() {
        cmd.sh('getent passwd | awk -F: \'$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1":"$3":"$5":"$6}\'; '
             + 'echo "--wheel:$(getent group wheel | cut -d: -f4)"; echo "--online:$(loginctl list-users --no-legend 2>/dev/null | awk \'{print $2}\' | paste -sd,)"',
            [], (c, out) => {
                let wheel = [], online = [];
                const list = [];
                for (const l of out.split("\n")) {
                    if (l.startsWith("--wheel:")) wheel = l.slice(8).split(",");
                    else if (l.startsWith("--online:")) online = l.slice(9).split(",");
                    else if (l.trim()) { const f = l.split(":"); list.push({ name: f[0], uid: +f[1], full: (f[2] || "").split(",")[0], home: f[3] }); }
                }
                for (const u of list) { u.admin = wheel.indexOf(u.name) >= 0; u.online = online.indexOf(u.name) >= 0; }
                page.users = list.sort((a, b) => (b.name === page.me) - (a.name === page.me) || a.uid - b.uid);
            });
    }
    Component.onCompleted: load()

    function run(what, args, input, okText) {
        page.busy = what; page.error = ""; page.notice = "";
        cmd.run([page.admin].concat(args), (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim() || "That didn't work.";
            else { page.notice = okText || ""; page.load(); }
        }, input);
    }
    function initial(u) { return ((u.full || u.name)[0] || "?").toUpperCase(); }
    function slug(full) { return full.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "").slice(0, 24); }

    FilePick {
        id: facePick
        title: "Choose a picture"
        filters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        folder: Quickshell.env("XDG_PICTURES_DIR") || (page.home + "/Pictures")
        onPicked: (p) => {
            cmd.sh('cp -f "$1" "$2/.face" && cp -f "$1" "$2/.face.icon"', [p, page.home], (c) => {
                if (c === 0) { Frame.PrefsService.customAvatarPath = page.home + "/.face"; page.faceRev++; }
                // and for the login screen, which can't read your home folder
                page.run("avatar", ["user-avatar", page.me, p], undefined, "Picture updated.");
            });
        }
    }

    component Avatar: Rectangle {
        property var user
        property int size: 40
        property bool mine: false
        width: size; height: size; radius: size / 2
        color: Ax.raised
        border.width: 1; border.color: Ax.accentLine
        clip: true
        Label { anchors.centerIn: parent; text: parent.user ? page.initial(parent.user) : ""; font.pixelSize: parent.size * 0.42; color: Ax.accent; visible: face.status !== Image.Ready }
        Image {
            id: face
            anchors.fill: parent; anchors.margins: 1
            source: !parent.user ? "" : parent.mine ? "file://" + (Frame.PrefsService.customAvatarPath || page.home + "/.face") + "?" + page.faceRev
                                                    : "file:///var/lib/AccountsService/icons/" + parent.user.name
            fillMode: Image.PreserveAspectCrop
            cache: false; asynchronous: true
            sourceSize.width: 256
            layer.enabled: false
        }
    }

    // ── you ────────────────────────────────────────────────────────────────────
    Rectangle {
        visible: page.self !== null
        width: parent.width; height: youCol.implicitHeight + 48
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Row {
            x: 28; y: 24
            spacing: 22
            Item {
                width: 88; height: 88
                Avatar { anchors.fill: parent; size: 88; user: page.self; mine: true }
                Rectangle {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    width: 28; height: 28; radius: 14; color: Ax.accent
                    Icon { anchors.centerIn: parent; name: "photo_camera"; size: 15; color: "#fbf8f3" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: facePick.open() }
                }
            }
            Column {
                id: youCol
                width: 520
                spacing: 6
                Label { caption: true; text: "Signed in" }
                Row {
                    spacing: 10
                    Label { text: page.self ? (page.self.full || page.self.name) : ""; font.pixelSize: 22; font.weight: Font.DemiBold; visible: !nameEdit.visible }
                    AxButton { icon: "edit"; visible: !nameEdit.visible; anchors.verticalCenter: parent.verticalCenter
                               onClicked: { nameField.text = page.self.full || ""; nameEdit.visible = true; nameField.focusIn(); } }
                    Row {
                        id: nameEdit
                        visible: false; spacing: 8
                        AxField { id: nameField; width: 240; placeholder: "Your full name"; onAccepted: saveName.clicked() }
                        AxButton { id: saveName; text: "Save"; kind: "primary"; enabled_: nameField.text.trim() !== ""
                                   onClicked: { nameEdit.visible = false; page.run("name", ["user-fullname", page.me, nameField.text.trim()], undefined, "Name updated."); } }
                        AxButton { text: "Cancel"; onClicked: nameEdit.visible = false }
                    }
                }
                Row {
                    spacing: 8
                    Label { mono: true; color: Ax.subtext; font.pixelSize: Ax.fsSmall; text: page.me + "  ·  " + page.home; anchors.verticalCenter: parent.verticalCenter }
                    Badge { visible: page.self && page.self.admin; text: "administrator"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                }
                Item { width: 1; height: 6 }
                Row {
                    spacing: 8
                    AxButton { icon: "photo_camera"; text: "Change picture"; onClicked: facePick.open() }
                    AxButton { icon: "password"; text: "Change password"; onClicked: { pwBox.who = page.me; pwBox.visible = !pwBox.visible || pwBox.who !== page.me; } }
                }
            }
        }
    }

    // password drawer, shared by you and others
    Rectangle {
        id: pwBox
        property string who: ""
        visible: false
        onVisibleChanged: { pw1.text = ""; pw2.text = ""; if (visible) pw1.focusIn(); }
        width: parent.width; height: 132
        radius: Ax.radius
        color: Ax.panel
        border.width: 1; border.color: Ax.accentLine
        Column {
            x: Ax.pad; y: 18; width: parent.width - 2 * Ax.pad
            spacing: 12
            Label { text: pwBox.who === page.me ? "New password" : "New password for " + pwBox.who; font.weight: Font.Medium }
            Row {
                spacing: 10
                AxField { id: pw1; width: 240; password: true; icon: "key"; placeholder: "New password" }
                AxField { id: pw2; width: 240; password: true; icon: "key"; placeholder: "Type it again"; onAccepted: pwGo.clicked() }
                AxButton { id: pwGo; text: "Change"; kind: "primary"; enabled_: pw1.text.length >= 1 && pw1.text === pw2.text
                           onClicked: { const w = pwBox.who, p = pw1.text; pwBox.visible = false; page.run("pw", ["user-passwd", w], p + "\n", "Password changed."); } }
                AxButton { text: "Cancel"; onClicked: pwBox.visible = false }
            }
            Label { font.pixelSize: Ax.fsSmall; color: pw2.text !== "" && pw1.text !== pw2.text ? Ax.danger : Ax.faint
                    text: pw2.text !== "" && pw1.text !== pw2.text ? "The two don't match." : pw1.text.length > 0 && pw1.text.length < 8 ? "Short passwords are easy to guess." : "You'll be asked for your current password to confirm." }
        }
    }

    Label {
        visible: page.error !== "" || page.notice !== ""
        width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
        color: page.error !== "" ? Ax.danger : Ax.ok
        text: page.error !== "" ? page.error : page.notice
    }

    // ── others ─────────────────────────────────────────────────────────────────
    Section {
        title: "Other people"
        note: page.users.length > 1 ? (page.users.length - 1) + "" : ""
        EmptyState { visible: page.users.filter(u => u.name !== page.me).length === 0; icon: "group"; title: "Only you so far"; desc: "Add an account below for someone else who uses this computer." }
        Repeater {
            model: page.users.filter(u => u.name !== page.me)
            delegate: Column {
                id: uc
                required property var modelData
                property bool topDivider: false
                readonly property bool open: page.open_ === modelData.name
                width: parent.width
                SRow {
                    topDivider: uc.topDivider
                    icon: uc.modelData.admin ? "shield_person" : "person"
                    title: uc.modelData.full || uc.modelData.name
                    desc: uc.modelData.name + "  ·  " + (uc.modelData.admin ? "Administrator" : "Standard") + (uc.modelData.online ? "  ·  signed in" : "")
                    clickable: true
                    onClicked: page.open_ = uc.open ? "" : uc.modelData.name
                    Icon { name: uc.open ? "expand_less" : "expand_more"; size: 20; color: Ax.faint; anchors.verticalCenter: parent.verticalCenter }
                }
                Item {
                    visible: uc.open
                    width: parent.width; height: 58
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Ax.pad
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Row { spacing: 8; anchors.verticalCenter: parent.verticalCenter
                              AxSwitch { checked: uc.modelData.admin; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                                         onToggled: (on) => page.run("admin", ["user-admin", uc.modelData.name, on ? "1" : "0"], undefined, on ? uc.modelData.name + " is now an administrator." : uc.modelData.name + " is now a standard user.") }
                              Label { text: "Administrator"; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter } }
                        Item { width: 12; height: 1 }
                        AxButton { icon: "password"; text: "Reset password"; onClicked: { pwBox.who = uc.modelData.name; pwBox.visible = true; } }
                        ConfirmButton { icon: "person_remove"; label: "Remove"; confirmText: "Remove and delete files"; enabled_: !uc.modelData.online
                                        onConfirmed: page.run("del", ["user-delete", uc.modelData.name, "0"], undefined, uc.modelData.name + " was removed.") }
                        ConfirmButton { icon: "folder_special"; label: "Remove, keep files"; confirmText: "Remove account"; enabled_: !uc.modelData.online
                                        onConfirmed: page.run("del", ["user-delete", uc.modelData.name, "1"], undefined, uc.modelData.name + " was removed; their files are still in " + uc.modelData.home + ".") }
                    }
                }
            }
        }
    }

    // ── add ────────────────────────────────────────────────────────────────────
    Section {
        title: "Add someone"
        Item {
            id: add
            property bool topDivider: false
            property string lastSlug: ""
            width: parent.width
            height: addCol.implicitHeight + 34
            readonly property bool nameOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(uname.text)
            readonly property bool taken: page.users.some(u => u.name === uname.text)
            Column {
                id: addCol
                x: Ax.pad; y: 18; width: parent.width - 2 * Ax.pad
                spacing: 12
                Row {
                    spacing: 10
                    // the user name follows the full name until it's edited by hand
                    AxField { id: full; width: 260; icon: "badge"; placeholder: "Full name"
                              onTextChanged: { const sl = page.slug(text); if (uname.text === "" || uname.text === add.lastSlug) uname.text = sl; add.lastSlug = sl; } }
                    AxField { id: uname; width: 200; icon: "alternate_email"; placeholder: "user name" }
                }
                Row {
                    spacing: 10
                    AxField { id: np1; width: 260; password: true; icon: "key"; placeholder: "Password" }
                    AxField { id: np2; width: 200; password: true; icon: "key"; placeholder: "Again" }
                }
                Row {
                    spacing: 10
                    AxSwitch { id: newAdmin; checked: false; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: "Administrator — can install apps and change system settings"; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 12
                    AxButton {
                        text: page.busy === "add" ? "Adding…" : "Add account"; icon: "person_add"; kind: "primary"
                        enabled_: page.busy === "" && add.nameOk && !add.taken && full.text.trim() !== "" && np1.text !== "" && np1.text === np2.text
                        onClicked: {
                            const n = uname.text;
                            page.run("add", ["user-add", n, full.text.trim(), newAdmin.checked ? "1" : "0"], np1.text + "\n", n + " can now sign in.");
                            full.text = ""; uname.text = ""; np1.text = ""; np2.text = ""; newAdmin.checked = false;
                        }
                    }
                    Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Ax.fsSmall; color: Ax.danger
                            text: uname.text !== "" && !add.nameOk ? "User names are lowercase letters, digits, - and _."
                                : add.taken ? "That user name is taken." : np2.text !== "" && np1.text !== np2.text ? "The passwords don't match." : "" }
                }
            }
        }
    }
}

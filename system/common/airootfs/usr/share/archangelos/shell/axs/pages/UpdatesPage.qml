// Updates — what's waiting from the Arch repositories, the AUR and Flatpak, and a way to install it.
// Checking uses checkupdates (a private copy of the sync database), so it never leaves the system
// half-updated; installing runs in a terminal so pacman's questions can be answered.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Updates"
    desc: "Keep ArchangelOS and your apps current."

    property var repo: []             // { name, from, to }
    property var aur: []
    property var flat: []
    property bool checking: false
    property bool checked: false
    property string lastCheck: ""
    property string lastUpgrade: ""
    property string version: ""
    property string note: ""
    readonly property int total: repo.length + aur.length + flat.length

    Cmd { id: cmd }
    FileView { path: "/etc/archangelos/version"; onLoaded: page.version = text().trim() }

    function parse(text) {
        return text.split("\n").map(l => /^(\S+)\s+(\S+)\s+->\s+(\S+)/.exec(l.trim())).filter(m => m).map(m => ({ name: m[1], from: m[2], to: m[3] }));
    }
    function check() {
        page.checking = true; page.note = "";
        cmd.sh('if command -v checkupdates >/dev/null; then checkupdates 2>/dev/null; else echo "!nocheck"; fi; echo "--aur"; '
             + 'for h in yay paru; do command -v $h >/dev/null && { $h -Qua 2>/dev/null; break; }; done; echo "--flatpak"; '
             + 'command -v flatpak >/dev/null && flatpak remote-ls --updates --columns=application,version 2>/dev/null; echo "--last"; '
             + 'grep -a "starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -n1 | sed -n "s/^\\[\\([^]]*\\)\\].*/\\1/p"', [], (c, out) => {
            const [r, rest1] = out.split("--aur");
            const [a, rest2] = (rest1 || "").split("--flatpak");
            const [f, last] = (rest2 || "").split("--last");
            if (r.indexOf("!nocheck") >= 0) page.note = "Install pacman-contrib to check the repositories safely.";
            page.repo = page.parse(r);
            page.aur = page.parse(a || "");
            page.flat = (f || "").split("\n").map(l => l.trim()).filter(l => l).map(l => { const p = l.split(/\t/); return { name: p[0], from: "", to: p[1] || "" }; });
            page.lastUpgrade = (last || "").trim();
            page.lastCheck = Qt.formatTime(new Date(), "HH:mm");
            page.checking = false; page.checked = true;
        });
    }
    Component.onCompleted: check()

    function when(iso) {
        if (!iso) return "never";
        const d = new Date(iso.replace(/([+-]\d\d)(\d\d)$/, "$1:$2"));
        if (isNaN(d)) return iso;
        const days = Math.floor((Date.now() - d.getTime()) / 86400000);
        return days <= 0 ? "today" : days === 1 ? "yesterday" : days + " days ago";
    }
    function install() {
        const steps = ["sudo pacman -Syu"];
        if (page.aur.length) steps.push("{ command -v yay >/dev/null && yay -Sua; } || { command -v paru >/dev/null && paru -Sua; }");
        if (page.flat.length) steps.push("flatpak update -y");
        const script = steps.join(" && ") + '; echo; read -rp "Finished. Press Enter to close. " _';
        Quickshell.execDetached(["sh", "-c",
            'for t in rio kitty foot alacritty; do command -v $t >/dev/null || continue; '
          + 'case $t in rio) exec rio -e bash -c "$1";; *) exec $t bash -c "$1";; esac; done', "sh", script]);
        relook.restart();
    }
    // Look again a little after the terminal opens, and again once it is likely done.
    Timer { id: relook; interval: 60000; onTriggered: page.check() }

    // ── status card ────────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width; height: 150
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: page.total > 0 ? Ax.alpha(Ax.accent, 0.35) : Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Column {
            x: 28; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { caption: true; text: "ArchangelOS" + (page.version ? "  ·  " + page.version : "") + "  ·  rolling" }
            Label { font.pixelSize: 26; font.weight: Font.DemiBold
                    text: page.checking && !page.checked ? "Checking…" : page.total === 0 ? "You're up to date" : page.total + (page.total === 1 ? " update" : " updates") + " ready" }
            Label { color: Ax.subtext; font.pixelSize: Ax.fsSmall
                    text: "Last full upgrade " + page.when(page.lastUpgrade) + (page.lastCheck ? "  ·  checked at " + page.lastCheck : "") }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            AxButton { icon: "refresh"; text: page.checking ? "Checking…" : "Check"; enabled_: !page.checking; onClicked: page.check() }
            AxButton { visible: page.total > 0; icon: "system_update_alt"; text: "Update now"; kind: "primary"; onClicked: page.install() }
        }
    }

    Label { visible: page.note !== ""; text: page.note; color: Ax.subtext; font.pixelSize: Ax.fsSmall }

    component UpdList: Section {
        id: ul
        property var items: []
        visible: items.length > 0
        note: items.length + ""
        Repeater {
            model: ul.items.slice(0, 80)
            SRow {
                required property var modelData
                title: modelData.name
                Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.faint; text: modelData.from; visible: modelData.from !== ""; anchors.verticalCenter: parent.verticalCenter }
                Icon { name: "arrow_forward"; size: 14; color: Ax.faint; visible: modelData.from !== ""; anchors.verticalCenter: parent.verticalCenter }
                Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.accent; text: modelData.to; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SRow { visible: ul.items.length > 80; title: "…and " + (ul.items.length - 80) + " more"; dim: true }
    }
    UpdList { title: "System & apps"; items: page.repo }
    UpdList { title: "AUR"; items: page.aur }
    UpdList { title: "Flatpak"; items: page.flat }

    Section {
        title: "Good to know"
        SRow { icon: "restart_alt"; title: "Restart after kernel updates"; desc: "A new kernel or graphics driver only takes over after a restart" }
        SRow { icon: "newspaper"; title: "Arch news"; desc: "Now and then an update needs a manual step; it's announced here first"
               clickable: true; chevron: true; onClicked: Qt.openUrlExternally("https://archlinux.org/news/") }
    }
}

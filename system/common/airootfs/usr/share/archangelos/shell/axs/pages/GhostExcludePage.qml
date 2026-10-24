// GhostWired › Excluded apps — apps that connect directly instead of through the tunnel.
// Excluding an app puts /usr/lib/archangelos/ghostwired-exempt in front of its launcher entry
// (a copy in ~/.local/share/applications), so it starts under the ghostwired-exempt group,
// which the GhostWired firewall lets through.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "GhostWired"
    title: "Excluded apps"
    desc: "These apps skip the tunnel and connect directly. Everything else still goes through Tor."

    readonly property string user: Quickshell.env("USER") || (Quickshell.env("HOME") || "").split("/").pop()
    readonly property string wrap: "/usr/lib/archangelos/ghostwired-exempt"
    readonly property string userApps: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/applications"
    readonly property string dirs: [page.userApps, "/usr/local/share/applications", "/usr/share/applications",
        Quickshell.env("HOME") + "/.local/share/flatpak/exports/share/applications", "/var/lib/flatpak/exports/share/applications"].join(":")
    property var ids: []
    property bool member: false
    property string error: ""
    readonly property var apps: (DesktopEntries.applications?.values ?? []).filter(e => !e.noDisplay)
        .slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""))

    Cmd { id: cmd }
    function load() {
        cmd.sh('for f in "$1"/*.desktop; do grep -qx "X-GhostWired-Exempt=true" "$f" 2>/dev/null && basename "$f" .desktop; done; '
             + 'echo "--member:$(getent group ghostwired-exempt | cut -d: -f4 | tr , "\\n" | grep -cx "$2")"', [page.userApps, page.user], (c, o) => {
            const lines = o.split("\n").filter(l => l);
            page.member = lines.some(l => l === "--member:1");
            page.ids = lines.filter(l => !l.startsWith("--member:"));
        });
    }
    Component.onCompleted: load()

    function exclude(e) {
        page.error = "";
        const go = () => cmd.sh(
            'u="$1"; id="$2"; w="$3"; IFS=:; mkdir -p "$u"; t="$u/$id.desktop"; '
          + 'if [ ! -f "$t" ]; then for d in $4; do [ -f "$d/$id.desktop" ] && { cp "$d/$id.desktop" "$t"; sed -i "/^\\[Desktop Entry\\]/a X-GhostWired-Created=true" "$t"; break; }; done; fi; '
          + '[ -f "$t" ] || exit 3; '
          + 'grep -q "^Exec=$w " "$t" || sed -i "s|^Exec=|Exec=$w |" "$t"; '
          + 'sed -i "/^DBusActivatable=/d" "$t"; '
          + 'grep -qx "X-GhostWired-Exempt=true" "$t" || sed -i "/^\\[Desktop Entry\\]/a X-GhostWired-Exempt=true" "$t"',
            [page.userApps, e.id, page.wrap, page.dirs], (c) => { if (c !== 0) page.error = "Couldn't find that app's launcher file."; page.load(); });
        // the group has to exist and include you before sg will run anything under it
        if (!page.member) Ghost.act("join", ["exempt-join", page.user], undefined, (ok) => { if (ok) go(); else page.load(); });
        else go();
    }
    function include(id) {
        cmd.sh('t="$1/$2.desktop"; [ -f "$t" ] || exit 0; '
             + 'if grep -qx "X-GhostWired-Created=true" "$t"; then rm -f "$t"; '
             + 'else sed -i -e "s|^Exec=$3 |Exec=|" -e "/^X-GhostWired-Exempt=true$/d" "$t"; fi',
            [page.userApps, id, page.wrap], () => page.load());
    }

    header: AxButton { icon: "arrow_back"; text: "GhostWired"; onClicked: NSS.Shell.openSettings("ghostwired") }

    Rectangle {
        width: parent.width; height: note.implicitHeight + 36
        radius: Ax.radius
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        Row {
            id: note
            x: 20; y: 18; width: parent.width - 40
            spacing: 14
            Icon { name: "info"; size: 20; color: Ax.accent }
            Label {
                width: parent.width - 34; wrapMode: Text.WordWrap; color: Ax.subtext; font.pixelSize: Ax.fsSmall
                text: "Excluded apps reach the internet with your real address, so sites they open can see who you are. "
                    + "The exclusion applies when the app is opened from the launcher; if it's already running, close it and open it again."
            }
        }
    }

    Label {
        visible: page.error !== "" || Ghost.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: page.error || Ghost.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
    }

    Section {
        title: "Excluded"
        note: page.ids.length ? page.ids.length + "" : ""
        EmptyState { visible: page.ids.length === 0; icon: "shield_lock"; title: "No exceptions"; desc: "Every app goes through Tor. Add one below to let it connect directly." }
        Repeater {
            model: page.ids
            SRow {
                required property string modelData
                readonly property var e: DesktopEntries.byId(modelData)
                title: e ? e.name : modelData
                desc: e ? (e.genericName || e.comment || "") : "Not installed any more"
                image: e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
                icon: image === "" ? "apps" : ""
                Badge { text: "direct"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { icon: "remove_circle_outline"; text: "Remove"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.include(modelData) }
            }
        }
        SRow {
            icon: "add"; title: "Exclude an app"
            AxSelect {
                width: 280; anchors.verticalCenter: parent.verticalCenter
                searchable: true; placeholder: "Choose an app…"
                readonly property var opts: page.apps.filter(a => page.ids.indexOf(a.id) < 0)
                model: opts.map(a => a.name); current: -1
                onPicked: (i) => page.exclude(opts[i])
            }
        }
    }
}

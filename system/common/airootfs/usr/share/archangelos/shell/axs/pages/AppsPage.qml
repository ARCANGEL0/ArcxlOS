// Apps — which app opens what, what starts with the desktop, and everything installed
// (open, see where it came from, uninstall).
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Apps"
    desc: "Default apps, startup apps and everything installed on this computer."

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dirs: [(Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/applications",
        "/usr/local/share/applications", "/usr/share/applications",
        home + "/.local/share/flatpak/exports/share/applications", "/var/lib/flatpak/exports/share/applications"].join(":")
    property string query: ""
    property string open_: ""
    property var pkgInfo: ({})        // id → { kind, pkg, version, size }
    property var defaults: []         // { key, label, icon, mimes, current, candidates[] }
    property var startup: []          // { id, name, enabled, user, system }
    property string error: ""
    property string busy: ""

    readonly property var apps: (DesktopEntries.applications?.values ?? [])
        .filter(e => !e.noDisplay)
        .slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    readonly property var shown: query === "" ? apps : apps.filter(e => ((e.name || "") + " " + (e.genericName || "") + " " + (e.comment || "") + " " + e.id).toLowerCase().includes(query.toLowerCase()))

    function entry(id) { return DesktopEntries.byId(String(id).replace(/\.desktop$/, "")); }
    function nameOf(id) { const e = page.entry(id); return e ? e.name : String(id).replace(/\.desktop$/, ""); }
    function iconOf(e) { return e && e.icon ? Quickshell.iconPath(e.icon, true) : ""; }

    Cmd { id: cmd }
    Cmd { id: lookup }

    // ── defaults ───────────────────────────────────────────────────────────────
    readonly property var cats: [
        { key: "web", label: "Web browser", icon: "language", mimes: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"] },
        { key: "files", label: "Files", icon: "folder", mimes: ["inode/directory"] },
        { key: "text", label: "Text editor", icon: "edit_note", mimes: ["text/plain"] },
        { key: "image", label: "Images", icon: "image", mimes: ["image/png", "image/jpeg", "image/webp", "image/gif"] },
        { key: "video", label: "Video", icon: "movie", mimes: ["video/mp4", "video/x-matroska", "video/webm"] },
        { key: "audio", label: "Music", icon: "music_note", mimes: ["audio/mpeg", "audio/flac", "audio/ogg"] },
        { key: "pdf", label: "PDF documents", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { key: "mail", label: "Email", icon: "mail", mimes: ["x-scheme-handler/mailto"] }
    ]
    function loadDefaults() {
        const script = 'IFS=:; dirs="$1"; shift; for spec in "$@"; do key=${spec%%=*}; mime=${spec#*=}; '
            + 'cur=$(xdg-mime query default "$mime" 2>/dev/null); '
            + 'cands=$(for d in $dirs; do [ -d "$d" ] && grep -l "^MimeType=.*$mime;" "$d"/*.desktop 2>/dev/null; done | xargs -r -n1 basename | sort -u | paste -sd,); '
            + 'echo "$key|$cur|$cands"; done';
        cmd.sh(script, [page.dirs].concat(page.cats.map(c => c.key + "=" + c.mimes[0])), (c, out) => {
            const m = {};
            for (const l of out.split("\n")) { const f = l.split("|"); if (f.length === 3) m[f[0]] = { current: f[1], candidates: f[2].split(",").filter(s => s) }; }
            page.defaults = page.cats.map(c => Object.assign({}, c, m[c.key] || { current: "", candidates: [] }));
        });
    }
    function setDefault(cat, id) {
        cmd.run(["xdg-mime", "default", id].concat(cat.mimes), () => {
            if (cat.key === "web") Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", id]);
            page.loadDefaults();
        });
    }

    // ── startup ────────────────────────────────────────────────────────────────
    function loadStartup() {
        const script = 'u="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"; '
            + 'for f in /etc/xdg/autostart/*.desktop "$u"/*.desktop; do [ -f "$f" ] || continue; id=$(basename "$f"); '
            + 'n=$(sed -n "s/^Name=//p" "$f" | head -n1); h=$(sed -n "s/^Hidden=//p" "$f" | head -n1); '
            + 'o=$(sed -n "s/^OnlyShowIn=//p" "$f" | head -n1); case "$f" in "$u"/*) w=user;; *) w=system;; esac; '
            + 'echo "$w|$id|$n|$h|$o"; done';
        cmd.sh(script, [], (c, out) => {
            const m = {};
            for (const l of out.split("\n")) {
                const f = l.split("|"); if (f.length < 5) continue;
                const it = m[f[1]] || { id: f[1], name: f[2], system: false, user: false, enabled: true, only: "" };
                if (f[0] === "system") { it.system = true; it.only = f[4]; if (!it.user) it.enabled = f[3] !== "true"; }
                else { it.user = true; it.name = f[2] || it.name; it.enabled = f[3] !== "true"; }
                m[f[1]] = it;
            }
            // Desktop-specific system entries (GNOME, KDE…) never run here; leave them out.
            page.startup = Object.values(m).filter(i => !i.only || /Hyprland|wlroots/i.test(i.only))
                .sort((a, b) => a.name.localeCompare(b.name));
        });
    }
    function setStartup(it, on) {
        const script = 'u="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"; f="$u/$1"; mkdir -p "$u"; '
            + 'if [ "$2" = 1 ]; then if [ -f "/etc/xdg/autostart/$1" ] && grep -q "^Hidden=true" "$f" 2>/dev/null && [ "$(grep -vc "^Hidden=" "$f")" = "$(grep -vc "^Hidden=" "/etc/xdg/autostart/$1")" ]; then rm -f "$f"; '
            + 'else sed -i "/^Hidden=/d" "$f"; fi; '
            + 'else [ -f "$f" ] || cp "/etc/xdg/autostart/$1" "$f"; sed -i "/^Hidden=/d" "$f"; sed -i "/^\\[Desktop Entry\\]/a Hidden=true" "$f"; fi';
        cmd.sh(script, [it.id, on ? "1" : "0"], () => page.loadStartup());
    }
    function addStartup(e) {
        const script = 'u="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"; mkdir -p "$u"; IFS=:; for d in $1; do '
            + '[ -f "$d/$2.desktop" ] && { cp "$d/$2.desktop" "$u/$2.desktop"; sed -i "/^Hidden=/d" "$u/$2.desktop"; break; }; done';
        cmd.sh(script, [page.dirs, e.id], () => page.loadStartup());
    }
    function removeStartup(it) {
        cmd.sh('rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/$1"', [it.id], () => page.loadStartup());
    }

    // ── packages ───────────────────────────────────────────────────────────────
    function lookupPkg(e) {
        if (page.pkgInfo[e.id]) return;
        const script = 'IFS=:; for d in $1; do f="$d/$2.desktop"; [ -f "$f" ] || continue; '
            + 'case "$f" in *flatpak*) echo "flatpak|$2|$(flatpak info "$2" 2>/dev/null | sed -n "s/^ *Version: //p" | head -n1)|"; exit;; esac; '
            + 'p=$(pacman -Qqo "$f" 2>/dev/null); [ -n "$p" ] && { LC_ALL=C pacman -Qi "$p" | awk -v p="$p" -F": " \'/^Version/{v=$2}/^Installed Size/{s=$2}END{print "pacman|"p"|"v"|"s}\'; exit; }; '
            + 'echo "local|$f||"; exit; done; echo "none|||"';
        lookup.sh(script, [page.dirs, e.id], (c, out) => {
            const f = out.trim().split("|");
            const o = Object.assign({}, page.pkgInfo); o[e.id] = { kind: f[0], pkg: f[1], version: f[2], size: f[3] }; page.pkgInfo = o;
        });
    }
    function uninstall(e) {
        const i = page.pkgInfo[e.id]; if (!i) return;
        page.busy = e.id; page.error = "";
        const argv = i.kind === "flatpak" ? ["flatpak", "uninstall", "-y", "--noninteractive", i.pkg]
                                          : ["/usr/lib/archangelos/axs-admin", "pkg-remove", i.pkg];
        cmd.run(argv, (c, o, er) => {
            page.busy = "";
            if (c !== 0) page.error = (er || o).trim().split("\n").slice(-3).join(" ") || "Couldn't uninstall it.";
            else { page.open_ = ""; const p = Object.assign({}, page.pkgInfo); delete p[e.id]; page.pkgInfo = p; }
        });
    }

    Component.onCompleted: { loadDefaults(); loadStartup(); }

    header: AxField { width: 240; icon: "search"; placeholder: "Find an app"; onTextChanged: page.query = text }

    Label {
        visible: page.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
    }

    Section {
        visible: page.query === ""
        title: "Default apps"
        Repeater {
            model: page.defaults
            SRow {
                required property var modelData
                icon: modelData.icon; title: modelData.label
                desc: modelData.candidates.length === 0 ? "No installed app handles this" : ""
                AxSelect {
                    width: 260; anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.candidates.length > 0
                    model: modelData.candidates.map(id => page.nameOf(id))
                    current: modelData.candidates.indexOf(modelData.current)
                    placeholder: "Not set"
                    onPicked: (i) => page.setDefault(modelData, modelData.candidates[i])
                }
            }
        }
    }

    Section {
        visible: page.query === ""
        title: "Startup apps"
        note: page.startup.filter(s => s.enabled).length + " on"
        EmptyState { visible: page.startup.length === 0; icon: "rocket_launch"; title: "Nothing starts with the desktop"; desc: "Add an app below to open it every time you sign in." }
        Repeater {
            model: page.startup
            SRow {
                required property var modelData
                readonly property var e: page.entry(modelData.id)
                title: modelData.name || modelData.id
                desc: modelData.system ? (modelData.user ? "System entry, changed by you" : "Started for everyone") : "Added by you"
                image: page.iconOf(e)
                icon: image === "" ? "rocket_launch" : ""
                AxButton { icon: "close"; visible: !modelData.system; anchors.verticalCenter: parent.verticalCenter; onClicked: page.removeStartup(modelData) }
                AxSwitch { checked: modelData.enabled; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.setStartup(modelData, on) }
            }
        }
        SRow {
            icon: "add"; title: "Add a startup app"
            AxSelect { width: 260; anchors.verticalCenter: parent.verticalCenter; searchable: true; placeholder: "Choose an app…"
                       readonly property var opts: page.apps.filter(a => !page.startup.some(s => s.id === a.id + ".desktop"))
                       model: opts.map(a => a.name); current: -1
                       onPicked: (i) => page.addStartup(opts[i]) }
        }
    }

    Section {
        title: page.query === "" ? "Installed" : "Results"
        note: page.shown.length + " apps"
        EmptyState { visible: page.shown.length === 0; icon: "search_off"; title: "No apps match “" + page.query + "”" }
        Repeater {
            model: page.shown
            delegate: Column {
                id: ac
                required property var modelData
                property bool topDivider: false
                readonly property bool open: page.open_ === modelData.id
                readonly property var info: page.pkgInfo[modelData.id] ?? null
                width: parent.width
                SRow {
                    topDivider: ac.topDivider
                    title: ac.modelData.name
                    desc: ac.modelData.genericName || ac.modelData.comment || ""
                    image: page.iconOf(ac.modelData)
                    icon: image === "" ? "apps" : ""
                    clickable: true
                    onClicked: { page.open_ = ac.open ? "" : ac.modelData.id; if (!ac.open) page.lookupPkg(ac.modelData); }
                    Icon { name: ac.open ? "expand_less" : "expand_more"; size: 20; color: Ax.faint; anchors.verticalCenter: parent.verticalCenter }
                }
                Item {
                    visible: ac.open
                    width: parent.width; height: 60
                    Label {
                        anchors.left: parent.left; anchors.leftMargin: Ax.pad
                        anchors.verticalCenter: parent.verticalCenter
                        mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext
                        text: !ac.info ? "Looking it up…"
                            : ac.info.kind === "pacman" ? ac.info.pkg + "  " + ac.info.version + "  ·  " + ac.info.size
                            : ac.info.kind === "flatpak" ? "Flatpak  ·  " + ac.info.pkg + (ac.info.version ? "  " + ac.info.version : "")
                            : ac.info.kind === "local" ? "Added by hand  ·  " + ac.info.pkg
                            : "Not from a package"
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: Ax.pad
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        AxButton { icon: "open_in_new"; text: "Open"; onClicked: ac.modelData.execute() }
                        ConfirmButton {
                            visible: ac.info && (ac.info.kind === "pacman" || ac.info.kind === "flatpak")
                            icon: "delete"; label: page.busy === ac.modelData.id ? "Removing…" : "Uninstall"
                            confirmText: "Uninstall " + (ac.info ? ac.info.pkg : "")
                            enabled_: page.busy === ""
                            onConfirmed: page.uninstall(ac.modelData)
                        }
                    }
                }
            }
        }
    }
}

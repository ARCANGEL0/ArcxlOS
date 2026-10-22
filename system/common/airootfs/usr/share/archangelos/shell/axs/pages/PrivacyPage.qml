// Privacy & history — the traces the desktop keeps (recent files, clipboard, thumbnails, shell
// history, trash): clear them now, or at every sign-in.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Privacy & history"
    desc: "What this computer remembers about what you do, and when it forgets."

    property var sizes: ({})
    property bool remember: true
    property string notice: ""
    Cmd { id: cmd }
    function load() {
        cmd.sh('d="${XDG_DATA_HOME:-$HOME/.local/share}"; c="${XDG_CACHE_HOME:-$HOME/.cache}"; '
             + 'echo "recent=$(grep -c "<bookmark " "$d/recently-used.xbel" 2>/dev/null || echo 0)"; '
             + 'echo "clip=$(cliphist list 2>/dev/null | wc -l)"; echo "thumbs=$(du -sh "$c/thumbnails" 2>/dev/null | cut -f1)"; '
             + 'echo "hist=$(cat "$HOME/.bash_history" "$HOME/.zsh_history" "$d/fish/fish_history" 2>/dev/null | wc -l)"; '
             + 'echo "trash=$(ls -A "$d/Trash/files" 2>/dev/null | wc -l)"; '
             + 'echo "remember=$(gsettings get org.gnome.desktop.privacy remember-recent-files 2>/dev/null)"', [], (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).trim(); }
            page.sizes = m; page.remember = m.remember !== "false";
        });
    }
    Component.onCompleted: load()
    function clear(what, label) { cmd.sh(Janitor.scripts[what], [], () => { page.notice = label + " cleared."; page.load(); }); }
    function setRemember(on) {
        cmd.sh('gsettings set org.gnome.desktop.privacy remember-recent-files "$1" 2>/dev/null; f="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"; mkdir -p "$(dirname "$f")"; '
             + '[ -f "$f" ] || printf "[Settings]\\n" > "$f"; sed -i "/^gtk-recent-files-/d" "$f"; '
             + '[ "$1" = false ] && sed -i "/^\\[Settings\\]/a gtk-recent-files-enabled=false\\ngtk-recent-files-max-age=0" "$f"; true', [on ? "true" : "false"], () => page.load());
    }

    Label { visible: page.notice !== ""; text: page.notice; color: Ax.ok; font.pixelSize: Ax.fsSmall }

    Section {
        title: "Remember"
        SRow {
            icon: "history"; title: "Remember recently used files"
            desc: page.remember ? "Apps list what you opened lately" : "Nothing is recorded"
            AxSwitch { checked: page.remember; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.setRemember(on) }
        }
    }

    Section {
        title: "Clear"
        note: "now, or at every sign-in"
        component Trace: SRow {
            id: tr
            property string key
            property string storeKey
            property string label
            AxButton { text: "Clear now"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.clear(tr.key, tr.label) }
            Row { spacing: 8; anchors.verticalCenter: parent.verticalCenter
                  Label { text: "At sign-in"; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
                  AxSwitch { checked: !!Store.data[tr.storeKey]; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => Store.data[tr.storeKey] = on } }
        }
        Trace { icon: "schedule"; title: "Recent files"; desc: (page.sizes.recent || "0") + " entries"; key: "recent"; storeKey: "clearRecent"; label: "Recent files" }
        Trace { icon: "content_paste"; title: "Clipboard history"; desc: (page.sizes.clip || "0") + " items"; key: "clipboard"; storeKey: "clearClipboard"; label: "Clipboard history" }
        Trace { icon: "photo_library"; title: "Thumbnail cache"; desc: (page.sizes.thumbs || "0") + " of previews"; key: "thumbs"; storeKey: "clearThumbs"; label: "Thumbnails" }
        Trace { icon: "terminal"; title: "Terminal history"; desc: (page.sizes.hist || "0") + " commands (bash, zsh, fish)"; key: "shell"; storeKey: "clearShellHistory"; label: "Terminal history" }
        SRow {
            icon: "delete"; title: "Empty old trash"; desc: (page.sizes.trash || "0") + " items in the trash"
            AxSelect { width: 180; anchors.verticalCenter: parent.verticalCenter
                       readonly property var days: [0, 7, 30, 90]
                       model: ["Keep until emptied", "After 7 days", "After 30 days", "After 90 days"]
                       current: Math.max(0, days.indexOf(Store.data.trashDays))
                       onPicked: (i) => Store.data.trashDays = days[i] }
        }
    }
}

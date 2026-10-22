// Clears the traces Privacy & history is told to, once per sign-in (the shell starts with the
// session), and empties trash older than the chosen number of days.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var scripts: ({
        recent: 'f="${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"; [ -f "$f" ] && printf "<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>\\n<xbel version=\\"1.0\\"/>\\n" > "$f"; true',
        clipboard: 'cliphist wipe 2>/dev/null; wl-copy --clear 2>/dev/null; true',
        thumbs: 'rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails"; true',
        shell: ': > "$HOME/.bash_history" 2>/dev/null; : > "$HOME/.zsh_history" 2>/dev/null; f="${XDG_DATA_HOME:-$HOME/.local/share}/fish/fish_history"; [ -f "$f" ] && : > "$f"; true'
    })
    function signIn() {
        const s = Store.data, parts = [];
        if (s.clearRecent) parts.push(root.scripts.recent);
        if (s.clearClipboard) parts.push(root.scripts.clipboard);
        if (s.clearThumbs) parts.push(root.scripts.thumbs);
        if (s.clearShellHistory) parts.push(root.scripts.shell);
        if (s.trashDays > 0)
            parts.push('t="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"; find "$t/info" -name "*.trashinfo" -mtime +' + s.trashDays
                     + ' 2>/dev/null | while read -r i; do n=$(basename "$i" .trashinfo); rm -rf "$t/files/$n" "$i"; done; true');
        if (parts.length) Quickshell.execDetached(["sh", "-c", parts.join("; ")]);
    }
    // the settings file loads asynchronously; give it a moment before reading the switches
    Timer { interval: 4000; running: true; onTriggered: root.signIn() }
}

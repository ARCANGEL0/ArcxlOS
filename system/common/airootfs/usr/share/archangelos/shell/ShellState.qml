pragma Singleton
import QtQuick
import Quickshell

// Which panel is poured out of the sidebar: "" (none) or "session".
Singleton {
    property string panel: ""
    // Last non-empty panel, so content can stay mounted while it flows closed.
    property string lastPanel: ""

    function open(p) { lastPanel = p; panel = p }
    function close() { panel = "" }
    function toggle(p) { if (panel === p) close(); else open(p) }

    // The app launcher is its own Quickshell overlay; this just toggles it.
    function openLauncher() {
        close()
        Quickshell.execDetached(["archangelos-launcher-toggle"])
    }
}

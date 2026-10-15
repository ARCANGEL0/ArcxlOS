pragma Singleton
import QtQuick
import Quickshell

// Which surface the notch is showing: "" (resting), "launcher", "session".
Singleton {
    property string panel: ""
    // Last non-empty panel, so content can stay mounted while the notch closes.
    property string lastPanel: ""

    function open(p) { lastPanel = p; panel = p }
    function close() { panel = "" }
    function toggle(p) { if (panel === p) close(); else open(p) }
}

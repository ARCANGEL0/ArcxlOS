//  ArchangelOS — animated region selector for screenshot / screen-record.
//  Quickshell layer-shell overlay: darkened field, drag a rectangle, and the
//  selected frame breathes dark "shadow flames". On confirm the chosen region
//  is written (as slurp-style "X,Y WxH") to $ARCHANGELOS_CAP_OUT and the
//  process quits; Esc cancels with no output. Spawned by /usr/bin/archangelos-region.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    // where to write the picked geometry ("X,Y WxH"); read by the wrapper script
    property string outPath: {
        var p = Quickshell.env("ARCHANGELOS_CAP_OUT")
        return (p && p.length > 0) ? p : "/tmp/archangelos-region.geom"
    }
    // "rec" tints the embers hotter red; anything else = screenshot (cool ember)
    property string mode: {
        var m = Quickshell.env("ARCHANGELOS_CAP_MODE")
        return (m && m.length > 0) ? m : "shot"
    }
    // debug/screenshot aid: pre-seed a selection ("x,y,w,h" local coords)
    property string demo: {
        var d = Quickshell.env("ARCHANGELOS_CAP_DEMO")
        return (d && d.length > 0) ? d : ""
    }

    property bool wrote: false
    // write "X,Y WxH" then quit; guarded so only the first confirm fires
    function confirm(gx, gy, gw, gh) {
        if (wrote) return
        if (gw < 4 || gh < 4) { Qt.quit(); return }   // treat a tap as a cancel
        wrote = true
        var geom = Math.round(gx) + "," + Math.round(gy) + " "
                 + Math.round(gw) + "x" + Math.round(gh)
        writeProc.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", geom, root.outPath]
        writeProc.running = true
    }
    function cancel() { Qt.quit() }
    Process {
        id: writeProc
        running: false
        onExited: Qt.quit()
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: true
            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "archangelos-capture"

            RegionSelect {
                anchors.fill: parent
                mode: root.mode
                demo: root.demo
                // this output's origin in global compositor space, so the
                // reported region is correct on multi-monitor layouts
                originX: modelData.x
                originY: modelData.y
                onPicked: (gx, gy, gw, gh) => root.confirm(gx, gy, gw, gh)
                onCancelled: root.cancel()
            }
        }
    }
}

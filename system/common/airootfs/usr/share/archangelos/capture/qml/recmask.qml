//  ArchangelOS — recording dim-mask overlay.
//  While wf-recorder is capturing a region, this paints a translucent scrim over
//  everything EXCEPT the recorded rectangle, so the capture area stays visible as
//  a live indicator. It is fully click-through (empty input mask) and sits on the
//  Wayland overlay layer. The recorded rect is read from ARCHANGELOS_REC_GEOM in
//  grim/slurp form ("X,Y WxH", global compositor coords). The accent border is
//  drawn just OUTSIDE the rect, so `wf-recorder -g` (region-only) never captures
//  either the dimming or the frame. Launched/killed by archangelos-screenrecord.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    // parse "X,Y WxH" → [x, y, w, h]; empty/malformed → null (mask hidden).
    readonly property var rec: {
        var s = Quickshell.env("ARCHANGELOS_REC_GEOM")
        if (!s || s.length === 0) return null
        var parts = ("" + s).trim().split(/\s+/)
        if (parts.length < 2) return null
        var xy = parts[0].split(","), wh = parts[1].split("x")
        if (xy.length < 2 || wh.length < 2) return null
        var x = parseInt(xy[0]), y = parseInt(xy[1])
        var w = parseInt(wh[0]), h = parseInt(wh[1])
        if (isNaN(x) || isNaN(y) || isNaN(w) || isNaN(h) || w <= 0 || h <= 0) return null
        return [x, y, w, h]
    }

    readonly property color dimColor: "#000000"
    readonly property real dimAlpha: 0.5
    readonly property color accent: "#c9a15a"

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "archangelos-recmask"
            // empty input region → the overlay never intercepts pointer/keyboard.
            mask: Region {}

            // region rect in this screen's local coordinates
            readonly property real rx: root.rec ? (root.rec[0] - modelData.x) : 0
            readonly property real ry: root.rec ? (root.rec[1] - modelData.y) : 0
            readonly property real rw: root.rec ? root.rec[2] : 0
            readonly property real rh: root.rec ? root.rec[3] : 0
            // does the recorded rect intersect this screen at all?
            readonly property bool hasRect: root.rec
                && rx < width && ry < height && (rx + rw) > 0 && (ry + rh) > 0

            // no rect on this screen → dim the whole output (it isn't recorded)
            Rectangle {
                anchors.fill: parent
                visible: !win.hasRect
                color: root.dimColor; opacity: root.dimAlpha
            }

            // four scrim panels framing the transparent capture rect
            Item {
                anchors.fill: parent
                visible: win.hasRect
                Rectangle {   // top
                    x: 0; y: 0; width: parent.width
                    height: Math.max(0, win.ry)
                    color: root.dimColor; opacity: root.dimAlpha
                }
                Rectangle {   // bottom
                    x: 0; y: Math.max(0, win.ry + win.rh); width: parent.width
                    height: Math.max(0, parent.height - (win.ry + win.rh))
                    color: root.dimColor; opacity: root.dimAlpha
                }
                Rectangle {   // left
                    x: 0; y: Math.max(0, win.ry)
                    width: Math.max(0, win.rx)
                    height: Math.max(0, Math.min(win.rh, parent.height - win.ry))
                    color: root.dimColor; opacity: root.dimAlpha
                }
                Rectangle {   // right
                    x: Math.max(0, win.rx + win.rw); y: Math.max(0, win.ry)
                    width: Math.max(0, parent.width - (win.rx + win.rw))
                    height: Math.max(0, Math.min(win.rh, parent.height - win.ry))
                    color: root.dimColor; opacity: root.dimAlpha
                }
                // accent frame drawn just OUTSIDE the rect (never inside the
                // captured region, so it stays out of the recording)
                Rectangle {
                    x: win.rx - 2; y: win.ry - 2
                    width: win.rw + 4; height: win.rh + 4
                    color: "transparent"
                    border.width: 2; border.color: root.accent
                    opacity: 0.9
                }
            }
        }
    }
}

import QtQuick

// Interactive drag-to-select surface, samurai-monochrome / melancholic key:
// a darkened field, a frosted-glass interior, a faint flame fringe licking the
// outline, and a glowing white neon frame. Reports the picked region in global
// compositor coords via picked(); Esc / right-click emits cancelled().
Item {
    id: sel
    focus: true

    property string mode: "shot"
    property real originX: 0
    property real originY: 0
    // debug/screenshot aid: pre-seed a selection ("x,y,w,h" in local coords)
    property string demo: ""
    Component.onCompleted: {
        if (demo.length > 0) {
            var p = demo.split(",")
            if (p.length === 4) {
                sx = parseFloat(p[0]); sy = parseFloat(p[1])
                cx = sx + parseFloat(p[2]); cy = sy + parseFloat(p[3])
            }
        }
    }
    signal picked(real gx, real gy, real gw, real gh)
    signal cancelled()

    // monochrome palette — soft neon white on charcoal
    readonly property color neon:  "#f4f6f8"
    readonly property color petal: "#eae7e1"

    // drag state (local coords)
    property bool dragging: false
    property real sx: 0
    property real sy: 0
    property real cx: 0
    property real cy: 0
    readonly property real rx: Math.min(sx, cx)
    readonly property real ry: Math.min(sy, cy)
    readonly property real rw: Math.abs(cx - sx)
    readonly property real rh: Math.abs(cy - sy)
    readonly property bool hasSel: rw > 2 && rh > 2

    Keys.onEscapePressed: sel.cancelled()
    Keys.onReturnPressed: if (sel.hasSel) sel.emitPick()
    Keys.onEnterPressed:  if (sel.hasSel) sel.emitPick()
    function emitPick() { sel.picked(sel.originX + sel.rx, sel.originY + sel.ry, sel.rw, sel.rh) }

    // ── darkened field: four panels framing the clear selection ──
    Repeater {
        model: 4
        Rectangle {
            color: "#000000"
            opacity: !sel.hasSel ? (index === 0 ? 0.46 : 0) : 0.58
            x: !sel.hasSel ? 0 : (index === 3 ? sel.rx + sel.rw : 0)
            y: !sel.hasSel ? 0 : (index === 0 ? 0 : index === 1 ? sel.ry + sel.rh : sel.ry)
            width:  !sel.hasSel ? sel.width  : (index <= 1 ? sel.width : index === 2 ? sel.rx : sel.width - sel.rx - sel.rw)
            height: !sel.hasSel ? sel.height : (index === 0 ? sel.ry : index === 1 ? sel.height - sel.ry - sel.rh : sel.rh)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    // frosted-glass interior — a GPU-composited gradient rectangle, so it costs
    // nothing per frame (no canvas raster).
    Rectangle {
        visible: sel.hasSel
        x: sel.rx; y: sel.ry; width: sel.rw; height: sel.rh
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#21ffffff" }
            GradientStop { position: 0.5; color: "#0fffffff" }
            GradientStop { position: 1.0; color: "#1affffff" }
        }
    }

    // subtle flame fringe — the ONLY animated layer. A tiny canvas (selection +
    // 8px) doing a single low-alpha path fill per frame: no blur, no gradients,
    // no full-screen raster, so it stays light.
    Canvas {
        id: veil
        visible: sel.hasSel
        readonly property real m: 8
        x: sel.rx - m; y: sel.ry - m
        width: sel.rw + 2 * m; height: sel.rh + 2 * m
        property real phase: 0
        Timer {
            running: sel.hasSel; repeat: true; interval: 50   // ~20fps is plenty
            onTriggered: { veil.phase += 0.12; veil.requestPaint() }
        }
        // map perimeter distance pp → [x, y, outward-nx, outward-ny]
        function perim(pp) {
            var rw = sel.rw, rh = sel.rh, P = 2 * (rw + rh)
            pp = ((pp % P) + P) % P
            if (pp < rw)      return [sel.rx + pp, sel.ry, 0, -1]
            pp -= rw
            if (pp < rh)      return [sel.rx + rw, sel.ry + pp, 1, 0]
            pp -= rh
            if (pp < rw)      return [sel.rx + rw - pp, sel.ry + rh, 0, 1]
            pp -= rw
            return [sel.rx, sel.ry + rh - pp, -1, 0]
        }
        // outward tongue height — layered sines, tapered so most of the edge sits
        // near zero and only small tongues (≤ ~5px) lick out.
        function flameH(pp, t) {
            var v = 0.5 * Math.sin(pp * 0.055 + t * 1.9)
                  + 0.3 * Math.sin(pp * 0.130 - t * 3.0 + 1.7)
                  + 0.2 * Math.sin(pp * 0.280 + t * 4.2)
            var f = v * 0.5 + 0.5
            return f * f * 5.0
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save(); ctx.translate(-x, -y)   // draw in item coords
            var P = 2 * (sel.rw + sel.rh), t = phase, step = 8, pp
            ctx.beginPath()
            var first = true
            for (pp = 0; pp <= P; pp += step) {        // outer wavering edge
                var q = perim(pp), h = flameH(pp, t)
                var ox = q[0] + q[2] * h, oy = q[1] + q[3] * h
                if (first) { ctx.moveTo(ox, oy); first = false } else ctx.lineTo(ox, oy)
            }
            for (pp = P; pp >= 0; pp -= step) {        // back along the edge
                var qi = perim(pp); ctx.lineTo(qi[0], qi[1])
            }
            ctx.closePath()
            ctx.fillStyle = "rgba(244,246,248,0.06)"   // almost invisible
            ctx.fill()
            ctx.restore()
        }
    }
    // neon white frame + soft glow — concentric translucent bordered rectangles,
    // fully GPU-composited. The "breath" is an opacity animation on the group, so
    // nothing re-rasterizes per frame (this is what killed the old blurred canvas
    // frame's lag).
    Item {
        id: frame
        visible: sel.hasSel
        x: sel.rx; y: sel.ry; width: sel.rw; height: sel.rh
        property real pulse: 1.0
        SequentialAnimation on pulse {
            running: sel.hasSel; loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 1500; easing.type: Easing.InOutSine }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -7; radius: 3
            color: "transparent"; border.color: sel.neon; border.width: 7
            opacity: 0.10 * frame.pulse
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: 2
            color: "transparent"; border.color: sel.neon; border.width: 3
            opacity: 0.22 * frame.pulse
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"; border.color: "#ffffff"; border.width: 1.5
            opacity: 0.95
        }
    }

    // dimensions readout, pinned by the top-left of the selection
    Rectangle {
        visible: sel.hasSel
        x: sel.rx
        y: sel.ry - 26 < 0 ? sel.ry + 6 : sel.ry - 26
        width: dimText.width + 16; height: 22; radius: 3
        color: "#0c0b0a"; opacity: 0.85
        Text {
            id: dimText; anchors.centerIn: parent
            text: Math.round(sel.rw) + " × " + Math.round(sel.rh)
            color: sel.neon; font.family: Theme.mono; font.pixelSize: 12; font.letterSpacing: 1
        }
    }

    // hint, centered, fades out once a drag begins
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.5
        opacity: sel.hasSel ? 0 : 0.8
        text: (sel.mode === "rec" ? "select a region to record" : "select a region to capture")
              + "    ·    enter confirms · esc cancels"
        color: Theme.ink; font.family: Theme.mono; font.pixelSize: 15; font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (m) => {
            if (m.button === Qt.RightButton) { sel.cancelled(); return }
            sel.sx = m.x; sel.sy = m.y; sel.cx = m.x; sel.cy = m.y; sel.dragging = true
        }
        onPositionChanged: (m) => { if (sel.dragging) { sel.cx = m.x; sel.cy = m.y } }
        onReleased: {
            sel.dragging = false
            if (sel.hasSel) sel.emitPick(); else sel.cancelled()
        }
    }
}

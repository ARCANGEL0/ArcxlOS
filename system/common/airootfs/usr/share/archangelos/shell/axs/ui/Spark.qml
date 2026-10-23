// Live line graph: one or two series of recent samples, newest on the right, scaled to `max`
// (or to the largest sample when max is 0). The first series is filled in the accent colour.
import QtQuick
import qs.axs

Canvas {
    id: sp
    property var a: []
    property var b: []
    property real max: 0
    property int span: 60
    property color tint: Ax.accent
    property color tint2: Ax.subtext
    implicitWidth: 300; implicitHeight: 64
    onAChanged: requestPaint()
    onBChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const g = getContext("2d"); g.reset();
        const w = width, h = height;
        let top = sp.max;
        if (top <= 0) top = Math.max(1, ...sp.a, ...sp.b) * 1.15;
        g.strokeStyle = Ax.alpha(Ax.text, 0.05); g.lineWidth = 1;
        for (let i = 1; i < 4; i++) { g.beginPath(); g.moveTo(0, Math.round(h * i / 4) + 0.5); g.lineTo(w, Math.round(h * i / 4) + 0.5); g.stroke(); }
        const path = (s) => {
            const n = s.length, dx = w / (sp.span - 1);
            g.beginPath();
            for (let i = 0; i < n; i++) {
                const x = w - (n - 1 - i) * dx, y = h - 1 - Math.min(1, s[i] / top) * (h - 3);
                if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
            }
            return n ? w - (n - 1) * dx : w;
        };
        if (sp.a.length > 1) {
            const x0 = path(sp.a);
            g.lineTo(w, h); g.lineTo(x0, h); g.closePath();
            g.fillStyle = Ax.alpha(sp.tint, 0.14); g.fill();
            path(sp.a); g.strokeStyle = sp.tint; g.lineWidth = 1.6; g.stroke();
        }
        if (sp.b.length > 1) { path(sp.b); g.strokeStyle = sp.tint2; g.lineWidth = 1.3; g.stroke(); }
    }
}

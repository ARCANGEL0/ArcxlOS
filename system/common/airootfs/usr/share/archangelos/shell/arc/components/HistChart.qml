// Smooth history line chart for the per-meter hover panes: gradient area under a
// rounded line, faint gridlines, and a glowing dot on the latest sample.
pragma ComponentBehavior: Bound

import QtQuick
import qs.arc

Item {
    id: chart
    property var hist: []
    property color line: Config.accent
    implicitHeight: 56

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: chart.draw()
    }

    onHistChanged: cv.requestPaint()
    onLineChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    Component.onCompleted: cv.requestPaint()

    function draw() {
        const ctx = cv.getContext("2d");
        ctx.reset();
        const w = cv.width, h = cv.height, n = chart.hist.length;
        if (w < 8 || h < 8 || n < 2) return;
        const padX = Math.max(2, Math.round(w * 0.05)), padY = Math.max(3, Math.round(h * 0.16));
        const step = (w - padX * 2) / (n - 1);
        const yOf = v => padY + (1 - Math.max(0, Math.min(1, v))) * (h - padY * 2);
        const pts = [];
        for (let i = 0; i < n; i++) pts.push([padX + i * step, yOf(chart.hist[i])]);

        ctx.lineWidth = 1;
        ctx.strokeStyle = Qt.rgba(Config.outline.r, Config.outline.g, Config.outline.b, 0.5);
        for (const g of [0.25, 0.5, 0.75]) {
            ctx.beginPath(); ctx.moveTo(0, yOf(g) + 0.5); ctx.lineTo(w, yOf(g) + 0.5); ctx.stroke();
        }

        function trace() {
            ctx.beginPath();
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (let i = 1; i < pts.length - 1; i++) {
                const mx = (pts[i][0] + pts[i + 1][0]) / 2;
                const my = (pts[i][1] + pts[i + 1][1]) / 2;
                ctx.quadraticCurveTo(pts[i][0], pts[i][1], mx, my);
            }
            const l = pts[pts.length - 1];
            ctx.lineTo(l[0], l[1]);
        }

        trace();
        ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, h);
        grad.addColorStop(0, Qt.rgba(chart.line.r, chart.line.g, chart.line.b, 0.32));
        grad.addColorStop(1, Qt.rgba(chart.line.r, chart.line.g, chart.line.b, 0.02));
        ctx.fillStyle = grad;
        ctx.fill();

        trace();
        ctx.strokeStyle = chart.line;
        ctx.lineWidth = 1.6;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.stroke();

        const lx = pts[n - 1][0], ly = pts[n - 1][1];
        ctx.beginPath(); ctx.arc(lx, ly, 5.5, 0, Math.PI * 2);
        ctx.fillStyle = Qt.rgba(chart.line.r, chart.line.g, chart.line.b, 0.22); ctx.fill();
        ctx.beginPath(); ctx.arc(lx, ly, 2.4, 0, Math.PI * 2);
        ctx.fillStyle = chart.line; ctx.fill();
    }
}

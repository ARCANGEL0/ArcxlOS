// A small orthographic globe: every country in outline, one lit in the accent, an optional pin
// (the time zone's city). It turns to face whatever it's pointed at; drag to spin it by hand.
// Country shapes: Natural Earth 1:110m (public domain), packed into assets/world.json as
// { "PT": { n: name, c: [lon, lat], r: [[lon*10, lat*10, …], …] }, … }.
import QtQuick
import Quickshell.Io
import qs.axs

Item {
    id: g
    property string highlight: ""            // ISO 3166 alpha-2
    property var pin: null                   // { lon, lat } or null
    property real lon: 0                     // the point facing us
    property real lat: 20
    property real zoom: 1                    // >1 closes in on the highlighted country
    property real focusZoom: 2.4
    property var world: ({})
    readonly property bool ready: Object.keys(world).length > 0
    implicitWidth: 220; implicitHeight: 220

    FileView {
        path: Qt.resolvedUrl("../assets/world.json").toString().replace("file://", "")
        onLoaded: { try { g.world = JSON.parse(text()); } catch (e) {} }
    }

    // Turn to the highlighted country (or the pin) whenever it changes.
    function centre() {
        const c = g.world[g.highlight];
        const t = c ? { lon: c.c[0], lat: c.c[1] } : g.pin;
        if (!t) return;
        // the short way round
        let d = ((t.lon - g.lon) % 360 + 540) % 360 - 180;
        spinLon.to = g.lon + d; spinLat.to = Math.max(-60, Math.min(60, t.lat));
        // pull back to the whole globe on the way, then close in on the country
        spinZoom.to = c ? g.focusZoom : 1.2;
        spin.restart();
    }
    onHighlightChanged: centre()
    onReadyChanged: centre()
    onPinChanged: if (!g.world[g.highlight]) centre()
    ParallelAnimation {
        id: spin
        NumberAnimation { id: spinLon; target: g; property: "lon"; duration: 900; easing.type: Easing.InOutCubic }
        NumberAnimation { id: spinLat; target: g; property: "lat"; duration: 900; easing.type: Easing.InOutCubic }
        SequentialAnimation {
            NumberAnimation { target: g; property: "zoom"; to: 1; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { id: spinZoom; target: g; property: "zoom"; duration: 650; easing.type: Easing.InOutCubic }
        }
    }
    onZoomChanged: canvas.requestPaint()
    onLonChanged: canvas.requestPaint()
    onLatChanged: canvas.requestPaint()
    onWorldChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        readonly property color land: Ax.mix(Ax.panel, Ax.text, 0.13)
        readonly property color edge: Ax.alpha(Ax.text, 0.16)
        readonly property color lit: Ax.accent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const D = Math.min(width, height) / 2 - 6, R = D * g.zoom, cx = width / 2, cy = height / 2;
            const rad = Math.PI / 180;
            const l0 = g.lon * rad, p0 = g.lat * rad, sp0 = Math.sin(p0), cp0 = Math.cos(p0);
            // project; points on the far side are pulled onto the rim so outlines close cleanly
            function proj(lon, lat) {
                const l = lon * rad - l0, p = lat * rad, cp = Math.cos(p), sp = Math.sin(p), cl = Math.cos(l);
                let x = cp * Math.sin(l), y = cp0 * sp - sp0 * cp * cl;
                const front = sp0 * sp + cp0 * cp * cl;
                if (front < 0) { const n = Math.hypot(x, y) || 1; x /= n; y /= n; }
                return [cx + x * R, cy - y * R, front >= 0];
            }

            // the sea, faintly lit from the upper left
            const sea = ctx.createRadialGradient(cx - R * 0.35, cy - R * 0.4, R * 0.1, cx, cy, R);
            sea.addColorStop(0, Qt.rgba(1, 1, 1, 0.06));
            sea.addColorStop(1, Qt.rgba(1, 1, 1, 0.015));
            ctx.beginPath(); ctx.arc(cx, cy, D, 0, Math.PI * 2); ctx.fillStyle = sea; ctx.fill();
            // zoomed in, the sphere is bigger than the window onto it
            ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, D, 0, Math.PI * 2); ctx.clip();

            // graticule every 30°
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.045); ctx.lineWidth = 1;
            for (let lo = -180; lo < 180; lo += 30) {
                ctx.beginPath(); let pen = false;
                for (let la = -90; la <= 90; la += 5) { const q = proj(lo, la); if (!q[2]) { pen = false; continue; } if (pen) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); pen = true; }
                ctx.stroke();
            }
            for (let la = -60; la <= 60; la += 30) {
                ctx.beginPath(); let pen = false;
                for (let lo = -180; lo <= 180; lo += 5) { const q = proj(lo, la); if (!q[2]) { pen = false; continue; } if (pen) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); pen = true; }
                ctx.stroke();
            }

            // countries: the lit one last, so its outline sits on top
            const draw = (code, fill, stroke, width_) => {
                const c = g.world[code]; if (!c) return;
                for (const r of c.r) {
                    let any = false;
                    for (let i = 0; i < r.length; i += 2) if (proj(r[i] / 10, r[i + 1] / 10)[2]) { any = true; break; }
                    if (!any) continue;
                    ctx.beginPath();
                    for (let i = 0; i < r.length; i += 2) { const q = proj(r[i] / 10, r[i + 1] / 10); if (i === 0) ctx.moveTo(q[0], q[1]); else ctx.lineTo(q[0], q[1]); }
                    ctx.closePath();
                    ctx.fillStyle = fill; ctx.fill();
                    ctx.strokeStyle = stroke; ctx.lineWidth = width_; ctx.stroke();
                }
            };
            for (const code in g.world) if (code !== g.highlight) draw(code, land, edge, 0.6);
            if (g.highlight) draw(g.highlight, lit, Qt.lighter(lit, 1.35), 1.2);

            // the pin
            if (g.pin) {
                const q = proj(g.pin.lon, g.pin.lat);
                if (q[2]) {
                    ctx.beginPath(); ctx.arc(q[0], q[1], 7, 0, Math.PI * 2); ctx.fillStyle = Ax.alpha("#ffffff", 0.18); ctx.fill();
                    ctx.beginPath(); ctx.arc(q[0], q[1], 3.2, 0, Math.PI * 2); ctx.fillStyle = "#fbf8f3"; ctx.fill();
                }
            }

            ctx.restore();
            // rim
            ctx.beginPath(); ctx.arc(cx, cy, D, 0, Math.PI * 2);
            ctx.strokeStyle = Ax.alpha(Ax.accent, 0.35); ctx.lineWidth = 1.2; ctx.stroke();
            ctx.beginPath(); ctx.arc(cx, cy, D + 4, 0, Math.PI * 2);
            ctx.strokeStyle = Ax.alpha(Ax.accent, 0.08); ctx.lineWidth = 4; ctx.stroke();
        }
    }

    // drag to spin; it swings back to the selection on its own later
    MouseArea {
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real px; property real py
        onPressed: (m) => { spin.stop(); px = m.x; py = m.y; }
        onWheel: (w) => { spin.stop(); g.zoom = Math.max(1, Math.min(6, g.zoom * (w.angleDelta.y > 0 ? 1.15 : 1 / 1.15))); back.restart(); }
        onPositionChanged: (m) => {
            g.lon -= (m.x - px) * 0.6 / g.zoom; g.lat = Math.max(-70, Math.min(70, g.lat + (m.y - py) * 0.6 / g.zoom));
            px = m.x; py = m.y;
        }
        onReleased: back.restart()
    }
    Timer { id: back; interval: 4000; onTriggered: g.centre() }
}

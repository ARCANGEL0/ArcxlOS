// Displays — arrangement, resolution, refresh rate, scale, rotation, brightness and night light.
// Changes go to Hyprland at once and are saved by ArcShell's display service, so they survive a
// restart.
import QtQuick
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Devices"
    title: "Displays"
    desc: "Arrange your screens and set how each one draws."

    readonly property var mons: NSS.Display.monitors
    property string selName: ""
    readonly property var sel: mons.find(m => m.name === selName) ?? mons.find(m => m.focused) ?? mons[0] ?? null
    readonly property var scales: [0.75, 1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3]
    readonly property var rotations: ["Landscape", "Portrait", "Landscape (flipped)", "Portrait (flipped)"]

    Component.onCompleted: { NSS.Display.active = true; NSS.Display.refresh(); sunProbe.sh("command -v hyprsunset >/dev/null && echo yes; pgrep -x hyprsunset >/dev/null && echo on", [], (c, o) => { page.hasSunset = o.indexOf("yes") >= 0; page.sunOn = o.indexOf("on") >= 0; }); }
    Component.onDestruction: NSS.Display.active = false

    // Logical size (what the layout sees): rotated and divided by scale.
    function lw(m) { return (m.transform % 2 ? m.height : m.width) / m.scale; }
    function lh(m) { return (m.transform % 2 ? m.width : m.height) / m.scale; }
    function nice(s) { return parseFloat(Number(s).toFixed(2)) + "×"; }

    // ── arrangement ────────────────────────────────────────────────────────────
    Rectangle {
        id: stage
        visible: page.mons.length > 0
        width: parent.width; height: 250
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        CornerTicks { len: 10; anchors.margins: 12 }
        Label { x: 20; y: 16; caption: true; text: page.mons.length > 1 ? "Drag to arrange" : "Arrangement" }

        readonly property var live: page.mons.filter(m => !m.disabled)
        readonly property real minX: Math.min(...live.map(m => m.x), 0)
        readonly property real minY: Math.min(...live.map(m => m.y), 0)
        readonly property real spanW: Math.max(...live.map(m => m.x + page.lw(m)), 1) - minX
        readonly property real spanH: Math.max(...live.map(m => m.y + page.lh(m)), 1) - minY
        readonly property real k: Math.min((width - 80) / spanW, (height - 80) / spanH)
        readonly property real ox: (width - spanW * k) / 2
        readonly property real oy: (height - spanH * k) / 2 + 8

        Repeater {
            model: stage.live
            Rectangle {
                id: mon
                required property var modelData
                readonly property bool chosen: page.sel && page.sel.name === modelData.name
                x: stage.ox + (modelData.x - stage.minX) * stage.k
                y: stage.oy + (modelData.y - stage.minY) * stage.k
                width: page.lw(modelData) * stage.k - 4
                height: page.lh(modelData) * stage.k - 4
                radius: 8
                color: chosen ? Ax.accentSoft : Ax.raised
                border.width: chosen ? 2 : 1
                border.color: chosen ? Ax.accent : Ax.border
                Behavior on color { ColorAnimation { duration: Ax.dur } }
                Column {
                    anchors.centerIn: parent; spacing: 3
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.name; font.weight: Font.Medium }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; mono: true; font.pixelSize: Ax.fsCaption + 1; color: Ax.subtext
                            text: mon.modelData.width + "×" + mon.modelData.height }
                }
                Rectangle { visible: mon.modelData.focused; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8; width: 18; height: 3; radius: 1.5; color: Ax.accent }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: stage.live.length > 1 ? Qt.SizeAllCursor : Qt.PointingHandCursor
                    drag.target: stage.live.length > 1 ? mon : null
                    onPressed: page.selName = mon.modelData.name
                    onReleased: if (stage.live.length > 1) page.dropAt(mon.modelData, (mon.x - stage.ox) / stage.k + stage.minX, (mon.y - stage.oy) / stage.k + stage.minY)
                }
            }
        }
    }
    // Snap a dragged screen against its nearest neighbour: beside it on the side it was dropped,
    // edges aligned when close.
    function dropAt(m, nx, ny) {
        const others = stage.live.filter(o => o.name !== m.name);
        const w = lw(m), h = lh(m);
        const cx = nx + w / 2, cy = ny + h / 2;
        let best = null, bd = 1e12;
        for (const o of others) { const d = Math.hypot(o.x + lw(o) / 2 - cx, o.y + lh(o) / 2 - cy); if (d < bd) { bd = d; best = o; } }
        if (!best) return;
        const bw = lw(best), bh = lh(best);
        const dx = cx - (best.x + bw / 2), dy = cy - (best.y + bh / 2);
        let x, y;
        if (Math.abs(dx) / (bw + w) >= Math.abs(dy) / (bh + h)) {
            x = dx > 0 ? best.x + bw : best.x - w;
            y = Math.abs(ny - best.y) < 120 ? best.y : Math.abs(ny + h - best.y - bh) < 120 ? best.y + bh - h : ny;
        } else {
            y = dy > 0 ? best.y + bh : best.y - h;
            x = Math.abs(nx - best.x) < 120 ? best.x : Math.abs(nx + w - best.x - bw) < 120 ? best.x + bw - w : nx;
        }
        NSS.Display.apply(m.name, { x: Math.round(x), y: Math.round(y) });
    }

    Section {
        visible: page.mons.length === 0
        EmptyState {
            icon: "desktop_access_disabled"
            title: "No displays reported"
            desc: "Display settings come from Hyprland. They show up here once the desktop is running on it."
        }
    }

    // ── selected screen ────────────────────────────────────────────────────────
    Section {
        visible: page.sel !== null
        title: page.sel ? page.sel.name + (page.sel.make || page.sel.model ? "  ·  " + [page.sel.make, page.sel.model].filter(s => s).join(" ") : "") : ""
        note: page.sel ? NSS.Display.modeText(page.sel) : ""
        SRow {
            visible: page.mons.length > 1
            icon: "desktop_windows"; title: "Use this display"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter
                       checked: page.sel ? !page.sel.disabled : false
                       enabled_: page.sel && (page.sel.disabled || page.mons.filter(m => !m.disabled).length > 1)
                       onToggled: (on) => NSS.Display.setDisabled(page.sel.name, !on) }
        }
        SRow {
            icon: "aspect_ratio"; title: "Resolution"
            AxSelect {
                id: resSel
                width: 220; anchors.verticalCenter: parent.verticalCenter
                readonly property var opts: NSS.Display.resolutions(page.sel)
                model: opts.map(r => r.w + " × " + r.h + (r === opts[0] ? "  (native)" : ""))
                current: page.sel ? opts.findIndex(r => r.w === page.sel.width && r.h === page.sel.height) : -1
                onPicked: (i) => {
                    const r = opts[i];
                    const hz = NSS.Display.rates(page.sel, r.key)[0] ?? page.sel.refreshRate;
                    NSS.Display.apply(page.sel.name, { width: r.w, height: r.h, refreshRate: hz });
                }
            }
        }
        SRow {
            icon: "speed"; title: "Refresh rate"
            AxSelect {
                width: 220; anchors.verticalCenter: parent.verticalCenter
                readonly property var opts: page.sel ? NSS.Display.rates(page.sel, page.sel.width + "x" + page.sel.height) : []
                model: opts.map(hz => NSS.Display.trim(hz, 2) + " Hz")
                current: page.sel ? opts.findIndex(hz => Math.abs(hz - page.sel.refreshRate) < 0.05) : -1
                onPicked: (i) => NSS.Display.apply(page.sel.name, { refreshRate: opts[i] })
            }
        }
        SRow {
            icon: "zoom_in"; title: "Scale"; desc: "Make everything larger on high-density screens"
            AxSelect {
                width: 220; anchors.verticalCenter: parent.verticalCenter
                model: page.scales.map(s => page.nice(s) + (s === 1 ? "  (100%)" : "  (" + Math.round(s * 100) + "%)"))
                current: page.sel ? page.scales.findIndex(s => Math.abs(s - page.sel.scale) < 0.01) : -1
                onPicked: (i) => NSS.Display.apply(page.sel.name, { scale: page.scales[i] })
            }
        }
        SRow {
            icon: "screen_rotation"; title: "Orientation"
            AxSelect {
                width: 220; anchors.verticalCenter: parent.verticalCenter
                model: page.rotations
                current: page.sel ? (page.sel.transform % 4) : -1
                onPicked: (i) => NSS.Display.apply(page.sel.name, { transform: i })
            }
        }
        SRow {
            icon: "sync"; title: "Adaptive sync"; desc: "VRR / FreeSync / G-Sync, for smoother games and video"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.sel ? !!page.sel.vrr : false
                       onToggled: (on) => NSS.Display.apply(page.sel.name, { vrr: on }) }
        }
        SRow {
            visible: page.mons.length > 1
            icon: "content_copy"; title: "Mirror"; desc: "Show another display's picture here"
            AxSelect {
                width: 220; anchors.verticalCenter: parent.verticalCenter
                readonly property var opts: ["none"].concat(page.mons.filter(m => page.sel && m.name !== page.sel.name).map(m => m.name))
                model: opts.map(o => o === "none" ? "Don't mirror" : o)
                current: page.sel ? Math.max(0, opts.indexOf(page.sel.mirrorOf || "none")) : 0
                onPicked: (i) => NSS.Display.apply(page.sel.name, { mirrorOf: opts[i] })
            }
        }
    }

    // ── light ──────────────────────────────────────────────────────────────────
    property bool hasSunset: false
    property bool sunOn: false
    property int sunTemp: 4500
    Cmd { id: sunProbe }
    function sunset(on) {
        page.sunOn = on;
        sunProbe.sh(on ? 'pkill -x hyprsunset; sleep 0.2; setsid -f hyprsunset -t "$1" >/dev/null 2>&1' : 'pkill -x hyprsunset', [String(page.sunTemp)], null);
    }
    Section {
        visible: NSS.Brightness.available || page.hasSunset
        title: "Light"
        SRow {
            visible: NSS.Brightness.available
            icon: "brightness_6"; title: "Brightness"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: NSS.Brightness.brightness; from: 1; to: 100; stepSize: 1; suffix: "%"
                       onMoved: (v) => NSS.Brightness.set(v) }
        }
        SRow {
            visible: page.hasSunset
            icon: "nightlight"; title: "Night light"; desc: "Warmer colours that are easier on the eyes after dark"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.sunOn; onToggled: (on) => page.sunset(on) }
        }
        SRow {
            visible: page.hasSunset && page.sunOn
            icon: "thermostat"; title: "Warmth"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: page.sunTemp; from: 2500; to: 6500; stepSize: 100; suffix: " K"
                       onReleased: (v) => { page.sunTemp = Math.round(v); page.sunset(true); } }
        }
    }
}

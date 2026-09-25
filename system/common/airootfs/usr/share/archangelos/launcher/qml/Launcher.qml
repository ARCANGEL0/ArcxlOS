//  ArchangelOS — radial "ink constellation" application launcher.
//  Level 1: a hub ("APPS") ringed by category nodes, joined by geometric
//  (horizontal / vertical / 45°) connectors. Click a category and the whole
//  constellation flows toward it; its applications fan out, each wired back
//  with the same geometric traces. Monochrome sumi-e to match the samurai
//  wallpaper — soft ink pills and hairlines, no color, no hard 90° chrome.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    focus: true

    property string menuPath: "/usr/share/archangelos/launcher/menu.json"
    property string logoPath: "/usr/share/archangelos/logo.png"
    property int startFocus: -1
    property string startQuery: ""   // debug/screenshot aid: pre-fill the search
    signal dismiss()

    // ── data ──
    property string edition: "ArchangelOS"
    property var cats: []
    readonly property int n: cats.length

    // ── navigation state ──
    property int focused: -1      // -1 = ring view, else focused category
    property int selCat: 0        // keyboard highlight on the ring
    property int selApp: 0        // keyboard highlight in the app fan
    property int hoverCat: -1
    property int hoverApp: -1
    property bool intro: false    // entrance-animation gate

    // ── live search state ──
    property string query: ""     // typed text; non-empty = search overlay up
    property bool searching: query.length > 0   // hides the constellation
    property var results: []      // matched apps across every category
    property int selResult: 0
    onQueryChanged: rebuildResults()
    function rebuildResults() {
        var q = query.trim().toLowerCase(), out = [], seen = ({})
        if (q.length > 0) {
            for (var c = 0; c < cats.length && out.length < 13; c++) {
                var items = cats[c].items || []
                for (var i = 0; i < items.length && out.length < 13; i++) {
                    var nm = ("" + (items[i].name || "")).toLowerCase()
                    if (nm.indexOf(q) < 0 || seen[nm]) continue   // filter + dedupe by name
                    seen[nm] = true
                    out.push({ item: items[i], cat: clean(cats[c].name) })
                }
            }
        }
        results = out; selResult = 0
    }

    // ── geometry ──
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real rx: Math.min(width * 0.30, 560)
    readonly property real ry: Math.min(height * 0.32, 320)
    readonly property real anchorX: width * 0.26
    readonly property real anchorY: height * 0.50

    // graph translation — flows the constellation toward the focused node
    property real gx: focused < 0 ? 0 : (anchorX - catHomeX(focused))
    property real gy: focused < 0 ? 0 : (anchorY - catHomeY(focused))
    Behavior on gx { NumberAnimation { duration: 560; easing.type: Easing.OutCubic } }
    Behavior on gy { NumberAnimation { duration: 560; easing.type: Easing.OutCubic } }
    onGxChanged: connCanvas.requestPaint()
    onGyChanged: connCanvas.requestPaint()
    onFocusedChanged: { selApp = 0; connCanvas.requestPaint() }
    // stable per-index pseudo-random in 0..1 (hash-noise; salt varies the axis)
    function jf(i, salt) {
        var s = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453
        return s - Math.floor(s)
    }

    // ── layout helpers (home = screen coords with the graph at rest) ──
    // nodes are scattered on a jittered ring so the constellation feels
    // hand-inked, not laid out on a rigid ellipse (angle + radius wobble).
    function catAng(i) {
        return (-90 + i * 360 / Math.max(n, 1) + (jf(i, 1) - 0.5) * 11) * Math.PI / 180
    }
    function catTier(i) { return 0.98 + jf(i, 2) * 0.30 }   // 0.98 .. 1.28
    function catHomeX(i) { return cx + rx * catTier(i) * Math.cos(catAng(i)) }
    function catHomeY(i) { return cy + ry * catTier(i) * Math.sin(catAng(i)) }
    // apps: a loose organic spray to the right of the anchored category node.
    // columns only guard against collisions; per-column phase + per-item jitter
    // break any table-like alignment so it reads scattered, not gridded.
    function appCols(len) { return Math.min(4, Math.max(1, Math.ceil(len / 9))) }
    function appPerCol(len) { return Math.ceil(len / appCols(len)) }
    function appX(i, len) {
        var per = appPerCol(len), col = Math.floor(i / per)
        return anchorX + 300 + col * 276 + (jf(i, 3) - 0.5) * 46
    }
    function appY(i, len) {
        var per = appPerCol(len), col = Math.floor(i / per), row = i % per
        var count = Math.min(per, len - col * per)
        var phase = (jf(col, 5) - 0.5) * 46          // per-column vertical drift
        return anchorY - (count - 1) * 34 + row * 68 + phase + (jf(i, 4) - 0.5) * 30
    }
    function upper(s) { return (s || "").toUpperCase() }
    // strip any leading icon/emoji glyphs the data embeds in a name so the
    // launcher stays monochrome (e.g. "⭐ Favorites" → "Favorites")
    function clean(s) { var m = ("" + (s || "")).match(/[A-Za-z0-9].*/); return m ? m[0] : (s || "") }
    function pad2(k) { k = "" + k; return k.length < 2 ? "0" + k : k }
    // search results: floating scatter across the field — never a column.
    // columns only bound density; jf jitter + per-column phase break alignment.
    function resCols(len) { return len <= 1 ? 1 : Math.min(4, Math.max(2, Math.ceil(len / 3))) }
    function resPerCol(len) { return Math.ceil(len / resCols(len)) }
    function resX(i, len) {
        var cols = resCols(len), per = resPerCol(len), col = Math.floor(i / per)
        var span = width * 0.66, x0 = width / 2 - span / 2
        var step = cols > 1 ? span / (cols - 1) : 0
        return x0 + col * step + (jf(i, 6) - 0.5) * 70
    }
    function resY(i, len) {
        var per = resPerCol(len), col = Math.floor(i / per), row = i % per
        var count = Math.min(per, len - col * per)
        var phase = (jf(col, 8) - 0.5) * 64
        return height * 0.52 - (count - 1) * 42 + row * 84 + phase + (jf(i, 7) - 0.5) * 34
    }

    // ── menu loading ──
    function parseMenu(txt) {
        try {
            var d = JSON.parse(txt)
            root.edition = d.edition || "ArchangelOS"
            root.cats = d.categories || []
            if (root.startFocus >= 0 && root.startFocus < root.cats.length)
                focusStartTimer.start()
            if (root.startQuery.length > 0) root.query = root.startQuery
        } catch (e) { console.warn("menu parse error:", e) }
        connCanvas.requestPaint()
    }
    Timer { id: focusStartTimer; interval: 120; onTriggered: root.focused = root.startFocus }
    FileView {
        id: menuFile
        path: root.menuPath
        onLoaded: root.parseMenu(menuFile.text())
        onLoadFailed: console.warn("menu load failed:", root.menuPath)
    }
    Component.onCompleted: introTimer.start()
    Timer { id: introTimer; interval: 40; onTriggered: root.intro = true }
    // ── launching (install-on-demand, detached) ──
    // Fully detach the child from the launcher process: dismiss() tears the
    // launcher down immediately after, and a Quickshell `Process` child would be
    // reaped with it before the app ever exec'd. execDetached reparents it away.
    function launchItem(item) {
        if (!item || !item.exec) return
        var exe = item.exec
        var bin = exe.split(" ")[0]
        var pkg = item.pkg ? item.pkg : bin
        var findTerm = "for t in rio konsole alacritty foot kitty wezterm xterm; do command -v $t >/dev/null 2>&1 && { TERM_EMU=$t; break; }; done"
        var run = item.terminal ? ("$TERM_EMU -e " + exe) : ("setsid " + exe + " >/dev/null 2>&1 &")
        var script = findTerm + "; "
            + "if command -v " + bin + " >/dev/null 2>&1; then " + run + "; "
            + "else $TERM_EMU -e bash -lc "
            + "'archangelos-install-tool " + pkg + "; "
            + "command -v " + bin + " >/dev/null 2>&1 && { " + run + "; }'; fi"
        Quickshell.execDetached(["sh", "-lc", script])
        root.dismiss()
    }

    // ── keyboard ──
    Keys.onPressed: function(e) {
        // live search takes priority whenever a query is active
        if (root.query.length > 0) {
            if (e.key === Qt.Key_Escape) { root.query = ""; e.accepted = true; return }
            if (e.key === Qt.Key_Backspace) { root.query = root.query.slice(0, -1); e.accepted = true; return }
            if (e.key === Qt.Key_Down) { root.selResult = Math.min(root.selResult + 1, root.results.length - 1); e.accepted = true; return }
            if (e.key === Qt.Key_Up) { root.selResult = Math.max(root.selResult - 1, 0); e.accepted = true; return }
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (root.results.length > 0) root.launchItem(root.results[root.selResult].item)
                e.accepted = true; return
            }
            if (e.text.length === 1 && e.text >= " ") { root.query += e.text; e.accepted = true; return }
            e.accepted = true; return
        }
        // any printable (non-space) key starts a search
        if (e.text.length === 1 && e.text > " ") { root.query = e.text; e.accepted = true; return }

        if (e.key === Qt.Key_Escape) {
            if (root.focused >= 0) root.focused = -1; else root.dismiss()
            e.accepted = true; return
        }
        var m = Math.max(root.n, 1)
        if (root.focused < 0) {
            if (e.key === Qt.Key_Right) root.selCat = (root.selCat + 1) % m
            else if (e.key === Qt.Key_Left) root.selCat = (root.selCat - 1 + m) % m
            else if (e.key === Qt.Key_Up) root.selCat = (root.selCat - 2 + m) % m
            else if (e.key === Qt.Key_Down) root.selCat = (root.selCat + 2) % m
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.focused = root.selCat
            else return
            connCanvas.requestPaint(); e.accepted = true
        } else {
            var items = root.cats[root.focused].items || []
            if (e.key === Qt.Key_Down) root.selApp = Math.min(root.selApp + 1, items.length - 1)
            else if (e.key === Qt.Key_Up) root.selApp = Math.max(root.selApp - 1, 0)
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launchItem(items[root.selApp]); return }
            else return
            connCanvas.requestPaint(); e.accepted = true
        }
    }
    // ── background: dim wash (click to dismiss) ──
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: root.intro ? 0.8 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    // ── horizon bloom + drifting ink motes ──
    Canvas {
        id: bgCanvas
        anchors.fill: parent
        opacity: root.intro ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700 } }
        property var motes: []
        Component.onCompleted: {
            var s = 7, arr = []
            function rnd() { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff }
            for (var i = 0; i < 46; i++) arr.push([rnd(), rnd(), 1.6 + rnd() * 3.0, 0.05 + rnd() * 0.12])
            motes = arr; requestPaint()
        }
        onPaint: {
            var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
            var g = ctx.createRadialGradient(root.cx, root.cy, 0, root.cx, root.cy, Math.min(width, height) * 0.62)
            g.addColorStop(0.0, "rgba(255,253,248,0.16)")
            g.addColorStop(0.45, "rgba(255,253,248,0.05)")
            g.addColorStop(1.0, "rgba(255,253,248,0.0)")
            ctx.fillStyle = g; ctx.fillRect(0, 0, width, height)
            for (var i = 0; i < motes.length; i++) {
                var m = motes[i], mx = m[0] * width, my = m[1] * height, rr = m[2] * 3.0
                var d = ctx.createRadialGradient(mx, my, 0, mx, my, rr)
                d.addColorStop(0.0, "rgba(255,255,255," + m[3] + ")")
                d.addColorStop(1.0, "rgba(255,255,255,0.0)")
                ctx.fillStyle = d; ctx.beginPath(); ctx.arc(mx, my, rr, 0, 6.2832); ctx.fill()
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    // ── geometric connectors (horizontal / vertical / 45° only) ──
    Canvas {
        id: connCanvas
        anchors.fill: parent
        opacity: (root.intro && !root.searching) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        function elbow(ctx, x0, y0, x1, y1) {
            var dx = x1 - x0, dy = y1 - y0
            var sx = dx < 0 ? -1 : 1, sy = dy < 0 ? -1 : 1
            var mm = Math.min(Math.abs(dx), Math.abs(dy))
            ctx.beginPath(); ctx.moveTo(x0, y0)
            ctx.lineTo(x0 + sx * mm, y0 + sy * mm)
            ctx.lineTo(x1, y1); ctx.stroke()
        }
        onPaint: {
            var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
            if (root.n === 0) return
            if (root.focused < 0) {
                for (var i = 0; i < root.n; i++) {
                    var hot = (i === root.hoverCat || i === root.selCat)
                    ctx.strokeStyle = hot ? "rgba(247,246,242,0.75)" : "rgba(231,229,224,0.16)"
                    ctx.lineWidth = hot ? 1.5 : 1.0
                    elbow(ctx, root.cx, root.cy, root.catHomeX(i) + root.gx, root.catHomeY(i) + root.gy)
                }
            } else {
                var fx = root.catHomeX(root.focused) + root.gx
                var fy = root.catHomeY(root.focused) + root.gy
                var items = root.cats[root.focused].items || []
                for (var j = 0; j < items.length; j++) {
                    var ha = (j === root.hoverApp || j === root.selApp)
                    ctx.strokeStyle = ha ? "rgba(247,246,242,0.85)" : "rgba(231,229,224,0.28)"
                    ctx.lineWidth = ha ? 1.5 : 1.0
                    elbow(ctx, fx, fy, root.appX(j, items.length), root.appY(j, items.length))
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    // ── the constellation (hub + category nodes) ──
    Item {
        id: graph
        anchors.fill: parent
        opacity: (root.intro && !root.searching) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        // central hub — the ArchangelOS mark with APPS beneath it
        Item {
            width: 168; height: 150
            x: root.cx + root.gx - width / 2
            y: root.cy + root.gy - height / 2
            opacity: root.focused < 0 ? 1 : 0.06
            Behavior on opacity { NumberAnimation { duration: 380 } }
            Column {
                anchors.centerIn: parent; spacing: 8
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "file://" + root.logoPath
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 200
                    height: 96; width: 120
                    smooth: true; mipmap: true; asynchronous: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; text: "APPS"
                    font.family: Theme.display; font.pixelSize: 26; font.bold: true
                    font.letterSpacing: 6; color: Theme.fg
                }
            }
            // brush underline beneath the APPS label
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                width: 96; height: 1.4; radius: 0.7; opacity: 0.6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.a4 }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: if (root.focused >= 0) root.focused = -1 }
            onXChanged: connCanvas.requestPaint()
        }

        Repeater { model: root.cats; delegate: catNode }
    }
    // ── category node delegate ──
    Component {
        id: catNode
        Item {
            id: nd
            property bool active: index === root.focused
            property bool hot: index === root.hoverCat || index === root.selCat
            property string label: root.upper(root.clean(modelData.name))
            width: Math.max(132, tm.advanceWidth + label.length * 1.6 + 72)
            height: 38
            x: root.catHomeX(index) + root.gx - width / 2
            y: root.catHomeY(index) + root.gy - height / 2
            z: active ? 5 : 1
            opacity: root.focused < 0 ? 1 : (active ? 1 : 0.05)
            Behavior on opacity { NumberAnimation { duration: 380 } }
            onXChanged: connCanvas.requestPaint()

            TextMetrics {
                id: tm; text: nd.label
                font.family: Theme.display; font.pixelSize: 12; font.letterSpacing: 1.6
            }
            // ink brushstroke — borderless, fades to nothing at both ends
            // (no capsule, no button edge; a soft wash the label rides on)
            Rectangle {
                anchors.fill: parent; radius: 3
                opacity: nd.hot ? 0.95 : 0.84
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.07; color: nd.hot ? "#332f28" : "#191713" }
                    GradientStop { position: 0.93; color: nd.hot ? "#252119" : "#131110" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            // brush-stroke underline — the ink signature, tapered at the ends
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 5
                width: parent.width - 30; height: nd.hot ? 1.8 : 1.0; radius: height / 2
                opacity: nd.hot ? 0.95 : 0.42
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.14; color: nd.hot ? Theme.a4 : Theme.a3 }
                    GradientStop { position: 0.86; color: nd.hot ? Theme.a4 : Theme.a3 }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            Rectangle {
                width: 6; height: 6; radius: 3; x: 16; color: Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 30
                anchors.right: cnt.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                text: nd.label; elide: Text.ElideRight
                font.family: Theme.display; font.pixelSize: 12; font.letterSpacing: 1.6
                color: nd.hot ? Theme.a4 : Theme.fg
            }
            Text {
                id: cnt; anchors.right: parent.right; anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -1
                text: root.pad2(modelData.items ? modelData.items.length : 0)
                font.family: Theme.mono; font.pixelSize: 9; color: Theme.a3
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onEntered: { root.hoverCat = index; root.selCat = index; connCanvas.requestPaint() }
                onExited: { root.hoverCat = -1; connCanvas.requestPaint() }
                onClicked: { root.focused = (root.focused === index) ? -1 : index; connCanvas.requestPaint() }
            }
        }
    }
    // ── application fan (level 2) ──
    Repeater {
        model: (root.focused >= 0 && !root.searching) ? (root.cats[root.focused].items || []) : []
        delegate: appNode
    }
    Component {
        id: appNode
        Item {
            id: an
            property var items: root.focused >= 0 ? (root.cats[root.focused].items || []) : []
            property bool hot: index === root.hoverApp || index === root.selApp
            width: 210; height: 34; z: 6
            x: root.appX(index, items.length) - width / 2
            y: root.appY(index, items.length) - height / 2
            opacity: 0
            Component.onCompleted: appIn.start()
            NumberAnimation on opacity { id: appIn; to: 1; duration: 300; easing.type: Easing.OutCubic }
            // ink brushstroke — borderless, fades at both ends (not a button)
            Rectangle {
                anchors.fill: parent; radius: 3
                opacity: an.hot ? 0.95 : 0.82
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.07; color: an.hot ? "#312d26" : "#191713" }
                    GradientStop { position: 0.93; color: an.hot ? "#241f18" : "#131110" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            // brush underline
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                width: parent.width - 26; height: an.hot ? 1.6 : 1.0; radius: height / 2
                opacity: an.hot ? 0.92 : 0.34
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.14; color: an.hot ? Theme.a4 : Theme.a3 }
                    GradientStop { position: 0.86; color: an.hot ? Theme.a4 : Theme.a3 }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            Rectangle {
                width: 5; height: 5; radius: 2.5; x: 15; color: Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 28
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -1
                text: modelData.name; elide: Text.ElideRight
                font.family: Theme.display; font.pixelSize: 13
                color: an.hot ? Theme.a4 : Theme.fg
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onEntered: { root.hoverApp = index; root.selApp = index; connCanvas.requestPaint() }
                onExited: { root.hoverApp = -1; connCanvas.requestPaint() }
                onClicked: root.launchItem(modelData)
            }
        }
    }
    // ── focused-category heading (top-left title, clear of the app spray) ──
    Column {
        x: 36
        y: 54
        spacing: 4
        opacity: (root.focused >= 0 && !root.searching) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
        Text {
            text: root.focused >= 0 ? root.upper(root.clean(root.cats[root.focused].name)) : ""
            font.family: Theme.display; font.pixelSize: 30; font.bold: true
            font.letterSpacing: 4; color: Theme.fg
        }
        Text {
            text: root.focused >= 0 ? ((root.cats[root.focused].items || []).length + " APPLICATIONS") : ""
            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3; color: Theme.a3
        }
    }

    // ── HUD ──
    Text {
        x: 34; y: 28
        opacity: root.intro ? 0.8 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
        text: root.upper(root.edition) + "  —  LAUNCHER"
        font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3; color: Theme.a3
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 34
        anchors.bottom: parent.bottom; anchors.bottomMargin: 30
        opacity: root.intro ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
        text: root.query.length > 0 ? "type to search · enter to launch · esc to clear"
            : (root.focused < 0 ? "click a node · type to search · esc to close"
                                : "click an app · type to search · esc to go back")
        font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 2.5; color: Theme.a3
    }

    // ── live search overlay (floats above everything while typing) ──
    Item {
        id: searchLayer
        anchors.fill: parent
        z: 60
        visible: root.query.length > 0

        // deeper wash so results read clearly over the constellation
        Rectangle {
            anchors.fill: parent; color: Theme.bg; opacity: 0.55
            MouseArea { anchors.fill: parent; onClicked: root.query = "" }
        }

        // query line — brush-underlined ink prompt, pinned near the top
        Item {
            width: 620; height: 58
            anchors.horizontalCenter: parent.horizontalCenter
            y: 70
            Text {
                id: qText
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                font.family: Theme.display; font.pixelSize: 34; color: Theme.fg
            }
            Rectangle {   // blinking caret
                x: qText.x + qText.width + 6
                anchors.verticalCenter: parent.verticalCenter
                width: 2; height: 30; color: Theme.a4
                SequentialAnimation on opacity {
                    running: searchLayer.visible; loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 520 }
                    NumberAnimation { to: 1; duration: 520 }
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.results.length + (root.results.length === 1 ? " MATCH" : " MATCHES")
                font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2.5; color: Theme.a3
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom; height: 1.2; opacity: 0.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.a3 }
                    GradientStop { position: 0.85; color: Theme.a3 }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // empty state
        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: "no applications match"
            font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 2; color: Theme.a3
        }

        // results — scattered/floating across the field, never a single column
        Repeater {
            model: root.results
            delegate: Item {
                id: ri
                property bool hot: index === root.selResult
                width: Math.max(148, rtm.advanceWidth + 92)
                height: 40
                x: root.resX(index, root.results.length) - width / 2
                y: root.resY(index, root.results.length) - height / 2
                opacity: 0
                Component.onCompleted: rin.start()
                NumberAnimation on opacity { id: rin; to: 1; duration: 260; easing.type: Easing.OutCubic }
                TextMetrics { id: rtm; text: modelData.item.name; font.family: Theme.display; font.pixelSize: 15 }
                Rectangle {
                    anchors.fill: parent; radius: 3
                    opacity: ri.hot ? 0.96 : 0.82
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.08; color: ri.hot ? "#332f28" : "#191713" }
                        GradientStop { position: 0.92; color: ri.hot ? "#251f18" : "#131110" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                    width: parent.width - 34; height: ri.hot ? 1.6 : 1.0; radius: height / 2
                    opacity: ri.hot ? 0.92 : 0.34
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.14; color: ri.hot ? Theme.a4 : Theme.a3 }
                        GradientStop { position: 0.86; color: ri.hot ? Theme.a4 : Theme.a3 }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {
                    width: 6; height: 6; radius: 3; x: 16; color: Theme.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 30
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.item.name; elide: Text.ElideRight
                    font.family: Theme.display; font.pixelSize: 15
                    color: ri.hot ? Theme.a4 : Theme.fg
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: root.selResult = index
                    onClicked: root.launchItem(modelData.item)
                }
            }
        }
    }
}

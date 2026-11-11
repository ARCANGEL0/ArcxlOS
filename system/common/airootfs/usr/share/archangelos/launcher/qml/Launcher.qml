import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: root
    focus: true

    property string menuPath: "/usr/share/archangelos/launcher/menu.json"
    property string logoPath: "/usr/share/archangelos/logo-mark.svg"
    property string hubLogo: "/usr/share/archangelos/logo.png"
    property int startFocus: -1
    property string startQuery: ""
    property bool active: true
    signal dismiss()

    readonly property real s: Math.max(0.8, Math.min(1.6, height / 1080))
    function px(v) { return Math.round(v * s) }

    FontLoader { id: sans; source: "file://" + Quickshell.shellDir + "/../../shell/arc/assets/fonts/InterVariable.ttf" }
    FontLoader { id: silk; source: "file://" + Quickshell.shellDir + "/../../shell/arc/assets/fonts/DepartureMono-Regular.otf" }
    readonly property string sansFamily: sans.status === FontLoader.Ready ? sans.name : "Inter"
    readonly property string silkFamily: silk.status === FontLoader.Ready ? silk.name : Theme.mono

    readonly property color surface: "#0a0a0a"
    readonly property color surfaceHi: "#140e0e"
    readonly property color ink: "#ECEAE4"
    readonly property color inkSoft: "#b9b7b1"
    readonly property color inkMute: "#8a8884"
    readonly property color silkInk: "#6a6864"
    readonly property color copper: "#4a4743"
    readonly property color edge: "#34322f"
    readonly property color accent: Theme.accent

    property string edition: "ArchangelOS"
    property string osName: edition
    property string kernel: ""
    FileView {
        path: "/etc/os-release"
        onLoaded: {
            var m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m) || text().match(/^NAME="?([^"\n]*)"?/m)
            if (m && m[1]) root.osName = m[1]
        }
    }
    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector { onStreamFinished: root.kernel = "Linux " + text.trim() }
    }
    property var cats: []
    property bool shown: false

    function clean(s) { var m = ("" + (s || "")).match(/[A-Za-z0-9].*/); return m ? m[0] : (s || "") }
    function catName(i) {
        var n = clean(cats[i] ? cats[i].name : "")
        return n === "Apps" ? "All apps" : n
    }
    function iconFor(ic) {
        if (!ic) return Quickshell.iconPath("application-x-executable", true)
        if (("" + ic).indexOf("/") === 0) return "file://" + ic
        var p = Quickshell.iconPath(ic, true)
        return (p && p.length > 0) ? p : Quickshell.iconPath("application-x-executable", true)
    }

    readonly property real hubW: px(240)
    readonly property real hubH: px(156)
    readonly property real chipW: px(200)
    readonly property real chipH: px(52)
    readonly property real appW: px(204)
    readonly property real appH: px(40)
    readonly property real appGapX: px(24)
    readonly property real appGapY: px(14)
    readonly property real feedLen: px(64)
    readonly property real stub: px(26)

    readonly property var slots: [[560,0],[-560,0],[0,-260],[0,260],[440,-170],[-440,-170],[440,170],[-440,170],[250,-340],[-250,340],[-250,-340],[250,340]]
    readonly property int count: Math.min(cats.length, slots.length)
    function catX(i) { return px(slots[i][0]) }
    function catY(i) { return px(slots[i][1]) }
    function sideOf(i) { return slots[i][0] < 0 ? -1 : 1 }

    readonly property var routes: {
        var out = []
        var groups = { r: [], l: [], t: [], b: [] }
        for (var i = 0; i < count; i++) {
            var x = slots[i][0], y = slots[i][1]
            var key = Math.abs(x) >= 400 ? (x > 0 ? "r" : "l") : (y < 0 ? "t" : "b")
            groups[key].push(i)
            out.push({ key: key })
        }
        var hw = hubW / 2, hh = hubH / 2
        for (var k in groups) {
            var g = groups[k]
            var horiz = k === "r" || k === "l"
            g.sort((a, b) => horiz ? slots[a][1] - slots[b][1] : slots[a][0] - slots[b][0])
            var span = horiz ? hubH - px(52) : hubW - px(92)
            for (var j = 0; j < g.length; j++) {
                var idx = g[j]
                var t = g.length === 1 ? 0 : (j / (g.length - 1) - 0.5) * span
                var cx = catX(idx), cy = catY(idx)
                var pts
                if (horiz) {
                    var sd = k === "r" ? 1 : -1
                    var sx = sd * hw, sy = t
                    var ex = cx - sd * chipW / 2
                    var x1 = sx + sd * stub
                    var x2 = x1 + sd * Math.abs(cy - sy)
                    pts = [[sx, sy], [x1, sy], [x2, cy], [ex, cy]]
                } else {
                    var sv = k === "b" ? 1 : -1
                    var px0 = t, py0 = sv * hh
                    var ey = cy - sv * chipH / 2
                    var y1 = py0 + sv * stub
                    var y2 = y1 + sv * Math.abs(cx - px0)
                    pts = [[px0, py0], [px0, y1], [cx, y2], [cx, ey]]
                }
                out[idx] = { key: k, horiz: horiz, pts: pts }
            }
        }
        return out
    }

    property int sel: -1
    property string pane: "cats"
    property string filter: ""
    property int appSel: 0
    readonly property bool searching: filter.trim().length > 0
    readonly property string query: filter.trim().toLowerCase()
    readonly property bool atHub: sel < 0 && !searching

    readonly property var listItems: {
        var q = query
        if (!searching) return (sel >= 0 && cats[sel] && cats[sel].items) ? cats[sel].items : []
        var out = [], seen = ({})
        for (var c = 0; c < cats.length; c++) {
            var items = cats[c].items || []
            for (var i = 0; i < items.length; i++) {
                var nm = ("" + (items[i].name || "")).toLowerCase()
                if (nm.indexOf(q) < 0 || seen[nm]) continue
                seen[nm] = true
                out.push(items[i])
            }
        }
        out.sort((a, b) => (("" + a.name).toLowerCase().indexOf(q) === 0 ? 0 : 1) - (("" + b.name).toLowerCase().indexOf(q) === 0 ? 0 : 1))
        return out
    }
    onListItemsChanged: appSel = 0
    onSearchingChanged: pane = searching ? "apps" : "cats"

    readonly property real margin: px(56)

    readonly property int side: sel >= 0 ? sideOf(sel) : 1
    readonly property real anchorX: sel >= 0 ? catX(sel) : 0
    readonly property real anchorY: sel >= 0 ? catY(sel) : 0
    readonly property real anchorHalfW: chipW / 2
    readonly property real availW: width - width * 0.12 - anchorHalfW * 2 - feedLen - margin
    readonly property int hCols: Math.max(1, Math.min(4, Math.floor((availW + appGapX) / (appW + appGapX))))
    readonly property int hRows: Math.max(1, Math.min(8, Math.floor((height - px(170) * 2 + appGapY) / (appH + appGapY))))
    readonly property int sCols: Math.max(1, Math.min(5, Math.floor((width - margin * 2 + appGapX) / (appW + appGapX))))
    readonly property int sRows: Math.max(1, Math.min(6, Math.floor((height - px(190) - hubH - feedLen - margin + appGapY) / (appH + appGapY))))
    readonly property int cols: searching ? sCols : hCols
    readonly property int visRows: searching ? sRows : hRows
    readonly property int totalRows: Math.max(1, Math.ceil(listItems.length / cols))
    readonly property bool rolling: totalRows > visRows
    readonly property int rowsUsed: Math.min(visRows, totalRows)
    readonly property int colsUsed: Math.max(1, Math.min(cols, listItems.length))
    readonly property int selRow: Math.floor(appSel / cols)
    readonly property int selCol: appSel % cols
    readonly property int topRow: Math.max(0, Math.min(totalRows - rowsUsed, selRow - Math.floor(rowsUsed / 2)))
    property real scrollRow: topRow
    Behavior on scrollRow { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    readonly property int winStart: Math.max(0, Math.floor(scrollRow) - 1)
    readonly property int winRows: rowsUsed + 3
    function rowFade(vr) {
        if (!rolling) return 1
        var half = rowsUsed / 2
        var d = Math.abs(vr - (rowsUsed - 1) / 2) / half
        return Math.max(0, Math.min(1, (1 - d) / 0.42))
    }

    readonly property real groupW: anchorHalfW * 2 + feedLen + Math.min(hCols, Math.max(1, listItems.length)) * (appW + appGapX) - appGapX
    readonly property real focusInset: Math.max(margin + anchorHalfW, (width - groupW) / 2 + anchorHalfW)

    readonly property real trunkX: anchorX + side * (anchorHalfW + feedLen - px(22))
    readonly property real gridX0: anchorX + side * (anchorHalfW + feedLen)
    function hAppCx(k) { return gridX0 + side * ((k % cols) * (appW + appGapX) + appW / 2) }
    function hRowCy(r) { return anchorY + (r - (rowsUsed - 1) / 2) * (appH + appGapY) }

    readonly property real sTrunkY: -hubH / 2 - feedLen + px(22)
    function sColCx(c) { return (c - (colsUsed - 1) / 2) * (appW + appGapX) }
    function sRowCy(r) { return -hubH / 2 - feedLen - appH / 2 - r * (appH + appGapY) }
    readonly property real sTop: sRowCy(rowsUsed - 1) - appH / 2

    readonly property real camX: atHub ? 0 : searching ? 0 : anchorX + side * (width / 2 - focusInset)
    readonly property real camY: atHub ? 0 : searching ? (sTop + hubH / 2) / 2 - px(20) : anchorY

    property bool dynamicLoaded: false
    property string menuText: ""
    property bool startApplied: false
    function parseMenu(txt) {
        if (txt === root.menuText) return
        try {
            var d = JSON.parse(txt)
            root.menuText = txt
            root.edition = d.edition || "ArchangelOS"
            root.cats = d.categories || []
            if (root.sel >= root.count) root.sel = -1
            if (!root.startApplied) {
                root.startApplied = true
                if (root.startFocus >= 0 && root.startFocus < root.count) root.sel = root.startFocus
                if (root.startQuery.length > 0) root.filter = root.startQuery
            }
        } catch (e) { console.warn("menu parse error:", e) }
    }
    function reset() {
        filter = ""
        sel = -1
        appSel = 0
        pane = "cats"
    }
    onActiveChanged: {
        if (active) {
            reset()
            shown = true
            forceActiveFocus()
            if (!menuGen.running) menuGen.running = true
        } else {
            shown = false
            reset()
        }
    }
    Process {
        id: menuGen
        command: ["/usr/bin/archangelos-menugen"]
        stdout: StdioCollector {
            id: menuGenOut
            onStreamFinished: {
                var good = false
                try { var d = JSON.parse(menuGenOut.text); good = d && d.categories && d.categories.length > 0 } catch (e) {}
                if (good) { root.dynamicLoaded = true; root.parseMenu(menuGenOut.text) }
            }
        }
        onExited: if (!root.dynamicLoaded) menuFile.path = root.menuPath
    }
    FileView {
        id: menuFile
        onLoaded: if (!root.dynamicLoaded) root.parseMenu(menuFile.text())
        onLoadFailed: console.warn("menu load failed:", root.menuPath)
    }
    Component.onCompleted: { menuGen.running = true; shown = active }

    function launchItem(item) {
        if (!item || !item.exec) return
        var exe = item.exec
        var bin = exe.split(" ")[0]
        var pkg = item.pkg ? item.pkg : bin
        var findTerm = "for t in rio konsole alacritty foot kitty wezterm xterm; do command -v $t >/dev/null 2>&1 && { TERM_EMU=$t; break; }; done"
        var run = item.terminal ? ("$TERM_EMU -e " + exe) : ("setsid " + exe + " >/dev/null 2>&1 &")
        var script = findTerm + "\n"
            + "if command -v " + bin + " >/dev/null 2>&1; then\n" + run + "\nelse\n"
            + "$TERM_EMU -e bash -lc '"
            + "archangelos-install-tool " + pkg + "; "
            + "command -v " + bin + " >/dev/null 2>&1 && " + run + "'\nfi"
        Quickshell.execDetached(["sh", "-lc", script])
        root.dismiss()
    }

    function selectCat(i) {
        filter = ""
        sel = i
        appSel = 0
        pane = "cats"
    }
    function step(dx, dy) {
        var fx = sel >= 0 ? catX(sel) : 0, fy = sel >= 0 ? catY(sel) : 0
        var best = -2, bestScore = 1e12
        for (var i = -1; i < count; i++) {
            if (i === sel) continue
            var x = i >= 0 ? catX(i) : 0, y = i >= 0 ? catY(i) : 0
            var ax = x - fx, ay = (y - fy) * 1.6
            var along = dx !== 0 ? ax * dx : ay * dy
            if (along <= 0) continue
            var across = dx !== 0 ? Math.abs(ay) : Math.abs(ax)
            var score = along + across * 1.5
            if (score < bestScore) { bestScore = score; best = i }
        }
        if (best > -2) selectCat(best)
    }
    function enterApps() { if (listItems.length > 0) pane = "apps" }
    property point hoverLock: Qt.point(-1, -1)
    function lockHover() { hoverLock = pointer.point.scenePosition }
    function hoverFree() {
        var p = pointer.point.scenePosition
        return Math.abs(p.x - hoverLock.x) > 2 || Math.abs(p.y - hoverLock.y) > 2
    }
    HoverHandler { id: pointer }
    function scrollAppSel(dy) {
        var n = listItems.length, c = cols
        if (n === 0 || c === 0) return
        appSel = Math.min(Math.max(0, appSel + dy * c), n - 1)
    }

    Keys.onPressed: function(e) {
        root.lockHover()
        var printable = e.text.length === 1 && e.text > " " && !(e.modifiers & Qt.ControlModifier)
        var n = root.listItems.length
        var c = root.cols
        var outward = root.side > 0 ? Qt.Key_Right : Qt.Key_Left
        var inward = root.side > 0 ? Qt.Key_Left : Qt.Key_Right
        if (e.key === Qt.Key_Escape) {
            if (root.searching) root.filter = ""
            else if (root.pane === "apps") root.pane = "cats"
            else if (root.sel >= 0) root.selectCat(-1)
            else root.dismiss()
        } else if (e.key === Qt.Key_Backspace) {
            root.filter = root.filter.slice(0, -1)
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (root.atHub) root.step(1, 0)
            else if (root.pane === "cats") root.enterApps()
            else if (n > 0) root.launchItem(root.listItems[Math.min(root.appSel, n - 1)])
        } else if (root.searching) {
            var sc = root.selCol
            if (e.key === Qt.Key_Right) { if (sc < c - 1 && root.appSel + 1 < n) root.appSel += 1 }
            else if (e.key === Qt.Key_Left) { if (sc > 0) root.appSel -= 1 }
            else if (e.key === Qt.Key_Up) { root.scrollAppSel(1) }
            else if (e.key === Qt.Key_Down) { root.scrollAppSel(-1) }
            else if (printable || e.key === Qt.Key_Space) root.filter += e.text
            else return
        } else if (root.pane === "cats") {
            if (!root.atHub && e.key === outward) root.enterApps()
            else if (e.key === Qt.Key_Right) root.step(1, 0)
            else if (e.key === Qt.Key_Left) root.step(-1, 0)
            else if (e.key === Qt.Key_Down) root.step(0, 1)
            else if (e.key === Qt.Key_Up) root.step(0, -1)
            else if (printable) root.filter += e.text
            else return
        } else {
            var col = root.selCol
            if (e.key === outward) { if (col < c - 1 && root.appSel + 1 < n) root.appSel += 1 }
            else if (e.key === inward) { if (col === 0) root.pane = "cats"; else root.appSel -= 1 }
            else if (e.key === Qt.Key_Down) { root.scrollAppSel(1) }
            else if (e.key === Qt.Key_Up) { root.scrollAppSel(-1) }
            else if (printable) root.filter += e.text
            else return
        }
        e.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.shown ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
        onWheel: function(w) {
            root.lockHover()
            root.scrollAppSel(w.angleDelta.y < 0 ? 1 : -1)
        }
    }

    component Part: Item {
        id: part
        property var item
        property bool active: false
        width: root.appW
        height: root.appH
        Rectangle {
            anchors.fill: parent
            radius: root.px(2)
            color: part.active ? root.surfaceHi : (partMa.containsMouse ? "#121212" : root.surface)
            border.width: 1
            border.color: part.active ? root.accent : (partMa.containsMouse ? "#5a5853" : root.edge)
        }
        Image {
            id: partIcon
            anchors { left: parent.left; leftMargin: root.px(12); verticalCenter: parent.verticalCenter }
            width: root.px(20); height: width
            sourceSize: Qt.size(root.px(32), root.px(32))
            asynchronous: true
            source: root.iconFor(part.item ? part.item.icon : "")
        }
        Rectangle {
            visible: partIcon.status !== Image.Ready
            anchors.fill: partIcon
            color: "transparent"
            border.width: 1
            border.color: root.edge
            Text {
                anchors.centerIn: parent
                text: ("" + ((part.item && part.item.name) || "?")).charAt(0).toUpperCase()
                color: root.inkMute
                font { family: root.sansFamily; pixelSize: root.px(10); weight: Font.Medium }
            }
        }
        Text {
            anchors { left: partIcon.right; leftMargin: root.px(10); right: parent.right; rightMargin: root.px(10); verticalCenter: parent.verticalCenter }
            text: (part.item && part.item.name) || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: part.active ? root.ink : root.inkSoft
            font { family: root.sansFamily; pixelSize: root.px(13); weight: part.active ? Font.Medium : Font.Normal }
        }
        property alias hovered: partMa.containsMouse
        signal hoveredIn()
        MouseArea {
            id: partMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: part.hoveredIn()
            onPositionChanged: if (!part.active) part.hoveredIn()
            onClicked: root.launchItem(part.item)
        }
    }

    component Pad: Rectangle {
        property bool vertical: false
        property bool lit: false
        property real cx: 0
        property real cy: 0
        width: vertical ? root.px(12) : root.px(8)
        height: vertical ? root.px(8) : root.px(12)
        x: cx - width / 2
        y: cy - height / 2
        color: lit ? root.accent : root.copper
    }

    Item {
        id: world
        x: root.width / 2 - root.camX
        y: root.height / 2 - root.camY
        opacity: root.shown ? 1 : 0
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220 } }

        function catFade(i) {
            if (root.searching) return 0.1
            if (root.sel < 0) return 1
            if (i === root.sel) return 1
            return 0.26
        }

        Repeater {
            model: root.count
            delegate: Shape {
                id: trace
                required property int index
                readonly property var r: root.routes[index] || ({ pts: [[0,0],[0,0]], horiz: true })
                readonly property bool lit: index === root.sel && !root.searching
                z: lit ? 2 : 1
                opacity: lit ? 1 : root.atHub ? 0.85 : 0.3
                Behavior on opacity { NumberAnimation { duration: 260 } }
                ShapePath {
                    strokeColor: trace.lit ? root.accent : root.copper
                    strokeWidth: root.px(2)
                    fillColor: "transparent"
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap
                    PathPolyline { path: trace.r.pts.map(p => Qt.point(p[0], p[1])) }
                }
                Rectangle {
                    readonly property var v: trace.r.pts[2] || [0, 0]
                    readonly property var u: trace.r.pts[1] || [0, 0]
                    visible: Math.abs(v[0] - u[0]) > 1 || Math.abs(v[1] - u[1]) > 1
                    x: v[0] - width / 2; y: v[1] - height / 2
                    width: root.px(10); height: width; radius: width / 2
                    color: "#050505"
                    border.width: root.px(2)
                    border.color: trace.lit ? root.accent : root.copper
                }
                Pad {
                    vertical: !trace.r.horiz
                    lit: trace.lit
                    cx: trace.r.pts[0][0]; cy: trace.r.pts[0][1]
                }
            }
        }

        Item {
            id: hub
            x: -root.hubW / 2
            y: -root.hubH / 2
            width: root.hubW
            height: root.hubH
            z: 3
            opacity: root.searching || root.sel < 0 ? 1 : 0.22
            Behavior on opacity { NumberAnimation { duration: 260 } }

            Rectangle {
                anchors.fill: parent
                radius: root.px(3)
                color: root.surface
                border.width: 1
                border.color: root.searching ? root.accent : root.edge
            }
            Rectangle {
                anchors { fill: parent; margins: root.px(6) }
                radius: root.px(1)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
            }
            Rectangle {
                x: root.px(14); y: root.px(14)
                width: root.px(6); height: width; radius: width / 2
                color: root.searching ? root.accent : root.silkInk
            }
            Text {
                anchors { left: parent.left; bottom: parent.top; bottomMargin: root.px(8) }
                text: "U0"
                color: root.silkInk
                font { family: root.silkFamily; pixelSize: root.px(11) }
            }
            Column {
                anchors.centerIn: parent
                spacing: root.px(3)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(height * 1541 / 1211)
                height: root.px(70)
                MultiEffect {
                    anchors.fill: parent
                    source: hubLogo
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 32
                    colorization: 1.0
                    colorizationColor: root.accent
                    opacity: root.searching ? 0.9 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                }
                Image {
                    id: hubLogo
                    anchors.fill: parent
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: "file://" + root.hubLogo
                }
            }
            Item { width: 1; height: root.px(6) }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.osName
                color: root.ink
                font { family: root.sansFamily; pixelSize: root.px(13); weight: Font.Medium }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.kernel
                visible: text.length > 0
                color: root.inkMute
                font { family: root.silkFamily; pixelSize: root.px(10) }
            }
            }
        }

        Repeater {
            model: root.count
            delegate: Item {
                id: chip
                required property int index
                readonly property bool active: index === root.sel && !root.searching
                readonly property var r: root.routes[index] || ({ pts: [[0,0],[0,0]], horiz: true })
                readonly property var entry: r.pts[r.pts.length - 1]
                x: root.catX(index) - width / 2
                y: root.catY(index) - height / 2
                width: root.chipW
                height: root.chipH
                z: 4

                Rectangle {
                    anchors.fill: parent
                    radius: root.px(3)
                    color: root.surface
                    opacity: root.searching ? 0.5 : 1
                }
                Item {
                anchors.fill: parent
                opacity: world.catFade(chip.index)
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Rectangle {
                    anchors.fill: parent
                    radius: root.px(3)
                    color: chip.active ? root.surfaceHi : root.surface
                    border.width: 1
                    border.color: chip.active ? root.accent : (chipMa.containsMouse ? "#5a5853" : root.edge)
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                }
                Rectangle {
                    anchors { fill: parent; margins: root.px(5) }
                    radius: root.px(1)
                    color: "transparent"
                    border.width: 1
                    border.color: chip.active ? Qt.rgba(194/255, 74/255, 82/255, 0.35) : Qt.rgba(1, 1, 1, 0.05)
                }
                Rectangle {
                    x: root.px(12); y: root.px(12)
                    width: root.px(5); height: width; radius: width / 2
                    color: chip.active ? root.accent : root.silkInk
                }
                Pad {
                    vertical: !chip.r.horiz
                    lit: chip.active
                    cx: chip.entry[0] - chip.x
                    cy: chip.entry[1] - chip.y
                }
                Text {
                    anchors { left: parent.left; bottom: parent.top; bottomMargin: root.px(6) }
                    text: "U" + (chip.index + 1)
                    color: chip.active ? root.accent : root.silkInk
                    font { family: root.silkFamily; pixelSize: root.px(11) }
                }
                Text {
                    anchors { left: parent.left; leftMargin: root.px(26); verticalCenter: parent.verticalCenter }
                    text: root.catName(chip.index)
                    color: chip.active ? root.ink : root.inkSoft
                    font { family: root.sansFamily; pixelSize: root.px(15); weight: chip.active ? Font.DemiBold : Font.Medium }
                }
                Text {
                    anchors { right: parent.right; rightMargin: root.px(16); verticalCenter: parent.verticalCenter }
                    text: ((root.cats[chip.index] || {}).items || []).length
                    color: chip.active ? root.ink : root.inkMute
                    font { family: root.sansFamily; pixelSize: root.px(13); features: { "tnum": 1 } }
                }
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectCat(chip.index)
                }
            }
        }

        Item {
            id: board
            z: 6
            visible: !root.searching && root.sel >= 0 && root.listItems.length > 0
            readonly property bool lit: root.pane === "apps"
            readonly property real topY: root.hRowCy(0)
            readonly property real botY: root.hRowCy(root.rowsUsed - 1)
            readonly property real feedFrom: root.anchorX + root.side * root.anchorHalfW
            readonly property real litY: root.hRowCy(Math.max(0, Math.min(root.rowsUsed - 1, root.selRow - root.scrollRow)))

            Rectangle {
                x: Math.min(board.feedFrom, root.trunkX); y: root.anchorY - height / 2
                width: Math.abs(root.trunkX - board.feedFrom); height: root.px(2)
                color: root.accent
            }
            Pad { lit: true; cx: board.feedFrom; cy: root.anchorY }
            Rectangle {
                x: root.trunkX - width / 2
                y: Math.min(board.topY, root.anchorY) - root.px(1)
                width: root.px(2)
                height: Math.max(board.botY, root.anchorY) - Math.min(board.topY, root.anchorY) + root.px(2)
                color: root.copper
            }
            Rectangle {
                visible: board.lit
                x: root.trunkX - width / 2
                y: Math.min(board.litY, root.anchorY) - root.px(1)
                width: root.px(2)
                height: Math.abs(board.litY - root.anchorY) + root.px(2)
                color: root.accent
            }
            Rectangle {
                x: root.trunkX - width / 2; y: root.anchorY - height / 2
                width: root.px(10); height: width; radius: width / 2
                color: "#050505"
                border.width: root.px(2)
                border.color: root.accent
            }

            Repeater {
                model: board.visible ? root.winRows : 0
                delegate: Item {
                    id: hstub
                    required property int index
                    readonly property int absRow: root.winStart + index
                    readonly property real vr: absRow - root.scrollRow
                    readonly property bool lit: board.lit && absRow === root.selRow
                    readonly property real cy: root.hRowCy(vr)
                    visible: absRow < root.totalRows
                    opacity: root.rowFade(vr)
                    Rectangle {
                        x: Math.min(root.trunkX, root.gridX0); y: hstub.cy - height / 2
                        width: Math.abs(root.gridX0 - root.trunkX); height: root.px(2)
                        color: hstub.lit ? root.accent : root.copper
                    }
                    Rectangle {
                        x: root.trunkX - width / 2; y: hstub.cy - height / 2
                        width: root.px(6); height: width; radius: width / 2
                        color: hstub.lit ? root.accent : root.copper
                    }
                }
            }

            Repeater {
                model: board.visible ? root.winRows * root.cols : 0
                delegate: Item {
                    id: hcell
                    required property int index
                    readonly property int absIdx: root.winStart * root.cols + index
                    readonly property var entry: root.listItems[absIdx]
                    readonly property int col: absIdx % root.cols
                    readonly property int absRow: Math.floor(absIdx / root.cols)
                    readonly property real vr: absRow - root.scrollRow
                    readonly property bool linkLit: board.lit && absRow === root.selRow && col <= root.selCol
                    visible: !!entry && opacity > 0.01
                    opacity: root.rowFade(vr)
                    x: root.hAppCx(col) - root.appW / 2
                    y: root.hRowCy(vr) - root.appH / 2
                    Rectangle {
                        visible: hcell.col > 0
                        x: root.side > 0 ? -root.appGapX : root.appW
                        y: root.appH / 2 - height / 2
                        width: root.appGapX; height: root.px(2)
                        color: hcell.linkLit ? root.accent : root.copper
                    }
                    Pad { lit: hcell.linkLit; cx: root.side > 0 ? 0 : root.appW; cy: root.appH / 2 }
                    Part {
                        item: hcell.entry
                        active: board.lit && hcell.absIdx === root.appSel
                        onHoveredIn: if (root.hoverFree()) { root.pane = "apps"; root.appSel = hcell.absIdx }
                    }
                }
            }
        }

        Item {
            id: sboard
            z: 6
            visible: root.searching && root.listItems.length > 0
            readonly property real hubTop: -root.hubH / 2
            readonly property real leftX: root.sColCx(0)
            readonly property real rightX: root.sColCx(root.colsUsed - 1)
            readonly property real litX: root.sColCx(root.selCol)

            Rectangle {
                x: -width / 2; y: root.sTrunkY
                width: root.px(2); height: sboard.hubTop - root.sTrunkY
                color: root.accent
            }
            Pad { vertical: true; lit: true; cx: 0; cy: sboard.hubTop }
            Rectangle {
                x: Math.min(sboard.leftX, 0); y: root.sTrunkY - height / 2
                width: Math.max(sboard.rightX, 0) - Math.min(sboard.leftX, 0); height: root.px(2)
                color: root.copper
            }
            Rectangle {
                x: Math.min(sboard.litX, 0); y: root.sTrunkY - height / 2
                width: Math.abs(sboard.litX); height: root.px(2)
                color: root.accent
            }
            Rectangle {
                x: -width / 2; y: root.sTrunkY - height / 2
                width: root.px(10); height: width; radius: width / 2
                color: "#050505"
                border.width: root.px(2)
                border.color: root.accent
            }

            Repeater {
                model: sboard.visible ? root.colsUsed : 0
                delegate: Item {
                    id: vstub
                    required property int index
                    readonly property bool lit: index === root.selCol
                    readonly property real cx: root.sColCx(index)
                    Rectangle {
                        x: vstub.cx - width / 2; y: root.sRowCy(0) + root.appH / 2
                        width: root.px(2); height: root.sTrunkY - y
                        color: vstub.lit ? root.accent : root.copper
                    }
                    Rectangle {
                        x: vstub.cx - width / 2; y: root.sTrunkY - height / 2
                        width: root.px(6); height: width; radius: width / 2
                        color: vstub.lit ? root.accent : root.copper
                    }
                }
            }

            Repeater {
                model: sboard.visible ? root.winRows * root.cols : 0
                delegate: Item {
                    id: scell
                    required property int index
                    readonly property int absIdx: root.winStart * root.cols + index
                    readonly property var entry: root.listItems[absIdx]
                    readonly property int col: absIdx % root.cols
                    readonly property int absRow: Math.floor(absIdx / root.cols)
                    readonly property real vr: absRow - root.scrollRow
                    readonly property bool linkLit: col === root.selCol && absRow <= root.selRow
                    visible: !!entry && opacity > 0.01
                    opacity: root.rowFade(vr)
                    x: root.sColCx(col) - root.appW / 2
                    y: root.sRowCy(vr) - root.appH / 2
                    Rectangle {
                        visible: scell.absRow > 0
                        x: root.appW / 2 - width / 2; y: root.appH
                        width: root.px(2); height: root.appGapY
                        color: scell.linkLit ? root.accent : root.copper
                    }
                    Pad { vertical: true; lit: scell.linkLit; cx: root.appW / 2; cy: root.appH }
                    Part {
                        item: scell.entry
                        active: scell.absIdx === root.appSel
                        onHoveredIn: if (root.hoverFree()) root.appSel = scell.absIdx
                    }
                }
            }
        }
    }

    Item {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: root.px(76) }
        width: searchText.width
        height: root.px(40)
        visible: root.filter.length > 0
        Text {
            id: searchText
            anchors.centerIn: parent
            text: root.filter
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.sansFamily; pixelSize: root.px(22); weight: Font.Medium }
        }
        Rectangle {
            anchors { left: searchText.right; leftMargin: root.px(3); verticalCenter: searchText.verticalCenter }
            width: Math.max(1, root.px(2)); height: root.px(24)
            color: root.accent
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: searchText.bottom; topMargin: root.px(4) }
            text: root.listItems.length === 0 ? "Nothing matches. Backspace to edit, Esc to clear." : root.listItems.length + (root.listItems.length === 1 ? " match" : " matches")
            color: root.inkMute
            font { family: root.sansFamily; pixelSize: root.px(12) }
        }
    }
}

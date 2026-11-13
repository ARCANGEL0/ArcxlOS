pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    focus: true

    property bool active: false
    signal dismiss()

    readonly property color surface: "#0a0a0a"
    readonly property color surfaceHi: "#141010"
    readonly property color edge: "#262523"
    readonly property color accent: "#F01010"
    readonly property color accentDim: "#5a1414"
    readonly property color ink: "#ECEAE4"
    readonly property color inkSoft: "#b9b7b1"
    readonly property color inkMute: "#8a8884"

    readonly property real scaleF: Math.max(0.78, Math.min(1.5, height / 1080))
    function px(v) { return Math.round(v * scaleF) }

    property var cats: []
    property int hover: 0
    property int expanded: -1
    property int toolSel: 0
    property real cx: width / 2
    property real cy: height / 2
    property real anim: 0

    readonly property real outer: px(236)
    readonly property real inner: px(126)

    FontLoader { id: mono; source: "file://" + Quickshell.shellDir + "/../../shell/arc/assets/fonts/DepartureMono-Regular.otf" }
    FontLoader { id: nerd; source: "file://" + Quickshell.shellDir + "/../../shell/arc/assets/fonts/MaterialSymbolsRounded.ttf" }
    readonly property string monoFamily: mono.status === FontLoader.Ready ? mono.name : "monospace"

    readonly property var glyphs: ({
        "Information Gathering": "travel_explore", "Vulnerability Analysis": "bug_report",
        "Web Application": "public", "Database Assessment": "database", "Password Attacks": "key",
        "Wireless Attacks": "wifi", "Bluetooth & RF": "bluetooth", "Exploitation": "bolt",
        "Sniffing & Spoofing": "sensors", "Reverse Engineering": "memory",
        "Malware Analysis": "coronavirus", "Forensics": "fingerprint",
        "Anonymity & Tunneling": "vpn_lock", "Defense & Hardening": "shield",
        "Fuzzing": "shuffle", "Code & Supply Chain": "code", "Automation & Utilities": "terminal"
    })
    function glyphFor(name) { return glyphs[name] || "crosshairs" }

    Process {
        id: gen
        command: ["/usr/bin/archangelos-menugen", "--redteam"]
        stdout: StdioCollector {
            id: genOut
            onStreamFinished: {
                try {
                    var d = JSON.parse(genOut.text);
                    root.cats = d.categories || [];
                } catch (e) { root.cats = []; }
            }
        }
    }

    Process {
        id: curpos
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            id: curOut
            onStreamFinished: {
                var x = root.width / 2, y = root.height / 2;
                try { var j = JSON.parse(curOut.text); x = j.x; y = j.y; } catch (e) {}
                var m = root.px(30);
                root.cx = Math.max(root.outer + m, Math.min(root.width - root.outer - m, x));
                root.cy = Math.max(root.outer + m, Math.min(root.height - root.outer - m, y));
                board.requestPaint();
            }
        }
    }

    onActiveChanged: {
        if (active) {
            expanded = -1; toolSel = 0; hover = 0;
            gen.running = true;
            curpos.running = true;
            forceActiveFocus();
            openAnim.restart();
        } else {
            anim = 0;
        }
    }

    NumberAnimation {
        id: openAnim
        target: root; property: "anim"; from: 0; to: 1
        duration: 180; easing.type: Easing.OutCubic
    }

    function sliceAt(mx, my) {
        var dx = mx - cx, dy = my - cy;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < inner * 0.8 || dist > outer * 1.1) return -1;
        var n = cats.length;
        if (n === 0) return -1;
        var ang = Math.atan2(dy, dx) * 180 / Math.PI + 90;
        ang = ((ang % 360) + 360) % 360;
        var span = 360 / n;
        return Math.floor(((ang + span / 2) % 360) / span) % n;
    }

    function catItems(i) {
        if (i < 0 || i >= cats.length) return [];
        return cats[i].items || [];
    }

    function launch(item) {
        if (!item || !item.exec) { root.dismiss(); return; }
        var exe = item.exec;
        var findTerm = "for t in rio konsole alacritty foot kitty wezterm xterm; do command -v $t >/dev/null 2>&1 && { TERM_EMU=$t; break; }; done";
        var run = item.terminal ? "$TERM_EMU -e " + exe : "setsid " + exe + " >/dev/null 2>&1 &";
        Quickshell.execDetached(["sh", "-lc", findTerm + "\n" + run]);
        root.dismiss();
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: (m) => {
            if (root.expanded >= 0) return;
            var s = root.sliceAt(m.x, m.y);
            if (s >= 0 && s !== root.hover) { root.hover = s; board.requestPaint(); }
        }
        onClicked: (m) => {
            if (m.button === Qt.RightButton) { root.dismiss(); return; }
            if (root.expanded >= 0) {
                root.expanded = -1; board.requestPaint(); return;
            }
            var s = root.sliceAt(m.x, m.y);
            if (s >= 0) { root.expanded = s; root.toolSel = 0; board.requestPaint(); }
            else root.dismiss();
        }
    }

    Canvas {
        id: board
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var n = root.cats.length;
            if (n === 0) return;
            var a = root.anim;
            ctx.globalAlpha = a;
            var span = 2 * Math.PI / n;
            var ro = root.outer * (0.6 + 0.4 * a);
            var ri = root.inner * (0.6 + 0.4 * a);
            for (var i = 0; i < n; i++) {
                var mid = i * span - Math.PI / 2;
                var a0 = mid - span / 2, a1 = mid + span / 2;
                var hot = (root.expanded >= 0 ? root.expanded === i : root.hover === i);
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, ro, a0 + 0.012, a1 - 0.012);
                ctx.arc(root.cx, root.cy, ri, a1 - 0.012, a0 + 0.012, true);
                ctx.closePath();
                ctx.fillStyle = hot ? root.surfaceHi : root.surface;
                ctx.fill();
                ctx.lineWidth = hot ? 1.6 : 1;
                ctx.strokeStyle = hot ? root.accent : root.edge;
                ctx.stroke();
            }
            ctx.beginPath();
            ctx.arc(root.cx, root.cy, ri - root.px(6), 0, 2 * Math.PI);
            ctx.fillStyle = root.surface;
            ctx.fill();
            ctx.lineWidth = 1.4;
            ctx.strokeStyle = root.accentDim;
            ctx.stroke();
        }
    }

    Image {
        source: "file://" + Quickshell.shellDir + "/../sword_neon.png"
        width: root.inner * 1.15
        height: root.inner * 1.15
        x: root.cx - width / 2
        y: root.cy - height / 2
        opacity: root.anim * (root.expanded >= 0 ? 0.5 : 1)
        smooth: true
        fillMode: Image.PreserveAspectFit
    }

    Repeater {
        model: root.cats.length
        Item {
            id: lbl
            required property int index
            readonly property int n: root.cats.length
            readonly property real span: 2 * Math.PI / Math.max(1, n)
            readonly property real mid: index * span - Math.PI / 2
            readonly property real lr: (root.outer + root.inner) / 2
            x: root.cx + Math.cos(mid) * lr - width / 2
            y: root.cy + Math.sin(mid) * lr - height / 2
            width: root.px(96); height: root.px(54)
            opacity: root.anim
            visible: root.expanded < 0 || root.expanded === index
            Column {
                anchors.centerIn: parent
                spacing: root.px(2)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.glyphFor(root.cats[lbl.index].name)
                    font.family: nerd.name; font.pixelSize: root.px(22)
                    color: (root.expanded === lbl.index || root.hover === lbl.index) ? root.accent : root.inkSoft
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.px(92)
                    horizontalAlignment: Text.AlignHCenter
                    text: root.cats[lbl.index].name
                    font.family: root.monoFamily; font.pixelSize: root.px(9)
                    font.letterSpacing: 0.5
                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    color: (root.expanded === lbl.index || root.hover === lbl.index) ? root.ink : root.inkMute
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.cats[lbl.index].items || []).length
                    font.family: root.monoFamily; font.pixelSize: root.px(8)
                    color: root.inkMute; opacity: 0.7
                }
            }
        }
    }

    Rectangle {
        id: panel
        visible: root.expanded >= 0
        opacity: visible ? root.anim : 0
        color: root.surface
        border.color: root.edge
        border.width: 1
        radius: root.px(10)
        readonly property real pw: root.px(430)
        readonly property real maxH: root.height - root.px(80)
        width: pw
        height: Math.min(maxH, grid.implicitHeight + root.px(52))
        x: Math.max(root.px(24), Math.min(root.width - width - root.px(24),
             root.cx + (root.cx > root.width / 2 ? -(root.outer + root.px(24) + width) : (root.outer + root.px(24)))))
        y: Math.max(root.px(24), Math.min(root.height - height - root.px(24), root.cy - height / 2))

        Column {
            anchors.fill: parent
            anchors.margins: root.px(16)
            spacing: root.px(10)
            Row {
                spacing: root.px(10)
                Text {
                    text: root.expanded >= 0 ? root.glyphFor(root.cats[root.expanded].name) : ""
                    font.family: nerd.name; font.pixelSize: root.px(20); color: root.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.expanded >= 0 ? root.cats[root.expanded].name : ""
                    font.family: root.monoFamily; font.pixelSize: root.px(14); font.letterSpacing: 1
                    color: root.ink
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.edge }
            Flickable {
                width: parent.width
                height: panel.height - root.px(52)
                contentHeight: grid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                GridLayout {
                    id: grid
                    width: parent.width
                    columns: 2
                    rowSpacing: root.px(6)
                    columnSpacing: root.px(6)
                    Repeater {
                        model: root.expanded >= 0 ? root.catItems(root.expanded) : []
                        Rectangle {
                            id: chip
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.px(34)
                            radius: root.px(7)
                            color: root.toolSel === index ? root.surfaceHi : "transparent"
                            border.color: root.toolSel === index ? root.accent : root.edge
                            border.width: 1
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: root.px(12)
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right; anchors.rightMargin: root.px(10)
                                text: chip.modelData.name
                                font.family: root.monoFamily; font.pixelSize: root.px(11)
                                color: root.toolSel === index ? root.ink : root.inkSoft
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.toolSel = chip.index
                                onClicked: root.launch(chip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: {
        if (expanded >= 0) { expanded = -1; board.requestPaint(); }
        else dismiss();
    }
    Keys.onPressed: (e) => {
        var n = cats.length;
        if (n === 0) return;
        if (expanded < 0) {
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) { hover = (hover - 1 + n) % n; board.requestPaint(); e.accepted = true; }
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) { hover = (hover + 1) % n; board.requestPaint(); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { expanded = hover; toolSel = 0; board.requestPaint(); e.accepted = true; }
        } else {
            var items = catItems(expanded);
            var m = items.length;
            if (m === 0) return;
            if (e.key === Qt.Key_Down || e.key === Qt.Key_Right) { toolSel = Math.min(m - 1, toolSel + 1); e.accepted = true; }
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left) { toolSel = Math.max(0, toolSel - 1); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { launch(items[toolSel]); e.accepted = true; }
        }
    }

    onAnimChanged: board.requestPaint()
    onCatsChanged: board.requestPaint()
}

/*
 * ArchangelOS shell — wallpaper coverflow, rising out of the bottom-centre notch.
 * Part of the ArcShell / arcshell mesh; AGPL-3.0 (see LICENSE).
 *
 * Replaces ArcShell's grid picker (WallpaperPopup.qml, kept for reference) and drives the
 * same WallpaperService. Browsing previews live on the desktop; Enter keeps it, Esc puts the
 * old one back. The swatches are the wallpaper's own colours: picking one makes it the accent
 * of both shells.
 */

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../components"
import "../services"
import "../"

Item {
    id: root

    property real localScale: 1.0
    readonly property real s: localScale
    readonly property int popupWidth:  Math.round(1240 * s)
    readonly property int popupHeight: Math.round(520 * s)

    readonly property bool shown: SurfaceState.activeContent === "wallpaper"
    readonly property var walls: WallpaperService.wallpapers
    readonly property int count: walls.length

    property int index: 0                 // the selected wallpaper
    property real flow: 0                 // eased position the cards are laid out from
    property bool flowEased: true
    onIndexChanged: flow = index
    Behavior on flow { enabled: root.flowEased; NumberAnimation { duration: Math.round(Anim.extraSlow * 0.9); easing.type: Easing.OutQuint } }

    property string original: ""          // what was on the desktop when the picker opened
    property bool committed: false
    readonly property string selected: count > 0 ? walls[Math.max(0, Math.min(count - 1, index))] : ""

    // --- card metrics -------------------------------------------------------------------
    readonly property real cw: Math.round(600 * s)       // centre card
    readonly property real ch: Math.round(338 * s)
    readonly property real sw0: Math.round(78 * s)       // first slice either side
    readonly property real sw: Math.round(44 * s)        // further slices
    readonly property real sh0: Math.round(286 * s)
    readonly property real gap: Math.round(18 * s)
    readonly property real step: Math.round(52 * s)
    readonly property real cardTop: Math.round(26 * s)

    function fileName(p) { var n = p.split("/").pop(); var i = n.lastIndexOf("."); return i > 0 ? n.slice(0, i) : n }
    function ext(p) { var i = p.lastIndexOf("."); return i > 0 ? p.slice(i + 1).toUpperCase() : "" }
    function humanSize(b) {
        if (b <= 0) return ""
        if (b < 1024 * 1024) return Math.round(b / 1024) + " KB"
        return (b / 1024 / 1024).toFixed(1) + " MB"
    }

    function go(i) {
        if (count === 0) return
        index = Math.max(0, Math.min(count - 1, i))
        previewTimer.restart()
    }
    function commit() {
        if (selected === "") return
        committed = true
        WallpaperService.apply(selected)
        SurfaceState.close()
    }
    function cancel() { SurfaceState.close() }

    onShownChanged: {
        if (shown) {
            WallpaperService.refresh()
            original = WallpaperService.currentWall
            committed = false
            var i = walls.indexOf(original)
            index = i >= 0 ? i : 0
            flowSnap.restart()
        } else if (!committed && original !== "" && previewing !== original) {
            // Closed without Enter: put the old one back.
            previewTimer.stop()
            WallpaperService.show(original)
            previewing = original
        }
    }
    // Opening lands on the current wallpaper without sweeping the whole strip past.
    Timer { id: flowSnap; interval: 0; onTriggered: { root.flowEased = false; root.flow = root.index; root.flowEased = true; probe.load() } }
    // Focus only sticks once the picker is visible (it fades in from opacity 0).
    onVisibleChanged: if (visible && shown) keys.forceActiveFocus()
    onOpacityChanged: if (opacity === 1 && shown && !keys.activeFocus) keys.forceActiveFocus()
    onCountChanged: if (shown && original !== "") { var i = walls.indexOf(original); if (i >= 0) { index = i } }

    // --- live preview on the desktop (debounced) ----------------------------------------
    property string previewing: ""
    Timer {
        id: previewTimer
        interval: 650
        onTriggered: {
            probe.load()
            if (!root.shown || root.selected === "" || root.selected === root.previewing) return
            root.previewing = root.selected
            WallpaperService.show(root.selected)
        }
    }

    // --- details of the selected file -----------------------------------------------------
    Item {
        id: probe
        property string path: ""
        property real bytes: 0
        readonly property bool video: WallpaperService.isVideo(path)
        property string videoInfo: ""      // "1920,1080,25.000" from ffprobe
        function load() {
            if (root.selected === path) return
            path = root.selected; bytes = 0; videoInfo = ""
            sizeProc.running = false; sizeProc.running = true
            if (video) { vidProc.running = false; vidProc.running = true }
        }
        Image { id: probeImg; visible: false; asynchronous: true; source: probe.path !== "" && !probe.video ? "file://" + probe.path : "" }
        Process {
            id: vidProc
            command: ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height:format=duration", "-of", "csv=p=0:s=,", probe.path]
            stdout: StdioCollector { onStreamFinished: probe.videoInfo = text.trim().split("\n").join(",") }
        }
        Process {
            id: sizeProc
            command: ["stat", "-Lc", "%s", probe.path]
            stdout: StdioCollector { onStreamFinished: probe.bytes = parseInt(text.trim()) || 0 }
        }
    }

    // --- palette from the selected wallpaper ------------------------------------------------
    property var swatchColors: []
    Canvas {
        id: sampler
        width: 24; height: 14
        visible: false
        renderStrategy: Canvas.Immediate
        property string src: probe.path !== "" ? "file://" + WallpaperService.posterFor(probe.path) : ""
        onSrcChanged: if (src !== "") loadImage(src)
        onImageLoaded: requestPaint()
        onPaint: {
            if (src === "" || !isImageLoaded(src)) return
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(src, 0, 0, width, height)
            var d = ctx.getImageData(0, 0, width, height).data
            var buckets = {}
            for (var i = 0; i < d.length; i += 4) {
                var c = Qt.rgba(d[i] / 255, d[i + 1] / 255, d[i + 2] / 255, 1)
                var h = c.hsvHue, sat = c.hsvSaturation, v = c.hsvValue
                if (v < 0.08) continue
                var key = (sat < 0.18) ? "n" + Math.round(v * 3) : "h" + Math.round((h < 0 ? 0 : h) * 14) + "v" + Math.round(v * 2)
                var b = buckets[key] || (buckets[key] = { r: 0, g: 0, b: 0, n: 0, w: 0 })
                b.r += d[i]; b.g += d[i + 1]; b.b += d[i + 2]; b.n++
                b.w += 1 + sat * 3 * v
            }
            var list = []
            for (var k in buckets) {
                var e = buckets[k]
                list.push({ c: Qt.rgba(e.r / e.n / 255, e.g / e.n / 255, e.b / e.n / 255, 1), w: e.w, chroma: k[0] === "h" })
            }
            list.sort(function(a, b) { return (b.chroma - a.chroma) || (b.w - a.w) })
            root.swatchColors = list.slice(0, 10).map(function(x) { return x.c })
        }
    }

    // ===================================================================================
    clip: true

    // Full height at all times and pinned to the bottom edge, so while the notch grows the
    // whole picker rises out of the edge instead of unfolding.
    Item {
        id: keys
        width: parent.width
        height: root.popupHeight
        anchors.bottom: parent.bottom
        focus: true
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? Anim.slow : Anim.fast; easing.type: Easing.OutCubic } }

        Keys.onLeftPressed: root.go(root.index - 1)
        Keys.onRightPressed: root.go(root.index + 1)
        Keys.onReturnPressed: root.commit()
        Keys.onEnterPressed: root.commit()
        Keys.onEscapePressed: root.cancel()
        Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Home) { root.go(0); e.accepted = true }
            else if (e.key === Qt.Key_End) { root.go(root.count - 1); e.accepted = true }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Popups.wallpaperPinned = true
            onWheel: function(w) {
                var dlt = (w.angleDelta.y !== 0 ? w.angleDelta.y : -w.angleDelta.x)
                if (Math.abs(dlt) >= 60) root.go(root.index + (dlt < 0 ? 1 : -1))
            }
        }

        // --- the strip ---------------------------------------------------------------
        Item {
            id: strip
            anchors.fill: parent

            Repeater {
                model: root.walls

                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index

                    readonly property real d: index - root.flow
                    readonly property real ad: Math.abs(d)
                    readonly property real sg: d < 0 ? -1 : 1
                    readonly property real t: Math.min(1, ad)
                    readonly property real far: Math.max(0, ad - 1)
                    // centre card → first slice → narrower, shorter slices
                    readonly property real cardW: ad <= 1 ? root.cw + (root.sw0 - root.cw) * t
                                                          : Math.max(root.sw * 0.7, root.sw0 + (root.sw - root.sw0) * Math.min(1, far))
                    readonly property real cardH: ad <= 1 ? root.ch + (root.sh0 - root.ch) * t
                                                          : Math.max(root.sh0 * 0.62, root.sh0 - far * 14 * root.s)
                    readonly property real cx: ad <= 1 ? sg * t * (root.cw / 2 + root.gap + root.sw0 / 2)
                                                       : sg * (root.cw / 2 + root.gap + root.sw0 / 2 + far * root.step)

                    visible: ad < 12
                    z: 100 - ad * 4
                    width: cardW; height: cardH
                    x: root.width / 2 + cx - width / 2
                    y: root.cardTop + (root.ch - height) / 2
                    opacity: ad < 8 ? 1 : Math.max(0, 1 - (ad - 8) / 4)

                    transform: Rotation {
                        origin.x: card.width / 2; origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: -card.sg * Math.min(1, card.ad) * 24
                    }

                    // shadow pooled under each card
                    Rectangle {
                        anchors.fill: frameRect
                        anchors.margins: -Math.round(3 * root.s)
                        anchors.topMargin: Math.round(8 * root.s)
                        radius: frameRect.radius + 3
                        color: "black"
                        opacity: 0.55
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 24 }
                    }

                    ClippingRectangle {
                        id: frameRect
                        anchors.fill: parent
                        radius: Math.round((card.ad < 1 ? 14 : 10) * root.s)
                        color: Theme.background
                        border.width: 0

                        Image {
                            anchors.fill: parent
                            source: "file://" + WallpaperService.posterFor(card.modelData)
                            sourceSize: Qt.size(Math.round(root.cw), Math.round(root.ch))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Anim.slow } }
                        }
                        // further away = deeper in the shadow
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: Math.min(0.72, card.ad * 0.16) * (hov.hovered ? 0.4 : 1)
                            Behavior on opacity { NumberAnimation { duration: Anim.normal } }
                        }
                    }
                    // live wallpaper: a small play mark (bottom-left on the big card, centred on slices)
                    Rectangle {
                        visible: WallpaperService.isVideo(card.modelData)
                        readonly property bool big: card.ad < 0.5
                        x: big ? Math.round(14 * root.s) : (parent.width - width) / 2
                        y: parent.height - height - Math.round((big ? 14 : 10) * root.s)
                        width: big ? playRow.implicitWidth + Math.round(16 * root.s) : Math.round(22 * root.s)
                        height: Math.round(22 * root.s)
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.62)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        Row {
                            id: playRow
                            anchors.centerIn: parent
                            spacing: Math.round(5 * root.s)
                            Text { text: "▶"; color: Theme.active; font.pixelSize: Math.round(9 * root.s); anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                visible: parent.parent.big
                                text: "LIVE"
                                color: Theme.text
                                font.pixelSize: Math.round(9.5 * root.s)
                                font.bold: true
                                font.letterSpacing: 1.2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // hairline edge; the accent marks the selected card
                    Rectangle {
                        anchors.fill: parent
                        radius: frameRect.radius
                        color: "transparent"
                        border.width: Math.max(1, Math.round(1.5 * root.s))
                        border.color: card.ad < 0.5 ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.85 - card.ad)
                                                    : Qt.rgba(1, 1, 1, 0.06)
                    }

                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: card.index === root.index ? root.commit() : root.go(card.index)
                    }
                }
            }
        }

        // --- details under the centre card -----------------------------------------------------
        Column {
            id: info
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cardTop + root.ch + Math.round(18 * root.s)
            spacing: Math.round(4 * root.s)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.selected !== "" ? root.fileName(root.selected) : "No wallpapers in " + WallpaperService.wallpaperDir
                color: Theme.active
                font.pixelSize: Math.round(17 * root.s)
                font.bold: true
                font.letterSpacing: 0.4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.selected !== ""
                color: Theme.subtext
                font.pixelSize: Math.round(11.5 * root.s)
                text: {
                    var parts = []
                    var here = probe.path === root.selected
                    if (here && probe.video && probe.videoInfo !== "") {
                        var v = probe.videoInfo.split(",")
                        parts.push(v[0] + " × " + v[1])
                        if (v.length > 2 && parseFloat(v[2]) > 0) parts.push(Math.round(parseFloat(v[2])) + " s loop")
                    } else if (here && probeImg.status === Image.Ready)
                        parts.push(probeImg.implicitWidth + " × " + probeImg.implicitHeight)
                    if (probe.bytes > 0 && probe.path === root.selected) parts.push(root.humanSize(probe.bytes))
                    parts.push(probe.video && here ? root.ext(root.selected) + " live" : root.ext(root.selected))
                    parts.push((root.index + 1) + " of " + root.count)
                    return parts.join("  ·  ")
                }
            }
        }

        // --- the wallpaper's colours — pick one as the accent ---------------------------------------
        Row {
            id: swatches
            anchors.horizontalCenter: parent.horizontalCenter
            y: info.y + info.height + Math.round(18 * root.s)
            spacing: Math.round(9 * root.s)

            Repeater {
                model: root.swatchColors
                delegate: Item {
                    id: sw
                    required property color modelData
                    readonly property bool current: Qt.colorEqual(sw.modelData, Theme.active)
                    width: Math.round(18 * root.s); height: width
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + (sw.current ? Math.round(6 * root.s) : 0); height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: sw.current ? 1 : 0
                        border.color: Theme.text
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * (swHov.hovered ? 1.15 : 1); height: width
                        radius: width / 2
                        color: sw.modelData
                        Behavior on width { NumberAnimation { duration: Anim.normal; easing.type: Easing.OutCubic } }
                    }
                    HoverHandler { id: swHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: PrefsService.overrideActive = sw.modelData.toString() }
                }
            }
            // back to the house crimson
            Item {
                width: Math.round(18 * root.s); height: width
                visible: root.swatchColors.length > 0
                Text {
                    anchors.centerIn: parent
                    text: "↺"
                    color: rstHov.hovered ? Theme.active : Theme.subtext
                    font.pixelSize: Math.round(14 * root.s)
                }
                HoverHandler { id: rstHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: PrefsService.overrideActive = "#C24A52" }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(16 * root.s)
            color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.7)
            font.pixelSize: Math.round(10.5 * root.s)
            text: "←  →  browse   ·   Enter keeps it   ·   Esc puts the old one back   ·   a colour below sets the accent"
        }
    }
}

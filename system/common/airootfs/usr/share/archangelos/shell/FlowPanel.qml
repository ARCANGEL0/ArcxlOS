import QtQuick
import QtQuick.Shapes

// A panel that pours out of the sidebar. It starts as a small bulge at
// `originY`, spreads sideways first and then fills out vertically, joined
// to the sidebar by curved flares like a liquid neck. A shader dissolves
// its leading edge into black smoke while it moves, and a veil of smoke
// rolls around it mid-transition. Children are laid out at the final size.
Item {
    id: flow

    property bool shown: false
    property real originY: 0
    property size size: Qt.size(400, 300)
    property real targetY: 0
    default property alias content: inner.data

    // Positioned by the caller at the sidebar's right edge; y runs in window
    // coordinates so originY/targetY can be given as such.
    width: parent ? parent.width - x : 0
    height: parent ? parent.height : 0

    // ── animated geometry ────────────────────────────────────────────────
    readonly property real restHeight: 40
    property real w: shown ? size.width : 0
    property real h: shown ? size.height : restHeight
    property real y0: shown ? targetY : originY - restHeight / 2
    property real progress: shown ? 1 : 0

    Behavior on w {
        NumberAnimation {
            duration: (flow.shown ? 620 : 460) * Theme.motion
            easing.type: flow.shown ? Easing.OutExpo : Easing.InQuart
        }
    }
    Behavior on h {
        SequentialAnimation {
            PauseAnimation { duration: (flow.shown ? 70 : 0) * Theme.motion }
            NumberAnimation {
                duration: (flow.shown ? 720 : 360) * Theme.motion
                easing.type: flow.shown ? Easing.OutQuint : Easing.InCubic
            }
        }
    }
    Behavior on y0 {
        SequentialAnimation {
            PauseAnimation { duration: (flow.shown ? 70 : 0) * Theme.motion }
            NumberAnimation {
                duration: (flow.shown ? 720 : 360) * Theme.motion
                easing.type: flow.shown ? Easing.OutQuint : Easing.InCubic
            }
        }
    }
    Behavior on progress {
        NumberAnimation {
            duration: (flow.shown ? 900 : 520) * Theme.motion
            easing.type: flow.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    readonly property bool live: w > 0.5 || progress > 0.001
    visible: live

    property real time: 0
    NumberAnimation on time {
        from: 0; to: 3600; duration: 3600000 * Theme.motion
        loops: Animation.Infinite
        running: flow.live
    }

    // ── body: fixed box covering the start and end shapes ────────────────
    readonly property real flare: 20
    readonly property real boxTop: Math.min(originY - restHeight / 2, targetY) - flare
    readonly property real boxBottom: Math.max(originY + restHeight / 2, targetY + size.height) + flare

    // Smoke rolling around the panel while it moves.
    ShaderEffect {
        id: veil
        x: 0
        y: flow.boxTop - 120
        width: flow.size.width + 200
        height: flow.boxBottom - flow.boxTop + 240
        visible: intensity > 0.01
        fragmentShader: Qt.resolvedUrl("shaders/veil.frag.qsb")

        property real intensity: Math.sin(Math.PI * Math.min(1, Math.max(0, flow.progress)))
        property real time: flow.time
        property real aspect: width / height
        property vector4d box: Qt.vector4d(0,
            (flow.y0 - y) / height,
            flow.w / width,
            (flow.y0 + flow.h - y) / height)
    }

    Item {
        id: body
        x: 0
        y: flow.boxTop
        width: flow.size.width + 1
        height: flow.boxBottom - flow.boxTop

        readonly property real ly: flow.y0 - y
        readonly property real neck: Math.min(flow.flare, flow.w)
        readonly property real corner: Math.min(18, flow.w / 2, flow.h / 2)
        // While moving, the leading edge bulges like a droplet's meniscus.
        readonly property real bulge: Math.min(90 * (1 - flow.progress), flow.size.width - flow.w)

        layer.enabled: flow.live
        layer.effect: ShaderEffect {
            fragmentShader: Qt.resolvedUrl("shaders/smoke.frag.qsb")
            property real progress: flow.progress
            property real time: flow.time
            property real aspect: body.width / Math.max(1, body.height)
            property real ambient: 0.02
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.ink
                strokeWidth: -1
                startX: 0; startY: body.ly - body.neck
                // flare out of the sidebar
                PathQuad { x: body.neck; y: body.ly; controlX: 0; controlY: body.ly }
                PathLine { x: flow.w - body.corner; y: body.ly }
                PathQuad { x: flow.w; y: body.ly + body.corner; controlX: flow.w; controlY: body.ly }
                PathQuad { x: flow.w; y: body.ly + flow.h - body.corner
                           controlX: flow.w + 2 * body.bulge; controlY: body.ly + flow.h / 2 }
                PathQuad { x: flow.w - body.corner; y: body.ly + flow.h; controlX: flow.w; controlY: body.ly + flow.h }
                PathLine { x: body.neck; y: body.ly + flow.h }
                // and back into it
                PathQuad { x: 0; y: body.ly + flow.h + body.neck; controlX: 0; controlY: body.ly + flow.h }
                PathLine { x: 0; y: body.ly - body.neck }
            }
        }

        // Content is clipped to the growing shape and fades in behind the front.
        Item {
            x: 0
            y: body.ly
            width: flow.w
            height: flow.h
            clip: true

            Item {
                id: inner
                x: -12 * (1 - reveal)
                y: flow.targetY - flow.y0
                width: flow.size.width
                height: flow.size.height
                readonly property real reveal: Math.max(0, (flow.progress - 0.3) / 0.7)
                opacity: reveal
            }
        }
    }
}

import QtQuick 2.15

Item {
    id: root
    property url source
    property bool active: true

    Image {
        id: tex
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property variant src: tex
        property real time: 0
        property real amp: 0.014
        property real grainAmt: 0.16
        fragmentShader: "../shaders/dust.frag.qsb"
        blending: true

        NumberAnimation on time {
            running: root.active
            from: 0; to: 100000
            duration: 100000 * 1000
            loops: Animation.Infinite
        }
        SequentialAnimation on amp {
            running: root.active
            loops: Animation.Infinite
            NumberAnimation { from: 0.010; to: 0.026; duration: 5200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.026; to: 0.010; duration: 6100; easing.type: Easing.InOutSine }
        }
    }

    transform: Translate { id: sway }

    SequentialAnimation {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation { target: sway; property: "x"; from: -3; to: 3; duration: 7000; easing.type: Easing.InOutSine }
        NumberAnimation { target: sway; property: "x"; from: 3; to: -3; duration: 7600; easing.type: Easing.InOutSine }
    }
}

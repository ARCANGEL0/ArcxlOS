import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property color ember: "#d3232f"
    readonly property string logoSource: "file://" + Quickshell.shellDir + "/../assets/logo.png"
    property bool leaving: false

    function dismiss() {
        if (root.leaving) return
        root.leaving = true
        quitTimer.start()
    }

    IpcHandler {
        target: "splash"
        function dismiss(): void { root.dismiss() }
    }

    Timer { interval: 30000; running: true; onTriggered: root.dismiss() }
    Timer { id: quitTimer; interval: 1250; onTriggered: Qt.quit() }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "archangelos-splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Item {
                id: stage
                anchors.fill: parent
                readonly property real unit: Math.max(0.75, Math.min(1.5, height / 1080))
                property real breath: 0

                SequentialAnimation on breath {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1; to: 0; duration: 2200; easing.type: Easing.InOutSine }
                }

                property real iris: -0.35
                NumberAnimation on iris {
                    running: root.leaving
                    to: 1.0
                    duration: 1150
                    easing.type: Easing.InOutCubic
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.GeometryRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: stage.width / 2; centerY: stage.height / 2
                            focalX: centerX; focalY: centerY
                            centerRadius: Math.sqrt(stage.width * stage.width + stage.height * stage.height) / 2
                            GradientStop { position: Math.max(0, Math.min(1, stage.iris)); color: "#00040406" }
                            GradientStop { position: Math.max(0, Math.min(1, stage.iris + 0.18)); color: "#b3040406" }
                            GradientStop { position: Math.max(0, Math.min(1, stage.iris + 0.35)); color: "#ff040406" }
                        }
                        PathRectangle { x: 0; y: 0; width: stage.width; height: stage.height }
                    }
                }

                Item {
                    id: mark
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -Math.round(18 * stage.unit)
                    width: Math.round(150 * stage.unit)
                    height: Math.round(width * 1211 / 1541)

                    opacity: 0
                    scale: 0.96
                    states: [
                        State { name: "in"; when: !root.leaving && logo.status === Image.Ready
                            PropertyChanges { mark.opacity: 1; mark.scale: 1 } },
                        State { name: "out"; when: root.leaving
                            PropertyChanges { mark.opacity: 0; mark.scale: 1.04 } }
                    ]
                    transitions: Transition {
                        NumberAnimation { properties: "opacity,scale"; duration: 650; easing.type: Easing.OutCubic }
                    }

                    Shape {
                        anchors.centerIn: parent
                        width: mark.width * 2.6
                        height: width
                        opacity: 0.10 + stage.breath * 0.14
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: RadialGradient {
                                centerX: mark.width * 1.3; centerY: mark.width * 1.3
                                centerRadius: mark.width * 1.3
                                focalX: centerX; focalY: centerY
                                GradientStop { position: 0.0; color: root.ember }
                                GradientStop { position: 0.45; color: Qt.rgba(root.ember.r, root.ember.g, root.ember.b, 0.25) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                            PathRectangle { x: 0; y: 0; width: mark.width * 2.6; height: mark.width * 2.6 }
                        }
                    }

                    Image {
                        id: logo
                        anchors.fill: parent
                        source: root.logoSource
                        sourceSize.width: Math.round(mark.width * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        opacity: 0.86 + stage.breath * 0.14
                    }
                }

                Item {
                    id: track
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: mark.bottom
                    anchors.topMargin: Math.round(54 * stage.unit)
                    width: Math.round(132 * stage.unit)
                    height: 1
                    clip: true
                    opacity: root.leaving ? 0 : mark.opacity
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    Rectangle {
                        id: sweep
                        width: track.width * 0.45
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.75) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        NumberAnimation on x {
                            loops: Animation.Infinite
                            from: -sweep.width; to: track.width
                            duration: 1500
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}

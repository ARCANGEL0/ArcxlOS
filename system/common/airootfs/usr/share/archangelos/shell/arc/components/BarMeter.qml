// ArchangelOS addition: a bar-sized gauge — Gauge.qml's ring, slimmed to fit the 56px bar,
// reading inside, icon underneath.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.arc

ColumnLayout {
    id: meter
    property string icon
    property real value: 0          // 0..1
    property string valueText
    property color tint: Config.accent
    property int ring: 34
    readonly property int stroke: 3

    spacing: 3

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: meter.ring; implicitHeight: meter.ring

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Config.surface
                strokeWidth: meter.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: meter.ring / 2; centerY: meter.ring / 2
                    radiusX: (meter.ring - meter.stroke) / 2; radiusY: (meter.ring - meter.stroke) / 2
                    startAngle: -90; sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: meter.tint
                strokeWidth: meter.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: meter.ring / 2; centerY: meter.ring / 2
                    radiusX: (meter.ring - meter.stroke) / 2; radiusY: (meter.ring - meter.stroke) / 2
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, meter.value))
                    Behavior on sweepAngle { Effect {} }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: meter.valueText
            color: Config.fg
            font.family: Config.textFont
            font.pixelSize: 9
        }
    }

    MatIcon {
        Layout.alignment: Qt.AlignHCenter
        text: meter.icon
        font.pixelSize: 12
        color: Config.dim
    }
}

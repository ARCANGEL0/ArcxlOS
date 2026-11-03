// ArchangelOS addition: a bar-sized gauge for the 56px vertical bar.
// With history available it draws a mini sparkline (the same chart the hover
// panes use); without it (battery) it falls back to a vertical liquid pill.
// Big percentage below, source icon at the bottom. `popout` names the pane.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.arc

Item {
    id: meter
    property string icon
    property real value: 0          // 0..1
    property string valueText
    property color tint: Config.accent
    property var hist: null         // samples 0..1, e.g. Sys.cpuHist
    // Name passed to bar.showPopout() when the cursor enters this meter.
    property string popout: ""

    readonly property bool hasHist: meter.hist !== null && meter.hist.length >= 2
    readonly property real pillW: 8
    readonly property real pillH: 38

    property real _anim: Math.max(0, Math.min(1, meter.value))
    Behavior on _anim { Effect {} }

    signal entered()
    signal exited()

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 3

        HistChart {
            visible: meter.hasHist
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 38
            implicitHeight: 18
            hist: meter.hist
            line: meter.tint
        }

        Item {
            visible: !meter.hasHist
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: meter.pillW
            implicitHeight: meter.pillH

            Rectangle {
                anchors.fill: parent
                radius: meter.pillW / 2
                color: Qt.rgba(meter.tint.r, meter.tint.g, meter.tint.b, 0.16)
            }

            Rectangle {
                id: fill
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(meter.pillW, meter._anim * meter.pillH)
                radius: meter.pillW / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: meter.tint }
                    GradientStop { position: 1; color: Qt.rgba(meter.tint.r, meter.tint.g, meter.tint.b, 0.45) }
                }
            }

            Rectangle {
                width: parent.width
                height: 3
                radius: 1.5
                y: Math.max(0, Math.min(meter.pillH - 3, meter.pillH - fill.height - 1.5))
                color: meter.tint
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: meter.valueText
            color: Config.fg
            font.family: Config.textFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MatIcon {
            Layout.alignment: Qt.AlignHCenter
            text: meter.icon
            font.pixelSize: 11
            color: Qt.rgba(meter.tint.r, meter.tint.g, meter.tint.b, 0.55)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: meter.entered()
        onExited: meter.exited()
    }
}

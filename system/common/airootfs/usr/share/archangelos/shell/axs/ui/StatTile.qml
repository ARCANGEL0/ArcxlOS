// A vital: big mono value, caption underneath, optional notch meter.
import QtQuick
import qs.axs

Rectangle {
    id: t
    property string value: "—"
    property string unit: ""
    property string caption: ""
    property real meter: -1          // <0 hides the meter
    implicitWidth: 150; implicitHeight: meter >= 0 ? 92 : 76
    radius: Ax.radius
    color: Ax.panel
    border.width: 1; border.color: Ax.border
    Column {
        anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Row {
            spacing: 3
            Label { text: t.value; mono: true; font.pixelSize: 24; color: Ax.text }
            Label { text: t.unit; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.baseline: parent.children[0].baseline }
        }
        Label { caption: true; text: t.caption }
        Meter { visible: t.meter >= 0; width: parent.width; height: 6; notches: 18; value: Math.max(0, t.meter) }
    }
}

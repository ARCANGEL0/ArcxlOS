// Usage meter drawn as a row of notches (blade marks) rather than a plain bar.
import QtQuick
import qs.axs

Item {
    id: m
    property real value: 0           // 0..1
    property int notches: 32
    property color tint: value > 0.9 ? Ax.danger : Ax.accent
    implicitWidth: 200; implicitHeight: 10
    Row {
        anchors.fill: parent
        spacing: 3
        Repeater {
            model: m.notches
            Rectangle {
                required property int index
                width: (m.width - (m.notches - 1) * 3) / m.notches
                height: m.height; radius: 1.5
                color: index < Math.round(m.value * m.notches) ? m.tint : Ax.raised
                Behavior on color { ColorAnimation { duration: Ax.durSlow } }
            }
        }
    }
}

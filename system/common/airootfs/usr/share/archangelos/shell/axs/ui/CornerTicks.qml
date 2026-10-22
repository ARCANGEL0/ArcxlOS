// Technical corner brackets around a parent area.
import QtQuick
import qs.axs

Item {
    anchors.fill: parent
    property int len: 12
    property color tint: Ax.alpha(Ax.text, 0.22)
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool r: index % 2 === 1
            readonly property bool b: index >= 2
            x: r ? parent.width - parent.len : 0
            y: b ? parent.height - parent.len : 0
            width: parent.len; height: parent.len
            Rectangle { x: 0; y: parent.b ? parent.height - 1 : 0; width: parent.width; height: 1; color: parent.parent.tint }
            Rectangle { x: parent.r ? parent.width - 1 : 0; y: 0; width: 1; height: parent.height; color: parent.parent.tint }
        }
    }
}

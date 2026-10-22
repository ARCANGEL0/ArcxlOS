// On/off switch. The whole control is the hit target; `toggled` reports the requested state and
// the owner decides (so a switch bound to real system state never shows a lie).
import QtQuick
import qs.axs

Item {
    id: sw
    property bool checked: false
    property bool enabled_: true
    signal toggled(bool on)
    implicitWidth: 42; implicitHeight: 24
    opacity: enabled_ ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Ax.accent : Ax.raised
        border.width: sw.checked ? 0 : 1
        border.color: Ax.border
        Behavior on color { ColorAnimation { duration: Ax.dur } }
    }
    Rectangle {
        width: 18; height: 18; radius: 9
        y: 3
        x: sw.checked ? sw.width - width - 3 : 3
        color: sw.checked ? "#fbf8f3" : Ax.subtext
        Behavior on x { NumberAnimation { duration: Ax.dur; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Ax.dur } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: sw.enabled_
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}

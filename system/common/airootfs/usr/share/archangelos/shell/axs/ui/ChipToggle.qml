// Compact on/off chip for grouping many small toggles in one row.
import QtQuick
import qs.axs

Rectangle {
    id: chip
    property string text: ""
    property string icon: ""
    property bool checked: false
    signal toggled(bool on)
    implicitHeight: 32
    implicitWidth: row.implicitWidth + 24
    radius: 16
    color: checked ? Ax.accentSoft : (ma.containsMouse ? Ax.mix(Ax.raised, Ax.text, 0.04) : Ax.raised)
    border.width: 1; border.color: checked ? Ax.accentLine : Ax.border
    Behavior on color { ColorAnimation { duration: Ax.dur } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Icon { name: chip.checked ? "check" : chip.icon; size: 15; color: chip.checked ? Ax.accent : Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
        Label { text: chip.text; font.pixelSize: Ax.fsSmall; color: chip.checked ? Ax.text : Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.toggled(!chip.checked) }
}
